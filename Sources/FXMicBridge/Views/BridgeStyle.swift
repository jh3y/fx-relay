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
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 8 : 10).fill(Color(red: 0.12, green: 0.13, blue: 0.13))
                BridgeMark().fill(Color(red: 0.94, green: 0.93, blue: 0.88))
                    .frame(width: compact ? 27 : 34, height: compact ? 27 : 34).offset(x: -3)
                Circle().fill(BridgeStyle.orange).frame(width: compact ? 5 : 6, height: compact ? 5 : 6).offset(x: compact ? 10 : 12, y: 2)
            }
            .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("FX RELAY").font(.system(size: compact ? 13 : 16, weight: .semibold, design: .monospaced)).tracking(1)
                BridgeStyle.label("AUDIO / ACTION")
            }
        }
    }
}
