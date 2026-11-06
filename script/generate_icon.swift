// Original vector icon rendered at every macOS icon size. No third-party imagery.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
func render(_ size: Int, name: String) throws {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    func rounded(_ rect: CGRect, _ radius: CGFloat, _ fill: CGColor) {
        c.setFillColor(fill); c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.fillPath()
    }
    let ink = color(0.12, 0.13, 0.13), paper = color(0.94, 0.93, 0.88), orange = color(0.97, 0.31, 0.11)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -8), blur: 25, color: CGColor(gray: 0, alpha: 0.18))
    rounded(CGRect(x: 58, y: 58, width: 908, height: 908), 196, ink); c.restoreGState()
    c.setStrokeColor(CGColor(gray: 1, alpha: 0.18)); c.setLineWidth(3)
    c.addPath(CGPath(roundedRect: CGRect(x: 60, y: 60, width: 904, height: 904), cornerWidth: 194, cornerHeight: 194, transform: nil)); c.strokePath()
    // One strong silhouette stays legible at 16 px. Details only enter at 32 px.
    rounded(CGRect(x: 272, y: 414, width: 324, height: 404), 112, paper)
    rounded(CGRect(x: 382, y: 204, width: 104, height: 310), 34, paper)
    rounded(CGRect(x: 522, y: 246, width: 64, height: 156), 24, orange)
    if size >= 32 {
        for y in [520, 584, 648, 712] { rounded(CGRect(x: 334, y: y, width: 200, height: 22), 11, ink) }
        rounded(CGRect(x: 636, y: 507, width: 110, height: 20), 10, color(0.42, 0.43, 0.41))
    }
    c.setFillColor(orange); c.fillEllipse(in: CGRect(x: 694, y: 459, width: 116, height: 116))
    // Four recessed bank indicators form the quiet instrument detail.
    if size >= 64 {
    for i in 0..<4 {
        rounded(CGRect(x: 653, y: 260 + i * 33, width: 20, height: 12), 5, i == 3 ? orange : color(0.34, 0.35, 0.33))
    }
    }
    let image = c.makeImage()!
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)
    guard let destination else { throw NSError(domain: "Icon", code: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "Icon", code: 2) }
}
for size in [16, 32, 128, 256, 512] {
    try render(size, name: "icon_\(size)x\(size).png")
    try render(size * 2, name: "icon_\(size)x\(size)@2x.png")
}
print("Rendered FX Relay icon: \(output.path)")
