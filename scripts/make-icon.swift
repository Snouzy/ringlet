// Dessine l'icône de Ringlet (camembert sur fond graphite) et écrit Resources/AppIcon.icns.
// Usage : swift scripts/make-icon.swift
import AppKit

func draw(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
        let s = size / 1024
        let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let tile = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.27, alpha: 1),
                   ending: NSColor(srgbRed: 0.08, green: 0.09, blue: 0.12, alpha: 1))!.draw(in: tile, angle: 90)
        let center = CGPoint(x: 512 * s, y: 512 * s)
        let outer = 300 * s, inner = 92 * s
        for index in 0..<4 {
            let mid = -90 + Double(index) * 90
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: outer, startAngle: mid - 42, endAngle: mid + 42, clockwise: false)
            path.appendArc(withCenter: center, radius: inner, startAngle: mid + 42, endAngle: mid - 42, clockwise: true)
            path.close()
            let color = index == 0 ? NSColor(srgbRed: 0.30, green: 0.53, blue: 0.96, alpha: 1)
                                   : NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 0.92)
            color.setFill()
            path.fill()
        }
        return true
    }
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = CGFloat(base * scale)
        let image = draw(size: pixels)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels), pixelsHigh: Int(pixels),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns" : "iconutil a échoué")
