import SwiftUI
import AppKit
import OndeCore

/// The same player in a compact surface. No decorative animation or new state.
struct EspaceMenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("onde").font(.system(size: 28, design: .serif)).tracking(-1).fixedSize()
                Spacer()
                Label(model.mode.title, systemImage: model.mode.symbol)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(EspaceTheme.accent(model.mode))
            }
            HStack(spacing: 13) {
                EspaceCover(id: model.selectedMusicID ?? "personal")
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.currentMusicTitle).font(.system(size: 21, design: .serif)).lineLimit(2)
                    Text(model.playing ? "Session active" : model.elapsed > 0 ? "Paused" : "Ready to play")
                        .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                Button { model.togglePlayback() } label: {
                    Label(model.playing ? "Pause" : model.elapsed > 0 ? "Resume" : "Play", systemImage: model.playing ? "pause.fill" : "play.fill")
                }.buttonStyle(EspaceButtonStyle(primary: true, tint: EspaceTheme.accent(model.mode)))
                Spacer(minLength: 0)
                Text(clockText(model.elapsed)).font(.system(size: 24, weight: .light)).monospacedDigit()
                    .accessibilityLabel("Elapsed \(clockText(model.elapsed))")
                EspaceIconButton(symbol: "stop", title: "End session") { model.stop() }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Start a mode").font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary)
                HStack(spacing: 5) {
                    ForEach(SessionMode.allCases) { mode in
                        Button { model.startDefaultMode(mode) } label: {
                            Text(mode.title).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 34)
                                .background(model.mode == mode ? EspaceTheme.raised : EspaceTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(EspaceRowButtonStyle())
                            .foregroundStyle(model.mode == mode ? EspaceTheme.accent(mode) : EspaceTheme.ink)
                            .accessibilityLabel("Start \(mode.title) with \(model.defaultMusicTitle(for: mode))")
                            .help("Start \(mode.title) with \(model.defaultMusicTitle(for: mode))")
                    }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: model.store.preferences.masterVolume == 0 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 13)).foregroundStyle(EspaceTheme.secondary)
                Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1)
                    .accessibilityLabel("Master volume")
                Text("\(Int(model.store.preferences.masterVolume * 100))%")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(EspaceTheme.secondary).frame(width: 32)
            }
            Divider().overlay(EspaceTheme.line)
            HStack {
                Button { openWindow(id: "main"); model.showWindow() } label: { Label("Open Onde", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.borderless).font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless).font(.system(size: 12))
                    .foregroundStyle(EspaceTheme.secondary)
            }
        }.padding(20).frame(width: 340)
            .background(EspaceTheme.background).foregroundStyle(EspaceTheme.ink)
            .tint(EspaceTheme.accent(model.mode)).preferredColorScheme(.dark)
            .environment(\.espaceReduceMotion, systemReduced || model.store.preferences.reducedMotion)
    }
}
