import SwiftUI
import AppKit
import OndeCore

struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Group {
            if model.quietView { QuietView() }
            else { ListeningView() }
        }
        .frame(minWidth: 940, minHeight: 680)
        .background(Theme.background).foregroundStyle(Theme.ink).preferredColorScheme(.dark)
        .sheet(item: $model.sheet, onDismiss: { model.page = "studio" }) { sheet in
            ListeningSheetView(sheet: sheet).environmentObject(model)
                .environment(\.locale, Locale(identifier: "en"))
        }
        .overlay(alignment: .top) {
            if let text = model.toast {
                Text(text).font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.raised, in: Capsule()).shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    .padding(.top, 8).allowsHitTesting(false)
            }
        }
        .alert("Onde", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Close", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct ListeningView: View {
    @EnvironmentObject var model: AppModel
    @State private var moreMusic = false
    private var featured: [SoundProfile] {
        model.musicProfiles.filter { model.mode != .focus || FocusCompositions.ids.contains($0.id) }
    }
    private var others: [SoundProfile] {
        model.musicProfiles.filter { model.mode == .focus && !FocusCompositions.ids.contains($0.id) }
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 10) {
                ForEach(SessionMode.allCases) { mode in ListeningModeButton(mode: mode) }
            }.padding(.horizontal, 30).padding(.bottom, 22)
            HStack(alignment: .top, spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(model.mode == .focus ? "Find your focus." : model.mode == .relax ? "Let the day settle." : "Make time for stillness.")
                                .font(.system(size: 27, design: .serif)).tracking(-0.5)
                            Spacer()
                            Label("Generative", systemImage: "infinity").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        }
                        Text(model.mode == .meditation ? "Relax music, with your meditation timer and chimes." : "Choose music for now. The star sets your default for next time.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 207), spacing: 12)], spacing: 12) {
                            ForEach(featured) { profile in ListeningMusicCard(profile: profile) }
                        }
                        if !others.isEmpty {
                            DisclosureGroup(isExpanded: $moreMusic) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 207), spacing: 12)], spacing: 12) {
                                    ForEach(others) { profile in ListeningMusicCard(profile: profile) }
                                }.padding(.top, 14)
                            } label: {
                                Text("More focus music · \(others.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                            }.padding(.top, 4)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield").font(.system(size: 10))
                            Text("Composed on your Mac. No account, no streaming.").font(.system(size: 10))
                        }.foregroundStyle(Theme.muted.opacity(0.8)).padding(.top, 4)
                    }.padding(.bottom, 24)
                }.scrollIndicators(.hidden)
                ListeningControls().frame(width: 268)
            }.padding(.horizontal, 30)
            CompactUpdateBanner(updates: model.updates)
            ListeningPlayerBar()
        }
        .onAppear { revealCurrentMusic() }
        .onChange(of: model.mode) { _, _ in revealCurrentMusic() }
        .onChange(of: model.selectedMusicID) { _, _ in revealCurrentMusic() }
    }
    private func revealCurrentMusic() {
        moreMusic = others.contains { $0.id == model.selectedMusicID }
    }
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path").font(.system(size: 25, weight: .light)).foregroundStyle(Theme.accent(model.mode))
            Text("onde").font(.system(size: 34, design: .serif)).tracking(-1.4)
            Spacer()
            Button { model.sheet = .history } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 11))
                    Text("\(Int(model.todaySeconds / 60)) min today").font(.system(size: 12)).monospacedDigit()
                }.foregroundStyle(Theme.muted)
            }.buttonStyle(.plain).help("Active time in your local day. Pauses do not count.")
            Rectangle().fill(Theme.line).frame(width: 1, height: 22).padding(.horizontal, 9)
            Button { model.sheet = .settings } label: {
                Image(systemName: "gearshape").font(.system(size: 17)).frame(width: 32, height: 34)
            }.buttonStyle(.plain).foregroundStyle(Theme.muted).help("Settings · ⌘,").accessibilityLabel("Settings")
            Menu {
                Button("Personal audio & mixes…") { model.sheet = .personal }
                Button("Session history…") { model.sheet = .history }
                Divider()
                Button("Agent & CLI…") { model.sheet = .cli }
                Button("Check for Updates…") { model.sheet = .updates; model.updates.check() }
                Button("About & credits…") { model.sheet = .credits }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18)).frame(width: 32, height: 34)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Theme.muted).accessibilityLabel("More options")
        }.padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 25)
    }
}

