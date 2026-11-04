// Offline rendering of this project's inert SVG artwork; no browser or JavaScript.
import AppKit
import Foundation
let root = URL(fileURLWithPath: "docs/brand")
for name in ["hero", "icon", "wordmark"] {
    let svg = root.appendingPathComponent(name + ".svg")
    guard let source = NSImage(contentsOf: svg) else { throw NSError(domain: "VectorRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(svg.path)"]) }
    var bounds = CGRect(origin: .zero, size: source.size)
    guard let image = source.cgImage(forProposedRect: &bounds, context: nil, hints: nil),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "VectorRender", code: 2)
    }
    try png.write(to: root.appendingPathComponent(name + ".png"))
    print("Rendered \(name): \(source.size)")
}
