import Cocoa

// Renders PeekBar's app icon (a menu-bar strip with dots, one highlighted —
// the "reveal the hidden one" motif) to a 1024×1024 PNG at argv[1].

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Rounded background with a blue vertical gradient.
let inset = size * 0.045
let bg = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let corner = size * 0.225
let bgPath = CGPath(roundedRect: bg, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs, colors: [
    NSColor(srgbRed: 0.24, green: 0.52, blue: 0.98, alpha: 1).cgColor,
    NSColor(srgbRed: 0.09, green: 0.21, blue: 0.56, alpha: 1).cgColor
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Menu-bar strip.
let stripW = size * 0.66, stripH = size * 0.205
let strip = CGRect(x: (size - stripW)/2, y: size*0.55, width: stripW, height: stripH)
ctx.addPath(CGPath(roundedRect: strip, cornerWidth: stripH/2, cornerHeight: stripH/2, transform: nil))
ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
ctx.fillPath()

// Four dots inside the strip; the last one highlighted (the hidden icon revealed).
let dotR = stripH * 0.21
let count = 4
let spacing = stripW / CGFloat(count + 1)
for i in 1...count {
    let cx = strip.minX + spacing * CGFloat(i)
    let highlighted = (i == count)
    ctx.addEllipse(in: CGRect(x: cx - dotR, y: strip.midY - dotR, width: dotR*2, height: dotR*2))
    ctx.setFillColor(highlighted
        ? NSColor(srgbRed: 1.0, green: 0.45, blue: 0.22, alpha: 1).cgColor
        : NSColor(srgbRed: 0.16, green: 0.27, blue: 0.52, alpha: 1).cgColor)
    ctx.fillPath()
}

// Downward chevron below the strip — "reveal".
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
ctx.setLineWidth(size * 0.045)
ctx.setLineCap(.round); ctx.setLineJoin(.round)
let cw = size * 0.17, cyTop = size * 0.44
ctx.move(to: CGPoint(x: size/2 - cw/2, y: cyTop))
ctx.addLine(to: CGPoint(x: size/2, y: cyTop - cw*0.62))
ctx.addLine(to: CGPoint(x: size/2 + cw/2, y: cyTop))
ctx.strokePath()

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