struct ListeningModeButton: View {
    @EnvironmentObject var model: AppModel
    let mode: SessionMode
    private var selected: Bool { model.mode == mode }
    var body: some View {
        Button { model.startDefaultMode(mode) } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol).font(.system(size: 20, weight: .light)).frame(width: 23)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title).font(.system(size: 14, weight: .semibold))
                    Text("Default · \(model.defaultMusicTitle(for: mode))").font(.system(size: 10)).opacity(0.75).lineLimit(1)
                }
                Spacer(minLength: 2)
                Image(systemName: "play.fill").font(.system(size: 9)).opacity(selected ? 0.9 : 0.45)
            }
            .padding(.horizontal, 18).padding(.vertical, 16).frame(maxWidth: .infinity)
            .foregroundStyle(selected ? Theme.sidebar : Theme.ink)
            .background(selected ? Theme.accent(mode) : Theme.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.clear : Theme.line))
        }.buttonStyle(.plain).help("Start \(mode.title) with \(model.defaultMusicTitle(for: mode))")
            .accessibilityLabel("Start \(mode.title) with \(model.defaultMusicTitle(for: mode))")
            .accessibilityIdentifier("mode-\(mode.rawValue)")
    }
}

struct ListeningMusicCard: View {
    @EnvironmentObject var model: AppModel
    let profile: SoundProfile
    @State private var hovered = false
    private var selected: Bool { model.selectedMusicID == profile.id }
    private var isDefault: Bool { model.defaultMusicID(for: model.mode) == profile.id }
    private var detail: String {
        switch profile.id {
        case "ambre": return "Warm electric keys & piano"
        case "canopee": return "Wooden tones, harp & low strings"
        case "meridien": return "Deep bass & minimal house"
        case "sillage": return "Driving bass & dark electronic motifs"
        case "filigrane": return "Soft acoustic piano"
        case "confluence": return "Strings, horns & a steady pulse"
        case "sanctuaire": return "Wordless voices & a deep bass"
        case "velours": return "Warm keys, soft and spacious"
        case "rive": return "Broad pads & a gentle pulse"
        case "immersion": return "Continuous ambient, without a beat"
        default: return profile.description
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                do { try model.selectMusic(profile.id, in: model.mode) } catch { model.fail(error) }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        MusicGlyph(id: profile.id, tint: Theme.accent(model.mode)).frame(width: 62, height: 22)
                        Spacer()
                        Image(systemName: selected && model.playing ? "waveform" : "play.circle")
                            .font(.system(size: 19, weight: .light)).opacity(selected || hovered ? 1 : 0.5)
                    }.foregroundStyle(Theme.accent(model.mode))
                    Text(profile.title).font(.system(size: 24, design: .serif)).tracking(-0.4).foregroundStyle(Theme.ink)
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                }.padding(.horizontal, 17).padding(.top, 16).padding(.bottom, 7).contentShape(Rectangle())
            }.buttonStyle(.plain).help(selected && !model.playing ? "Restart \(profile.title) with a gentle fade" : "Play \(profile.title)")
                .accessibilityLabel("Play \(profile.title)").accessibilityIdentifier("music-card-\(profile.id)")
            HStack(spacing: 6) {
                Text(selected ? (model.playing ? "SELECTED" : "READY") : "GENERATIVE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(selected ? Theme.accent(model.mode) : Theme.muted.opacity(0.65))
                Spacer(minLength: 4)
                Button {
                    do { try model.setDefaultMusic(profile.id, for: model.mode) } catch { model.fail(error) }
                } label: {
                    HStack(spacing: 4) {
                        if isDefault { Text("Default").font(.system(size: 9, weight: .medium)) }
                        Image(systemName: isDefault ? "star.fill" : "star").font(.system(size: 11))
                    }.padding(.vertical, 7).padding(.leading, 8)
                        .foregroundStyle(isDefault ? Theme.accent(model.mode) : Theme.muted)
                }.buttonStyle(.plain).disabled(isDefault)
                    .help("Make \(profile.title) the default for \(model.mode.title). Does not start playback.")
                    .accessibilityLabel(isDefault ? "\(profile.title) is the default for \(model.mode.title)" : "Set \(profile.title) as \(model.mode.title) default")
                    .accessibilityIdentifier("default-\(profile.id)")
            }.padding(.horizontal, 17).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.raised : hovered ? Theme.raised.opacity(0.6) : Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Theme.accent(model.mode).opacity(0.7) : Theme.line, lineWidth: selected ? 1.4 : 1))
        .onHover { hovered = $0 }
    }
}
struct MusicGlyph: View {
    let id: String
    let tint: Color
    var body: some View {
        Canvas { context, size in
            let seed = id.utf8.reduce(0) { $0 + Int($1) }
            for i in 0..<15 {
                let height = 4 + CGFloat((seed + i * 7 + i * i) % 19)
                let rect = CGRect(x: CGFloat(i) * 4.2, y: (size.height - height) / 2, width: 2.1, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(tint.opacity(i % 3 == 0 ? 0.85 : 0.4)))
            }
        }.accessibilityHidden(true)
    }
}

