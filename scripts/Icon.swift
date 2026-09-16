import AppKit
let target = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let n = CGFloat(pixels)
        let rect = NSRect(x: n * 0.07, y: n * 0.07, width: n * 0.86, height: n * 0.86)
        let path = NSBezierPath(roundedRect: rect, xRadius: n * 0.19, yRadius: n * 0.19)
        NSGradient(starting: NSColor(srgbRed: 0.29, green: 0.45, blue: 0.34, alpha: 1), ending: NSColor(srgbRed: 0.15, green: 0.29, blue: 0.21, alpha: 1))!.draw(in: path, angle: -65)
        let card = NSBezierPath(roundedRect: NSRect(x: n * 0.25, y: n * 0.24, width: n * 0.5, height: n * 0.53), xRadius: n * 0.045, yRadius: n * 0.045)
        NSColor(srgbRed: 0.95, green: 0.97, blue: 0.9, alpha: 1).setFill()
        card.fill()
        NSColor(srgbRed: 0.29, green: 0.45, blue: 0.34, alpha: 1).setFill()
        for (y, width) in [(0.60, 0.31), (0.48, 0.31), (0.36, 0.19)] {
            NSBezierPath(roundedRect: NSRect(x: n * 0.345, y: n * y, width: n * width, height: n * 0.045), xRadius: n * 0.02, yRadius: n * 0.02).fill()
        }
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: target.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
