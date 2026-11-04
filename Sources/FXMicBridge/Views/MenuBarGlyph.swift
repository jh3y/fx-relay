import AppKit

/// A template mic/control mark that remains identifiable in every status.
@MainActor enum MenuBarGlyph {
    private static var cache: [String: NSImage] = [:]
    static func image(status: String) -> NSImage {
        if let image = cache[status] { return image }
        let image = NSImage(size: NSSize(width: 23, height: 18), flipped: false) { _ in
            NSColor.black.setFill(); NSColor.black.setStroke()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 6, width: 10, height: 11), xRadius: 3, yRadius: 3).fill()
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 1, width: 3, height: 8), xRadius: 1, yRadius: 1).fill()
            NSBezierPath(roundedRect: NSRect(x: 10, y: 2, width: 2.5, height: 4.5), xRadius: 1, yRadius: 1).fill()
            let dot = NSBezierPath(ovalIn: NSRect(x: 16, y: 5.5, width: 5, height: 5))
            if status == "mic" { dot.lineWidth = 1; dot.stroke() }
            else if status == "mic.slash" || status == "exclamationmark.triangle" {
                let mark = NSBezierPath(); mark.move(to: NSPoint(x: 16, y: 4)); mark.line(to: NSPoint(x: 21, y: 12)); mark.lineWidth = 1.5; mark.stroke()
            } else if status == "bolt.circle.fill" {
                let square = NSBezierPath(rect: NSRect(x: 16, y: 5.5, width: 5, height: 5)); square.fill()
            } else if status == "keyboard.fill" {
                NSBezierPath(roundedRect: NSRect(x: 16, y: 3, width: 5, height: 10), xRadius: 2, yRadius: 2).fill()
            } else { dot.fill() }
            return true
        }
        image.isTemplate = true; cache[status] = image
        return image
    }
}
