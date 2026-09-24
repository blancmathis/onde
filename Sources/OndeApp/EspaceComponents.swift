import SwiftUI
import AppKit
import Combine
import OndeCore

/// Scoped palette. Legacy screens keep working; no external assets or fonts.
enum EspaceTheme {
    static let background = Color(hex: 0x111718)
    static let surface = Color(hex: 0x192122)
    static let raised = Color(hex: 0x232E2D)
    static let ink = Color(hex: 0xEFF1E9)
    static let secondary = Color(hex: 0xA3AFAD)
    static let line = Color(hex: 0x303B3B)
    static func accent(_ mode: SessionMode) -> Color {
        switch mode { case .focus: return Color(hex: 0xC6DFC2); case .relax: return Color(hex: 0xE7CBB1); case .meditation: return Color(hex: 0xD3CBE9) }
    }
    static func shade(_ mode: SessionMode, light: Double) -> Color {
        let a: [Double]; let b: [Double]
        switch mode {
        case .focus: a = [175, 212, 173]; b = [43, 83, 70]
        case .relax: a = [222, 188, 150]; b = [98, 73, 57]
        case .meditation: a = [190, 186, 220]; b = [66, 69, 106]
        }
        return Color(.sRGB, red: (b[0] + (a[0] - b[0]) * light) / 255,
                     green: (b[1] + (a[1] - b[1]) * light) / 255,
                     blue: (b[2] + (a[2] - b[2]) * light) / 255, opacity: 1)
    }
}

struct EspaceButtonStyle: ButtonStyle {
    var primary = false
    var tint = EspaceTheme.accent(.focus)
    func makeBody(configuration: Configuration) -> some View {
        EspaceButtonBody(configuration: configuration, primary: primary, tint: tint)
    }
    private struct EspaceButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let primary: Bool
        let tint: Color
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused
        @Environment(\.espaceReduceMotion) private var reduced
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hovered = false
        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: primary ? .semibold : .medium))
                .padding(.horizontal, primary ? 21 : 13).frame(minHeight: primary ? 46 : 38)
                .foregroundStyle(primary ? EspaceTheme.background : EspaceTheme.ink)
                .background(primary ? tint : hovered ? EspaceTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(focused ? tint : primary ? .clear : contrast == .increased ? EspaceTheme.secondary : EspaceTheme.line, lineWidth: focused ? 2 : 1))
                .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
                .scaleEffect(configuration.isPressed && !reduced ? 0.985 : 1)
                .animation(reduced ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

struct EspaceIconButton: View {
    let symbol: String
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 15, weight: .regular)).frame(width: 32, height: 38) }
            .buttonStyle(.borderless).foregroundStyle(EspaceTheme.secondary)
            .accessibilityLabel(title).help(title)
    }
}

struct EspaceThumbnail: View {
    let id: String
    let mode: SessionMode
    var body: some View { EspaceCover(id: id).equatable() }
}
