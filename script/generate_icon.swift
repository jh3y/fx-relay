// Original Contact vector artwork. Transparent exterior; no baked presentation background.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func render(_ size: Int, name: String) throws {
    let space = CGColorSpaceCreateDeviceRGB()
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = CGPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864), cornerWidth: 190, cornerHeight: 190, transform: nil)
    c.saveGState(); c.addPath(tile); c.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x242724), color(0x363B37)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 80), end: CGPoint(x: 1024, y: 944), options: [])
    c.setLineCap(.round)
    c.setStrokeColor(color(0xF1EBD0)); c.setLineWidth(46)
    c.move(to: CGPoint(x: 80, y: 350)); c.addLine(to: CGPoint(x: 310, y: 350)); c.strokePath()
    c.move(to: CGPoint(x: 714, y: 674)); c.addLine(to: CGPoint(x: 944, y: 674)); c.strokePath()
    c.setStrokeColor(color(0xFF5A1F)); c.setLineWidth(size <= 32 ? 62 : 58)
    c.move(to: CGPoint(x: 310, y: 350)); c.addLine(to: CGPoint(x: 615, y: 611)); c.strokePath()
    c.setFillColor(color(0xF1EBD0))
    c.fillEllipse(in: CGRect(x: 245, y: 285, width: 130, height: 130))
    c.fillEllipse(in: CGRect(x: 649, y: 609, width: 130, height: 130))
    c.restoreGState()
    if size >= 32 {
        c.addPath(tile); c.setStrokeColor(CGColor(gray: 1, alpha: 0.20)); c.setLineWidth(2); c.strokePath()
    }
    guard let image = c.makeImage(), let destination = CGImageDestinationCreateWithURL(
        output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw NSError(domain: "Icon", code: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "Icon", code: 2) }
}
for size in [16, 32, 128, 256, 512] {
    try render(size, name: "icon_\(size)x\(size).png")
    try render(size * 2, name: "icon_\(size)x\(size)@2x.png")
}
print("Rendered Contact icon: \(output.path)")
