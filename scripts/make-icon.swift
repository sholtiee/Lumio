// Renders the app icon into the asset catalog: `swift scripts/make-icon.swift`
import AppKit

let canvas = 1024.0
let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
    // macOS icon grid: 824pt body centred on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.42, green: 0.62, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.28, green: 0.30, blue: 0.92, alpha: 1),
    ])!.draw(in: shape, angle: -90)

    // Soft top highlight.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(roundedRect: body.insetBy(dx: 0, dy: 0), xRadius: 185, yRadius: 185), angle: -90)

    func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: NSRect) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(.init(paletteColors: [color]))
        guard let glyph = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
        let size = glyph.size
        let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        glyph.draw(in: NSRect(origin: origin, size: size))
    }

    // White display; an indigo sparkle on its screen stands for "crisp".
    symbol("display", pointSize: 400, weight: .regular, color: .white, in: NSRect(x: 100, y: 120, width: 824, height: 760))
    symbol("sparkle", pointSize: 170, weight: .semibold, color: NSColor(srgbRed: 0.30, green: 0.34, blue: 0.93, alpha: 1),
           in: NSRect(x: 452, y: 500, width: 120, height: 120))
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: canvas, height: canvas))
NSGraphicsContext.restoreGraphicsState()

let directory = URL(fileURLWithPath: "Lumio/Resources/Assets.xcassets/AppIcon.appiconset")
let master = directory.appending(path: "icon_1024.png")
try rep.representation(using: .png, properties: [:])!.write(to: master)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)@\(scale)x.png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-z", "\(pixels)", "\(pixels)", master.path, "--out", directory.appending(path: name).path]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
try FileManager.default.removeItem(at: master)
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appending(path: "Contents.json"))
print("icon written")
