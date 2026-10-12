import Cocoa
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement

// PeekBar — click any menu bar icon, even ones hidden under the notch.
//
// How it works: the macOS Accessibility API can list every app's menu bar
// extras by name and trigger them. PeekBar shows that list in a plain window;
// clicking a row opens that icon's menu (which appears in visible screen space,
// not under the notch). No screen recording — only the Accessibility permission.
//
// Open it from Spotlight/Dock, or with the global hotkey ⌘⌥M.

extension Notification.Name { static let peekbarToggle = Notification.Name("peekbarToggle") }

// MARK: - Accessibility helpers

func axString(_ el: AXUIElement, _ attr: String) -> String {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success, let s = v as? String { return s }
    return ""
}
func axChildren(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success, let arr = v as? [AXUIElement] { return arr }
    return []
}

struct Icon { let label: String; let element: AXUIElement; let app: NSRunningApplication; let system: Bool }

func enumerateIcons() -> [Icon] {
    var result: [Icon] = []
    for app in NSWorkspace.shared.runningApplications {
        let pid = app.processIdentifier
        if pid <= 0 { continue }
        let appName = app.localizedName ?? "?"
        let system = app.bundleIdentifier?.hasPrefix("com.apple.") ?? false
        let axApp = AXUIElementCreateApplication(pid)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, "AXExtrasMenuBar" as CFString, &v) == .success,
              let extras = v else { continue }
        for item in axChildren(extras as! AXUIElement, kAXChildrenAttribute as String) {
            let desc = axString(item, kAXDescriptionAttribute as String)
            let title = axString(item, kAXTitleAttribute as String)
            if system && desc.isEmpty && title.isEmpty { continue }   // skip blank system slots
            let detail = (!desc.isEmpty ? desc : title).replacingOccurrences(of: "\n", with: " ")
            let label = (detail.isEmpty || detail == appName) ? appName : "\(appName) — \(detail)"
            result.append(Icon(label: label, element: item, app: app, system: system))
        }
    }
    return result
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var stack: NSStackView!
    var icons: [Icon] = []
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ note: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        setupLoginItem()
        buildWindow()
        registerHotKey()
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: .peekbarToggle, object: nil)
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }

    // Register as a login item once (don't fight the user if they later disable it).
    func setupLoginItem() {
        let key = "didRegisterLoginItem"
        if UserDefaults.standard.bool(forKey: key) { return }
        do { try SMAppService.mainApp.register(); UserDefaults.standard.set(true, forKey: key) }
        catch { NSLog("PeekBar: login-item register failed: \(error)") }
    }

    func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 470),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "PeekBar — menu bar icons"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.center()

        let scroll = NSScrollView(frame: w.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        w.contentView!.addSubview(scroll)

        NSLayoutConstraint.activate([
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])
        window = w
    }

    func rebuildList() {
        icons = enumerateIcons()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, icon) in icons.enumerated() {
            let label = NSButton(title: " " + icon.label, target: self, action: #selector(rowClicked(_:)))
            label.tag = i
            label.isBordered = false
            label.alignment = .left
            label.font = .systemFont(ofSize: 13)
            label.contentTintColor = .labelColor
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            if let appIcon = icon.app.icon?.copy() as? NSImage {
                appIcon.size = NSSize(width: 18, height: 18)
                label.image = appIcon
                label.imagePosition = .imageLeft
                label.imageHugsTitle = true
            }

            var views: [NSView] = [label]
            if !icon.system {
                let quit = NSButton(title: "Quit", target: self, action: #selector(quitClicked(_:)))
                quit.tag = i
                quit.bezelStyle = .rounded
                quit.controlSize = .small
                quit.font = .systemFont(ofSize: 11)
                quit.setContentHuggingPriority(.required, for: .horizontal)
                quit.toolTip = "Quit \(icon.app.localizedName ?? "this app")"
                views.append(quit)
            }
            let row = NSStackView(views: views)
            row.orientation = .horizontal
            row.distribution = .fill
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 4).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -4).isActive = true
        }
    }

    @objc func rowClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < icons.count else { return }
        let el = icons[sender.tag].element
        window.orderOut(nil)                                   // hide so the icon's menu is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            _ = AXUIElementPerformAction(el, kAXPressAction as CFString)   // -25204 is benign
        }
    }

    @objc func quitClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < icons.count else { return }
        icons[sender.tag].app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.rebuildList() }
    }

    func showWindow() {
        rebuildList()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func toggle() {
        if window.isVisible { window.orderOut(nil) } else { showWindow() }
    }

    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow(); return true
    }

    // Global hotkey ⌘⌥M
    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            NotificationCenter.default.post(name: .peekbarToggle, object: nil)
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x50454b42), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(cmdKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
