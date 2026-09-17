import SwiftUI
import AppKit
import OndeCore

struct PageHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 29, weight: .regular, design: .serif)).tracking(-0.7)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted) }
        }
    }
}

struct MixerRow: View {
    @EnvironmentObject var model: AppModel
    var sound: Sound
    var volume: Double { model.store.layers[sound.id]?.volume ?? 0.5 }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sound.symbol).font(.system(size: 17, weight: .light)).foregroundStyle(Theme.accent).frame(width: 39, height: 43).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(sound.title).font(.system(size: 11, weight: .medium)).lineLimit(1); Spacer(); Text("\(Int(volume * 100)) %").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted) }
                Slider(value: Binding(get: { volume }, set: { model.setSound(sound.id, volume: $0) }), in: 0...1).tint(Theme.accent).controlSize(.mini).accessibilityLabel("Volume for \(sound.title)")
            }
            Button { model.setSound(sound.id, enabled: false) } label: { Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(Theme.muted).frame(width: 18, height: 24) }.buttonStyle(.plain).help("Disable \(sound.title)")
        }.padding(.horizontal, 15).padding(.vertical, 13).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var markers = ""
    @State private var markerError = ""
    var body: some View {
        DefaultMusicSettings()
        Panel {
            VStack(alignment: .leading, spacing: 21) {
                HStack { Image(systemName: "bell.badge").foregroundStyle(Theme.accent(.meditation)); Text("Meditation chimes").font(.system(size: 21, design: .serif)); Spacer(); Toggle("Enable chimes", isOn: Binding(get: { model.store.preferences.chimesEnabled }, set: { value in _ = model.handle(["command":"settings","key":"chimesEnabled","value":value]) })).labelsHidden().toggleStyle(.switch).tint(Theme.accent(.meditation)) }
                Text("A soft glass chime marks each milestone. After the last one, no further chimes play and the stopwatch keeps going.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                VStack(alignment: .leading, spacing: 9) {
                    Text("Chime times in minutes from the start of the session").font(.system(size: 11, weight: .medium))
                    HStack(spacing: 10) {
                        TextField("10, 20, 30", text: $markers).textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(12).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 9)).onSubmit(saveMarkers)
                        PillButton(title: "Apply", symbol: "checkmark", primary: true, action: saveMarkers)
                        Button("Defaults") { markers = "10, 20, 30"; saveMarkers() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    if !markerError.isEmpty { Text(markerError).font(.system(size: 11)).foregroundStyle(.orange) }
                    Text("Separate minutes with commas, such as 5, 15, 25. Leave empty for no chimes. Past markers are not replayed.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
                Divider().overlay(Theme.line)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) { Text("Chime level").font(.system(size: 12, weight: .medium)); Text("Also affected by master volume.").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                    Spacer()
                    Slider(value: Binding(get: { model.store.preferences.chimeVolume }, set: model.setChime), in: 0...1).frame(width: 145).tint(Theme.accent(.meditation)).accessibilityLabel("Chime volume")
                    Text("\(Int(model.store.preferences.chimeVolume * 100)) %").font(.system(size: 11, design: .monospaced)).frame(width: 40)
                    PillButton(title: "Listen", symbol: "bell") { model.previewChime() }
                }
            }
        }
        Panel {
            VStack(alignment: .leading, spacing: 23) {
                Text("Sound without interruptions").font(.system(size: 21, design: .serif))
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Gentle start", systemImage: "sun.horizon").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(model.store.preferences.startFadeSeconds == 0 ? "Off" : "\(Int(model.store.preferences.startFadeSeconds)) s")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                    Text("Let music emerge from silence instead of arriving at full volume. Resuming fades in over up to two seconds. Your chosen volume and meditation chimes stay unchanged.")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    Slider(value: Binding(get: { model.store.preferences.startFadeSeconds }, set: {
                        _ = model.handle(["command": "settings", "key": "startFadeSeconds", "value": $0])
                    }), in: 0...20, step: 1).tint(Theme.accent).accessibilityLabel("Gentle start duration in seconds")
                    HStack { Text("Off"); Spacer(); Text("20 seconds") }.font(.system(size: 9)).foregroundStyle(Theme.muted)
                }
                Divider().overlay(Theme.line)
                HStack { VStack(alignment: .leading, spacing: 5) { Text("Recorded-layer smoothing").font(.system(size: 12, weight: .medium)); Text("For imported audio and background layers. Music crossfades are on the main screen.").font(.system(size: 10)).foregroundStyle(Theme.muted) }; Spacer(); Slider(value: Binding(get: { model.store.preferences.fadeSeconds }, set: { model.store.preferences.fadeSeconds = $0; model.persist() }), in: 0...10, step: 0.5).frame(width: 180).tint(Theme.accent); Text(String(format: "%.1f s", model.store.preferences.fadeSeconds)).font(.system(size: 11, design: .monospaced)).frame(width: 45) }
                Toggle(isOn: Binding(get: { model.store.preferences.preventSleep }, set: { _ = model.handle(["command":"settings","key":"preventSleep","value":$0]) })) { VStack(alignment: .leading, spacing: 5) { Text("Keep playing with the display off").font(.system(size: 12, weight: .medium)); Text("Prevents automatic system sleep. Closing the lid or putting your Mac to sleep pauses the session.").font(.system(size: 10)).foregroundStyle(Theme.muted) } }.toggleStyle(.switch).tint(Theme.accent)
                Toggle(isOn: Binding(get: { model.store.preferences.reducedMotion }, set: { model.store.preferences.reducedMotion = $0; model.persist() })) { VStack(alignment: .leading, spacing: 5) { Text("Reduce motion").font(.system(size: 12, weight: .medium)); Text("Keep the visual soundscape still.").font(.system(size: 10)).foregroundStyle(Theme.muted) } }.toggleStyle(.switch).tint(Theme.accent)
            }
        }
        .onAppear { updateMarkers() }
        .onChange(of: model.store.preferences.markers) { _, _ in updateMarkers() }
    }
    func updateMarkers() { markers = model.store.preferences.markers.map { String(format: "%g", $0 / 60) }.joined(separator: ", ") }
    func saveMarkers() {
        let trimmed = markers.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.isEmpty ? [] : trimmed.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap(Double.init)
        guard numbers.count == parts.count else { markerError = "Use numbers separated by commas."; return }
        do { try model.setMarkers(numbers.map { $0 * 60 }); markerError = ""; model.notify("Chime times updated.") } catch { markerError = error.localizedDescription }
    }
}

