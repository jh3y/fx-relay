import SwiftUI

enum BridgeStyle {
    static let orange = Color(red: 0.94, green: 0.29, blue: 0.10)
    static func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(.secondary)
    }
}

/// Original geometric microphone mark, also used in the application icon.
struct BridgeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 17, y: 3, width: 30, height: 36), cornerSize: CGSize(width: 10, height: 10))
        p.addRoundedRect(in: CGRect(x: 27, y: 37, width: 10, height: 24), cornerSize: CGSize(width: 4, height: 4))
        p.addRoundedRect(in: CGRect(x: 39, y: 40, width: 8, height: 14), cornerSize: CGSize(width: 3, height: 3))
        return p.applying(CGAffineTransform(scaleX: rect.width / 64, y: rect.height / 64))
    }
}

struct BridgeBrand: View {
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                BridgeMark().fill(.primary).frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                Circle().fill(BridgeStyle.orange).frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("FX RELAY").font(.system(size: compact ? 12 : 15, weight: .semibold, design: .monospaced)).tracking(1)
                BridgeStyle.label("AUDIO / ACTION")
            }
        }
    }
}
