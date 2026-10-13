# PeekBar

Click any macOS menu bar icon — **even ones hidden under the notch** or pushed
off the edge when the bar overflows.

Menu-bar managers like Ice/Bartender solve overflow by drawing a second bar and
screen-capturing your icons. PeekBar takes a simpler route: it uses the
**Accessibility API** to list every menu bar icon by name and trigger it
directly. Clicking a row opens that icon's menu in normal, visible screen space.

- **No Screen Recording** — only the Accessibility permission.
- No private APIs, no daemons, no network. ~300 lines of Swift, zero dependencies.

## Features

- A plain window listing every menu bar extra, each with its **app icon** and name.
- Click a row → opens that icon's menu (works for icons hidden under the notch).
- **Keyboard-driven**: start typing to filter the list to apps whose name
  contains what you typed; **↑/↓** move the selection, **⏎** opens the selected
  icon's menu (**esc** hides the window).
- **Quit** button on each third-party row to quit that app (system items are left alone).
- Global hotkey **⌘⌥M** to show/hide the window; also launchable from Spotlight/Dock.
- Registers itself as a **login item** on first run (manage it in
  System Settings → General → Login Items).

## Build

```sh
./make-cert.sh   # one-time: create a stable self-signed signing identity
./build.sh       # compile + sign -> PeekBar.app
open ./PeekBar.app
```

On first launch, grant **PeekBar** access in
System Settings → Privacy & Security → **Accessibility**.

## Why the self-signed identity?

macOS ties the Accessibility grant to the app's code signature. An *ad-hoc*
signature changes hash on every rebuild, so you'd have to re-grant each time.
`make-cert.sh` creates a stable self-signed identity (kept in your login
keychain, private key never committed), so the grant survives rebuilds. The
cert is untrusted — that's expected and fine for local signing.

## Files

| file            | purpose                                   |
|-----------------|-------------------------------------------|
| `main.swift`    | the whole app                             |
| `build.sh`      | compile + sign into `PeekBar.app`         |
| `make-cert.sh`  | create the stable signing identity        |
| `gen-icon.swift`| render the app icon                       |
| `AppIcon.icns`  | the built icon asset                      |

## Notes

- The Accessibility press returns error `-25204` for status-item menus; this is
  benign (the menu enters a modal tracking loop) and the menu still opens.
