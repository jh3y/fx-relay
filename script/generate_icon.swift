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
    let ink = color(0.14, 0.15, 0.15), paper = color(0.91, 0.90, 0.86), orange = color(0.94, 0.29, 0.10)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -8), blur: 25, color: CGColor(gray: 0, alpha: 0.18))
    rounded(CGRect(x: 58, y: 58, width: 908, height: 908), 196, paper); c.restoreGState()
    c.setStrokeColor(CGColor(gray: 1, alpha: 0.5)); c.setLineWidth(3)
    c.addPath(CGPath(roundedRect: CGRect(x: 60, y: 60, width: 904, height: 904), cornerWidth: 194, cornerHeight: 194, transform: nil)); c.strokePath()
    rounded(CGRect(x: 314, y: 422, width: 324, height: 416), 116, ink)
    rounded(CGRect(x: 426, y: 186, width: 100, height: 310), 34, ink)
    rounded(CGRect(x: 558, y: 242, width: 64, height: 174), 24, ink)
    for y in [530, 590, 650, 710] { rounded(CGRect(x: 376, y: y, width: 200, height: 22), 11, paper) }
    c.setFillColor(orange); c.fillEllipse(in: CGRect(x: 672, y: 338, width: 144, height: 144))
    for i in 0..<4 {
        c.setFillColor(i == 0 ? orange : color(0.67, 0.67, 0.64))
        c.fillEllipse(in: CGRect(x: 298 + i * 46, y: 136, width: 14, height: 14))
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
print("Rendered original FX-MIC icon: \(output.path)")