struct QuietView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ZStack {
            Theme.sidebar
            OrbitalArt(mode: model.mode, animated: model.playing && !model.store.preferences.reducedMotion).frame(width: 650, height: 650).opacity(0.19)
            VStack(spacing: 20) {
                Eyebrow(text: model.mode.title, color: Theme.accent(model.mode).opacity(0.7))
                Text(clockText(model.elapsed)).font(.system(size: 96, weight: .ultraLight, design: .rounded)).monospacedDigit().tracking(-4).foregroundStyle(Theme.ink.opacity(0.8))
                Text(quietCaption).font(.system(size: 12)).foregroundStyle(Theme.muted.opacity(0.65))
                Button { model.togglePlayback() } label: { Image(systemName: model.playing ? "pause" : "play").font(.system(size: 19, weight: .ultraLight)).foregroundStyle(Theme.muted).frame(width: 50, height: 50).overlay(Circle().stroke(Theme.line)) }.buttonStyle(.plain).padding(.top, 20)
            }
            VStack { HStack { Spacer(); PillButton(title: "Leave quiet view", symbol: "arrow.down.right.and.arrow.up.left") { model.quietView = false } }; Spacer(); Text("Nothing to achieve.").font(.system(size: 15, weight: .regular, design: .serif)).foregroundStyle(Theme.muted.opacity(0.4)) }.padding(30)
        }
    }
    var quietCaption: String {
        guard model.mode == .meditation else { return "Just a little breathing room." }
        if let marker = model.nextMarker { return "Next chime at \(clockText(marker)). Stay as long as you like." }
        return "No more chimes. The timer keeps going."
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow: "No scores. No competition.", title: "Time you made for yourself.", subtitle: "Completed sessions, stored locally. No targets to meet.")
        if (model.store.activityLedger?.legacyRecordCount ?? 0) > 0 {
            Text("Daily totals imported from older versions are estimates because exact pause times were not recorded. New sessions track active intervals precisely.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
        }
        if model.store.history.isEmpty { Panel { Text("Your completed sessions will appear here.").font(.system(size: 13)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading) } }
        ForEach(model.store.history.prefix(50)) { session in
            HStack(spacing: 15) {
                Image(systemName: session.mode.symbol).foregroundStyle(Theme.accent(session.mode)).frame(width: 25)
                Text(session.mode.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(session.date, format: .dateTime.day().month().hour().minute()).font(.system(size: 11)).foregroundStyle(Theme.muted)
                Text(clockText(session.seconds)).font(.system(size: 15, design: .monospaced)).frame(width: 90, alignment: .trailing)
            }.padding(20).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct CLIGuideView: View {
    @EnvironmentObject var model: AppModel
    let examples = AgentExamples.commands
    var body: some View {
        PageHeader(eyebrow: "Agent-ready", title: "The same control. No clicking.", subtitle: "The native CLI controls the running app. Every response is a JSON object.")
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                HStack { Text("One state. Two interfaces.").font(.system(size: 22, design: .serif)); Spacer(); PillButton(title: "Copy", symbol: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(examples, forType: .string); model.notify("Commands copied.") } }
                Text("The app and CLI share the same engine. No network port: a private UNIX socket accessible only to your macOS user.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                Text(examples).font(.system(size: 12, design: .monospaced)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 12))
                Text("Optional CLI shortcut: ~/.local/bin/onde\nThe bundled CLI is Onde.app/Contents/MacOS/ondectl. --launch opens the app when needed. onde schema describes every command for agents.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(5).textSelection(.enabled)
            }
        }
    }
}

struct CreditsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow: "Onde · \(AppBuild.version)", title: "A little calm. No account required.", subtitle: "Native macOS. Open source, local library, no telemetry.")
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                Text("A sound studio, not a medical claim.").font(.system(size: 21, design: .serif))
                Text("Onde offers a customizable sound environment. These compositions have not been clinically validated. No universal improvement in concentration, relaxation or meditation is guaranteed.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Text("Code: MIT. Original compositions and VSCO 2 CE instruments: CC0. Personal imports remain private and are never included in public builds.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Link("MIT license", destination: URL(string: "https://opensource.org/license/mit")!).font(.system(size: 11)).tint(Theme.accent)
            }
        }
        Panel {
            VStack(alignment:.leading,spacing:10) {
                Text("Acoustic instruments").font(.system(size:21,design:.serif))
                Text("76 VSCO 2 Community Edition recordings, including piano. Versilian Studios, Sam Gossner and contributors. CC0 1.0. Trimmed edges, balanced levels and gentle filtering; stereo preserved.").font(.system(size:12)).foregroundStyle(Theme.muted).lineSpacing(4)
                Link("Instrument source and license",destination:URL(string:"https://github.com/sgossner/VSCO-2-CE")!).font(.system(size:11)).tint(Theme.accent)
            }
        }
        ForEach(model.sounds.filter { !$0.imported }) { sound in
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(sound.title).font(.system(size: 14, weight: .medium)); Spacer(); Text(sound.license).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.accent) }
                Text(sound.author).font(.system(size: 11)).foregroundStyle(Theme.muted)
                if sound.source.hasPrefix("https://"), let url = URL(string: sound.source) { Link("Official source", destination: url).font(.system(size: 10)).tint(Theme.accent) }
                if sound.license == "CC BY 4.0" {
                    Link("Creative Commons Attribution 4.0 · unmodified audio file", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).font(.system(size: 10)).tint(Theme.muted)
                } else { Text(sound.id == "living" ? "Original synthesis and/or CC0 acoustic instruments, depending on the profile." : "Generated by the included script. Nature textures are synthesized.").font(.system(size: 10)).foregroundStyle(Theme.muted) }
            }.padding(20).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
