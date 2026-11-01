import AppKit
import Foundation

let output = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Taskvovsky-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        let p = CGFloat(pixels)
        NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: p, height: p).fill()
        let rect = NSRect(x: p * 0.07, y: p * 0.07, width: p * 0.86, height: p * 0.86)
        let shape = NSBezierPath(roundedRect: rect, xRadius: p * 0.195, yRadius: p * 0.195)
        NSGradient(starting: NSColor(srgbRed: 0.39, green: 0.49, blue: 1, alpha: 1), ending: NSColor(srgbRed: 0.26, green: 0.36, blue: 0.88, alpha: 1))!.draw(in: shape, angle: -90)
        let line = NSBezierPath(); line.move(to: NSPoint(x: p * 0.29, y: p * 0.48)); line.line(to: NSPoint(x: p * 0.44, y: p * 0.33)); line.line(to: NSPoint(x: p * 0.73, y: p * 0.66)); line.lineWidth = p * 0.085; line.lineCapStyle = .round; line.lineJoinStyle = .round; NSColor.white.setStroke(); line.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
func lengthBytes(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}
var chunks = Data()
for (type, filename) in [("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    chunks.append(Data(type.utf8)); chunks.append(lengthBytes(png.count + 8)); chunks.append(png)
}
var icns = Data("icns".utf8); icns.append(lengthBytes(chunks.count + 8)); icns.append(chunks)
try icns.write(to: URL(fileURLWithPath: output))
