import AppKit
import SwiftUI

/// Semantic Contact colors. System foregrounds and controls keep their native contrast.
enum BridgeStyle {
    static let orange = Color(red: 1, green: 90.0 / 255, blue: 31.0 / 255)
    static let surface = adaptive("Contact surface", light: 0xF5F3EC, dark: 0x292B28)
    static let well = adaptive("Contact control well", light: 0xFFFFFF, dark: 0x353732)
    static let selection = adaptive("Contact selection", light: 0xE3E1D8, dark: 0x42453E)
    static let spacing: CGFloat = 16
    static let radius: CGFloat = 7
    static func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.6).foregroundStyle(.secondary)
    }
    private static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

/// One native material at the root, with a light color wash. Forms do not stack blur.
struct BridgeBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var solid: Bool {
        #if FXRELAY_PREVIEW
        if ContactPreviewAppearance.accessible { return true }
        #endif
        return reduceTransparency || contrast == .increased
    }
    var body: some View {
        ZStack {
            if solid { BridgeStyle.surface }
            else {
                Rectangle().fill(.regularMaterial)
                BridgeStyle.surface.opacity(0.65)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct BridgeWell: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    private var highContrast: Bool {
        #if FXRELAY_PREVIEW
        if ContactPreviewAppearance.accessible { return true }
        #endif
        return contrast == .increased
    }
    func body(content: Content) -> some View {
        content.background(BridgeStyle.well, in: RoundedRectangle(cornerRadius: BridgeStyle.radius))
            .overlay(RoundedRectangle(cornerRadius: BridgeStyle.radius)
                .strokeBorder(.primary.opacity(highContrast ? 0.5 : 0.12)))
    }
}
extension View {
    func bridgeWell() -> some View { modifier(BridgeWell()) }
    func bridgeSurface() -> some View {
        font(.system(size: 13)).tint(BridgeStyle.orange).background(BridgeBackdrop())
    }
}

/// Original relay-contact geometry. The open gap is retained at menu-bar size.
struct ContactTerminals: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 1, y: 12)); p.addLine(to: CGPoint(x: 3, y: 12))
        p.move(to: CGPoint(x: 13, y: 4)); p.addLine(to: CGPoint(x: 15, y: 4))
        p.addEllipse(in: CGRect(x: 3, y: 10.5, width: 3, height: 3))
        p.addEllipse(in: CGRect(x: 10, y: 2.5, width: 3, height: 3))
        return p.strokedPath(.init(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .applying(.init(scaleX: rect.width / 16, y: rect.height / 16))
    }
}
struct ContactArm: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 5.6, y: 10.7)); p.addLine(to: CGPoint(x: 9.15, y: 7.15))
        return p.strokedPath(.init(lineWidth: 1.8, lineCap: .round))
            .applying(.init(scaleX: rect.width / 16, y: rect.height / 16))
    }
}
struct ContactSymbol: View {
    var accented = true
    var body: some View {
        ZStack {
            ContactTerminals().fill(.primary)
            ContactArm().fill(accented ? BridgeStyle.orange : Color.primary)
        }.accessibilityHidden(true)
    }
}
struct BridgeBrand: View {
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            ContactSymbol().frame(width: compact ? 22 : 24, height: compact ? 22 : 24)
            Text("FX Relay").font(.system(size: compact ? 14 : 16, weight: .semibold))
        }.fixedSize()
    }
}

struct BridgePageHeading: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if FXRELAY_PREVIEW
// Only the screenshot executable can force the solid/high-contrast fallback.
enum ContactPreviewAppearance { static var accessible = false }
#endif
