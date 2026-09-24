import SwiftUI
import OndeCore

/// Small static covers: recognition without a second animated surface.
struct EspaceCover: View, Equatable {
    let id: String
    private var motif: OndeMotif { OndeMotif.forMusic(id) }
    private var tint: Color { Color(hex: MusicArtworkIdentity.color(motif)) }
    var body: some View {
        Image(nsImage: EspacePosterCache.image(motif))
            .interpolation(.high).frame(width: 46, height: 52)
            .background(LinearGradient(colors: [tint.opacity(0.13), EspaceTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
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
