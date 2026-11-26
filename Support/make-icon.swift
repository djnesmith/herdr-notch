// Fork: draws the app icon, a dark rounded square with a notch at its top edge and three status dots
// in the app's own colors (needs you, working, done). Run from the repo root:
//   swift Support/make-icon.swift && iconutil -c icns Support/AppIcon.iconset -o Support/AppIcon.icns && rm -r Support/AppIcon.iconset
import AppKit

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024                       // drawn on a 1024 grid, y up
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * s, y: y * s, width: w * s, height: h * s) }

    // Body: the standard macOS icon square (824 on a 1024 canvas).
    let body = NSBezierPath(roundedRect: r(100, 100, 824, 824), xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.25, alpha: 1),
               ending: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1))!.draw(in: body, angle: -90)
    NSColor(white: 1, alpha: 0.08).setStroke()
    body.lineWidth = 4 * s
    body.stroke()

    // The notch: flat against the top edge, rounded below.
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    let notch = NSBezierPath(roundedRect: r(332, 760, 360, 200), xRadius: 56 * s, yRadius: 56 * s)
    NSColor.black.setFill()
    notch.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Three status dots.
    let dots = [NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.59, alpha: 1),
                NSColor(calibratedRed: 0.85, green: 0.74, blue: 0.47, alpha: 1),
                NSColor(calibratedRed: 0.55, green: 0.73, blue: 0.93, alpha: 1)]
    for (i, c) in dots.enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: r(512 - 60 + CGFloat(i - 1) * 190, 390, 120, 120)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: "Support/AppIcon.iconset")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try draw(pt).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try draw(pt * 2).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