struct ListeningControls: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Make it yours").font(.system(size: 19, design: .serif))
                    VStack(alignment: .leading, spacing: 9) {
                        HStack { Label("Music", systemImage: "music.note"); Spacer(); Text("\(Int(model.musicLevel * 100))%").monospacedDigit().foregroundStyle(Theme.muted) }
                            .font(.system(size: 12))
                        Slider(value: Binding(get: { model.musicLevel }, set: model.setMusicLevel), in: 0...1)
                            .tint(Theme.accent(model.mode)).disabled(!model.generatorActive)
                            .accessibilityLabel("Music level").accessibilityIdentifier("music-level")
                        Button { model.sheet = .sound } label: {
                            Label("Adjust this music", systemImage: "slider.horizontal.3").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }.buttonStyle(.plain).disabled(!model.generatorActive)
                    }
                    Divider().overlay(Theme.line)
                    BackgroundControls()
                }.padding(21).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 14) {
                    Label("Transitions", systemImage: "waveform.path").font(.system(size: 12, weight: .semibold))
                    SmallTimeSlider(title: "Gentle start", seconds: Binding(get: { model.store.preferences.startFadeSeconds }, set: {
                        _ = model.handle(["command":"settings", "key":"startFadeSeconds", "value":$0])
                    }), range: 0...20)
                    SmallTimeSlider(title: "Music crossfade", seconds: Binding(get: { model.transitionSeconds }, set: model.setTransitionSeconds), range: 2...30)
                    Text("New music fades in from silence after a pause. During playback, music blends together.")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                }.padding(21).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
                if model.mode == .meditation {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Meditation chimes", systemImage: "bell").font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Button { model.sheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                                .buttonStyle(.plain).help("Edit meditation chimes").accessibilityLabel("Edit meditation chimes")
                        }.foregroundStyle(Theme.accent(.meditation))
                        Text(model.store.preferences.chimesEnabled && !model.store.preferences.markers.isEmpty ? model.store.preferences.markers.map { clockText($0) }.joined(separator: " · ") : "No chimes")
                            .font(.system(size: 11, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                        Text("After the last chime, just your music. The timer keeps going.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                    }.padding(19).background(Theme.accent(.meditation).opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
                }
            }.padding(.bottom, 20)
        }.scrollIndicators(.hidden)
    }
}
struct BackgroundControls: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background sound").font(.system(size: 12, weight: .semibold))
            Picker("Background sound", selection: Binding(get: { model.currentBackground.kind }, set: { model.changeBackground($0) })) {
                ForEach(BackgroundKind.allCases) { kind in Text(kind.title).tag(kind) }
            }.labelsHidden().pickerStyle(.menu).accessibilityLabel("Background sound").accessibilityIdentifier("background-kind")
            HStack { Text("Amount"); Spacer(); Text(model.currentBackground.kind == .off ? "Off" : "\(Int(model.currentBackground.volume * 100))%") }
                .font(.system(size: 10)).foregroundStyle(Theme.muted).monospacedDigit()
            Slider(value: Binding(get: { model.currentBackground.volume }, set: { model.changeBackground(model.currentBackground.kind, volume: $0) }), in: 0...1)
                .tint(Theme.accent(model.mode)).disabled(model.currentBackground.kind == .off)
                .accessibilityLabel("Background amount").accessibilityIdentifier("background-level")
            Text("Optional. Remembered for this mode.").font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }
}
struct SmallTimeSlider: View {
    let title: String
    @Binding var seconds: Double
    let range: ClosedRange<Double>
    var unit: String = "s"
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title); Spacer(); Text(seconds == 0 ? "Off" : "\(Int(seconds)) \(unit)").monospacedDigit().foregroundStyle(Theme.muted) }.font(.system(size: 11))
            Slider(value: $seconds, in: range, step: 1).tint(Theme.accent).accessibilityLabel("\(title) duration in \(unit == "s" ? "seconds" : "minutes")")
        }
    }
}

