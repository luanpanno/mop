// Renders the Mop app icon into Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 rounded square, centered.
    let inset = s * 100 / 1024
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.38, blue: 0.95, alpha: 1),
    ])!.draw(in: path, angle: -90)

    // Custom artwork (SF Symbols may not be used in app icons): soap bubbles and sparkles.
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
    func bubble(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        let radius = rect.width * r
        let c = point(x, y)
        let circle = NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
        NSColor(calibratedRed: 0.94, green: 0.98, blue: 1, alpha: 1).setFill()
        circle.fill()
        NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.95, alpha: 0.35).setStroke()
        circle.lineWidth = max(1, rect.width * 0.008)
        circle.stroke()
        // Highlight
        let h = radius * 0.32
        let hc = NSPoint(x: c.x - radius * 0.38, y: c.y + radius * 0.38)
        NSGradient(colors: [NSColor(calibratedRed: 0.55, green: 0.85, blue: 1, alpha: 0.9), .clear])!
            .draw(in: NSBezierPath(ovalIn: NSRect(x: hc.x - h, y: hc.y - h, width: h * 2, height: h * 2)), relativeCenterPosition: .zero)
    }
    func sparkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        let c = point(x, y)
        let R = rect.width * r
        let k = R * 0.18
        let star = NSBezierPath()
        star.move(to: NSPoint(x: c.x, y: c.y + R))
        star.curve(to: NSPoint(x: c.x + R, y: c.y), controlPoint1: NSPoint(x: c.x + k, y: c.y + k), controlPoint2: NSPoint(x: c.x + k, y: c.y + k))
        star.curve(to: NSPoint(x: c.x, y: c.y - R), controlPoint1: NSPoint(x: c.x + k, y: c.y - k), controlPoint2: NSPoint(x: c.x + k, y: c.y - k))
        star.curve(to: NSPoint(x: c.x - R, y: c.y), controlPoint1: NSPoint(x: c.x - k, y: c.y - k), controlPoint2: NSPoint(x: c.x - k, y: c.y - k))
        star.curve(to: NSPoint(x: c.x, y: c.y + R), controlPoint1: NSPoint(x: c.x - k, y: c.y + k), controlPoint2: NSPoint(x: c.x - k, y: c.y + k))
        star.close()
        NSColor.white.setFill()
        star.fill()
    }
    bubble(0.56, 0.48, 0.20)
    bubble(0.32, 0.60, 0.11)
    bubble(0.38, 0.30, 0.08)
    bubble(0.74, 0.70, 0.07)
    sparkle(0.28, 0.80, 0.08)
    sparkle(0.78, 0.26, 0.10)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in sizes where size <= 512 {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
