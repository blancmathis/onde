import SwiftUI
import OndeCore

/// Small static covers: recognition without a second animated surface.
struct EspaceCover: View {
    let id: String
    private var family: Int { ListeningDesign.coverFamily(id) }
    private var tint: Color {
        Color(hex: [UInt32(0x9CC8C0), 0xE0C6A0, 0xA7B7D7, 0xC7BDDE, 0xB7CA9A, 0x9FC3CE][family])
    }
    var body: some View {
        Group {
            if EspaceRenderingSupport.needsSoftwareCanvas { EspaceSoftwareCover(family: family, tint: tint) }
            else {
        Canvas { context, size in
            for line in 0..<8 {
                let f = Double(line) / 7
                var path = Path()
                for j in 0...48 {
                    let u = Double(j) / 48
                    let t = u * .pi * 2
                    let x: Double; let y: Double
                    switch family {
                    case 1:
                        x = 0.5 + (0.08 + f * 0.4) * cos(t)
                        y = 0.5 + (0.11 + f * 0.36) * sin(t)
                    case 2:
                        x = 0.09 + u * 0.82
                        y = 0.24 + f * 0.56 + 0.15 * abs(sin(u * .pi * 2 + f * 0.25)) - u * 0.2
                    case 3:
                        x = 0.13 + f * 0.74 + 0.045 * sin(u * .pi * 2 + f)
                        y = 0.1 + u * 0.8
                    case 4:
                        x = 0.08 + u * 0.84
                        y = 0.5 + (f - 0.5) * 0.82 * sin(u * .pi) - (u - 0.5) * 0.45
                    case 5:
                        x = 0.5 + (0.12 + f * 0.48) * cos(t)
                        y = 0.5 + (0.04 + f * 0.24) * sin(t)
                    default:
                        x = u
                        y = 0.24 + f * 0.49 + sin(u * .pi * 2 - f * 0.25) * 0.095
                    }
                    let p = CGPoint(x: x * size.width, y: y * size.height)
                    if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(tint.opacity(0.32 + f * 0.35)), lineWidth: 0.65)
            }
        }
            }
        }
        .frame(width: 46, height: 52)
        .background(LinearGradient(colors: [tint.opacity(0.15), EspaceTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.09)))
        .accessibilityHidden(true)
    }
}

struct EspaceRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { RowAppearance(configuration: configuration) }
    private struct RowAppearance: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? EspaceTheme.ink : .clear, lineWidth: 2))
        }
    }
}