struct ListeningPlayerBar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 17) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.currentMusicTitle).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                PlaybackStateLabel()
            }.frame(minWidth: 125, maxWidth: .infinity, alignment: .leading)
            Text(clockText(model.elapsed)).font(.system(size: 23, weight: .light, design: .rounded)).monospacedDigit()
                .frame(minWidth: 74).accessibilityLabel("Session time \(clockText(model.elapsed))")
            Button { model.togglePlayback() } label: {
                Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 16))
                    .frame(width: 49, height: 49).foregroundStyle(Theme.sidebar).background(Theme.accent(model.mode), in: Circle())
            }.buttonStyle(.plain).accessibilityLabel(model.playing ? "Pause" : model.elapsed > 0 ? "Resume" : "Play")
                .help(model.playing ? "Pause · ⌘P" : "Play · ⌘P").accessibilityIdentifier("transport-play")
            Button { model.stop() } label: {
                Image(systemName: "stop.fill").font(.system(size: 11)).frame(width: 28, height: 40).foregroundStyle(Theme.muted)
            }.buttonStyle(.plain).help("End session").accessibilityLabel("End session")
            Spacer(minLength: 20)
            Image(systemName: model.store.preferences.masterVolume == 0 ? "speaker.slash" : "speaker.wave.2").font(.system(size: 13)).foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1)
                .frame(width: 111).tint(Theme.accent(model.mode)).accessibilityLabel("Master volume")
            Text("\(Int(model.store.preferences.masterVolume * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted).frame(width: 34)
            Button { model.quietView = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 14)).frame(width: 29, height: 40).foregroundStyle(Theme.muted)
            }.buttonStyle(.plain).help("Quiet view · ⇧⌘F").accessibilityLabel("Quiet view")
        }.padding(.horizontal, 31).padding(.vertical, 16).background(Theme.sidebar)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
struct PlaybackStateLabel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Text(status).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }
    private var status: String {
        guard model.playing else { return model.mode.title + (model.elapsed > 0 ? " · Paused" : " · Ready") }
        guard model.generatorActive else { return model.mode.title + " · Playing" }
        let state = model.generatorSnapshot
        if state["loading"] as? Bool == true { return "Preparing your music…" }
        let transition = state["transition"] as? [String: Any] ?? [:]
        if transition["state"] as? String == "crossfading" { return "Blending into " + model.currentMusicTitle }
        let entrance = state["entrance"] as? [String: Any] ?? [:]
        if ((entrance["progress"] as? NSNumber)?.doubleValue ?? 1) < 1 { return "Easing in…" }
        return model.mode.title + " · Playing"
    }
}
struct CompactUpdateBanner: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var updates: UpdateManager
    var body: some View {
        if updates.available {
            HStack {
                Label("An update is available", systemImage: "arrow.down.circle").font(.system(size: 11))
                Spacer()
                Button("View update") { model.sheet = .updates }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain)
            }.foregroundStyle(Theme.accent).padding(.horizontal, 32).padding(.vertical, 10).background(Theme.panel)
        }
    }
}
