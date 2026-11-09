import AppKit

/// A separate template drawing, optically tuned for an 18-point menu item.
/// State changes the contact itself; no extra status dot competes with the mark.
@MainActor enum MenuBarGlyph {
    private static var cache: [String: NSImage] = [:]
    static func image(status: String) -> NSImage {
        if let image = cache[status] { return image }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke(); NSColor.black.setFill()
            func line(_ start: NSPoint, _ end: NSPoint, width: CGFloat = 1.65) {
                let p = NSBezierPath(); p.lineWidth = width; p.lineCapStyle = .round
                p.move(to: start); p.line(to: end); p.stroke()
            }
            let left = NSPoint(x: 5, y: 4.5), right = NSPoint(x: 13, y: 13)
            line(NSPoint(x: 1.5, y: 4.5), NSPoint(x: 3.5, y: 4.5))
            line(NSPoint(x: 14.5, y: 13), NSPoint(x: 16.5, y: 13))
            for center in [left, right] {
                let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 1.6, y: center.y - 1.6, width: 3.2, height: 3.2))
                ring.lineWidth = 1.55
                if status == "bolt.circle.fill" { ring.fill() } else { ring.stroke() }
            }
            if status == "mic.slash" {
                line(NSPoint(x: 6.2, y: 5.8), NSPoint(x: 7.2, y: 6.8))
                line(NSPoint(x: 9.3, y: 8.8), NSPoint(x: 10.2, y: 9.7))
            } else if status == "exclamationmark.triangle" {
                line(NSPoint(x: 8.8, y: 9.2), NSPoint(x: 8.8, y: 12.8), width: 1.5)
                NSBezierPath(ovalIn: NSRect(x: 8.05, y: 6.4, width: 1.5, height: 1.5)).fill()
            } else {
                let closed = status == "keyboard.fill" || status == "waveform.circle.fill" || status == "bolt.circle.fill"
                line(NSPoint(x: 6.2, y: 5.8), closed ? NSPoint(x: 11.8, y: 11.8) : NSPoint(x: 10.3, y: 9.8), width: 1.8)
            }
            return true
        }
        image.isTemplate = true; cache[status] = image
        return image
    }
}
