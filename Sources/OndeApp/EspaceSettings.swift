import SwiftUI
import OndeCore

struct EspaceSheetView: View {
    @EnvironmentObject var model: AppModel
    let sheet: ListeningSheet
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(sheet == .sound ? "Adjust sound" : sheet.title).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                Spacer()
                Button("Done") { model.sheet = nil }.keyboardShortcut(.cancelAction).buttonStyle(EspaceButtonStyle())
            }.padding(24)
            Divider().overlay(EspaceTheme.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch sheet {
                    case .settings: EspacePreferencesView()
                    case .sound: EspaceSoundSettings()
                    case .personal: PersonalAudioView()
                    case .history: HistoryView()
                    case .cli: CLIGuideView()
                    case .credits: CreditsView()
                    case .updates: UpdatesView(updates: model.updates)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(26)
            }
        }.frame(width: 740, height: 590).background(EspaceTheme.background)
            .foregroundStyle(EspaceTheme.ink).tint(EspaceTheme.accent(model.mode)).preferredColorScheme(.dark)
    }
}

private struct EspaceSection<Content: View>: View {
    let title: String
    var detail: String = ""
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(title).font(.system(size: 14, weight: .semibold))
            if !detail.isEmpty { Text(detail).font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(4) }
            content()
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(EspaceTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EspaceSettingSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var seconds = false
    private var formatted: String { seconds ? "\(Int(value)) s" : "\(Int(value * 100))%" }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(formatted).font(.system(size: 12)).monospacedDigit().foregroundStyle(EspaceTheme.secondary)
            }
            Slider(value: $value, in: range).accessibilityLabel(title + (seconds ? " in seconds" : " level"))
        }
    }
}

private struct EspaceSoundSettings: View {
    @EnvironmentObject var model: AppModel
    @State private var advanced = false
    @State private var resetConfirmation = false
    var body: some View {
        Text("For \(model.currentMusicTitle). Adjusting sound keeps your session running.")
            .font(.system(size: 13)).foregroundStyle(EspaceTheme.secondary)
        EspaceSection(title: "Balance") {
            EspaceSettingSlider(title: "Music", value: Binding(get: { model.musicLevel }, set: model.setMusicLevel))
                .disabled(!model.generatorActive).accessibilityIdentifier("music-level")
            Divider().overlay(EspaceTheme.line)
            Picker("Background sound", selection: Binding(get: { model.currentBackground.kind }, set: { model.changeBackground($0) })) {
                ForEach(BackgroundKind.allCases) { kind in Text(kind.title).tag(kind) }
            }.pickerStyle(.menu).font(.system(size: 13)).accessibilityIdentifier("background-kind")
            EspaceSettingSlider(title: "Background amount", value: Binding(get: { model.currentBackground.volume }, set: { model.changeBackground(model.currentBackground.kind, volume: $0) }))
                .disabled(model.currentBackground.kind == .off).accessibilityIdentifier("background-level")
            Text("One optional background, remembered for this mode. Master volume affects the whole mix.")
                .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(3)
        }
        if model.generatorActive {
            EspaceSection(title: "Tone", detail: "Your settings are remembered for this music in this mode.") {
                HStack(alignment: .top, spacing: 26) {
                    EspaceSettingSlider(title: "Bass", value: parameter("bass"))
                    EspaceSettingSlider(title: "Warmth", value: parameter("warmth"))
                }
                HStack(alignment: .top, spacing: 26) {
                    EspaceSettingSlider(title: "Space", value: parameter("space"))
                    EspaceSettingSlider(title: "Note density", value: parameter("density"))
                }
            }
        }
        EspaceSection(title: "Transitions", detail: "Music fades in from silence after a pause. During playback, a new selection crossfades.") {
            EspaceSettingSlider(title: "Gentle start", value: Binding(get: { model.store.preferences.startFadeSeconds }, set: { value in
                _ = model.handle(["command": "settings", "key": "startFadeSeconds", "value": value])
            }), range: 0...20, seconds: true)
            EspaceSettingSlider(title: "Music crossfade", value: Binding(get: { model.transitionSeconds }, set: model.setTransitionSeconds), range: 2...30, seconds: true)
        }
        if model.generatorActive {
            DisclosureGroup("Instruments, composition & export", isExpanded: $advanced) {
                SoundControlsView().padding(.top, 18)
            }.font(.system(size: 13, weight: .medium))
            Button("Restore this sound's settings…") { resetConfirmation = true }.buttonStyle(EspaceButtonStyle())
                .confirmationDialog("Restore this sound's original settings? Your defaults, backgrounds, volume and chimes are unchanged.", isPresented: $resetConfirmation) {
                    Button("Restore sound settings", role: .destructive) { model.resetCurrentMusicTuning() }
                }
        }
    }
    private func parameter(_ key: String) -> Binding<Double> {
        Binding(get: { model.generatorConfiguration.value(key) }, set: { value in
            _ = model.handle(["command": "generate.set", "key": key, "value": value])
        })
    }
}

private enum EspaceSettingsTab: String, CaseIterable, Identifiable {
    case general = "General", defaults = "Defaults", meditation = "Meditation", advanced = "Advanced"
    var id: String { rawValue }
}

private struct EspacePreferencesView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.espaceReduceMotion) private var reduced
    @AppStorage("onde.espace.visualMotion") private var visualMotion = true
    @State private var tab: EspaceSettingsTab = .general
    var body: some View {
        Picker("Settings section", selection: $tab) {
            ForEach(EspaceSettingsTab.allCases) { item in Text(item.rawValue).tag(item) }
        }.pickerStyle(.segmented).labelsHidden().controlSize(.large)
        switch tab {
        case .general:
            EspaceSection(title: "Your listening space", detail: "Opening Onde never starts playback. Browsing a mode does not change the current session.") {
                Toggle("Subtle visual motion", isOn: $visualMotion).toggleStyle(.switch).font(.system(size: 13)).disabled(reduced)
                Text(reduced ? "Reduce motion is enabled in the system or in Onde. The listening surface stays still." : "Only the listening surface moves. Music cards stay still; the visual pauses when Onde is not active.")
                    .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(4)
                Divider().overlay(EspaceTheme.line)
                Toggle("Reduce motion in Onde", isOn: Binding(get: { model.store.preferences.reducedMotion }, set: { value in
                    _ = model.handle(["command": "settings", "key": "reducedMotion", "value": value])
                })).toggleStyle(.switch).font(.system(size: 13))
            }
            EspaceSection(title: "Playback") {
                Toggle("Keep playing with the display off", isOn: Binding(get: { model.store.preferences.preventSleep }, set: { value in
                    _ = model.handle(["command": "settings", "key": "preventSleep", "value": value])
                })).toggleStyle(.switch).font(.system(size: 13))
                Text("Prevents automatic system sleep while a session is running. Closing the lid or putting the Mac to sleep still pauses the session.")
                    .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(4)
            }
        case .defaults:
            EspaceSection(title: "Start with what you love", detail: "The Start button and ⌘1–3 use these choices. Setting a default never starts playback.") {
                ForEach(SessionMode.allCases) { mode in
                    Picker(mode.title, selection: Binding(get: { model.defaultMusicID(for: mode) }, set: { id in
                        do { try model.setDefaultMusic(id, for: mode) } catch { model.fail(error) }
                    })) {
                        ForEach(MusicCatalog.profiles(for: mode)) { profile in Text(profile.title).tag(profile.id) }
                    }.pickerStyle(.menu).font(.system(size: 13)).accessibilityLabel("\(mode.title) default")
                }
                Text("Relax and Meditation share music, but keep independent defaults and backgrounds.")
                    .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(3)
            }
        case .meditation: EspaceChimeSettings()
        case .advanced:
            EspaceSection(title: "Recorded audio", detail: "Smoothing for imported audio and background layers. Generated music uses its own crossfade.") {
                EspaceSettingSlider(title: "Recorded-layer smoothing", value: Binding(get: { model.store.preferences.fadeSeconds }, set: { value in
                    _ = model.handle(["command": "settings", "key": "fadeSeconds", "value": value])
                }), range: 0...10, seconds: true)
            }
            EspaceSection(title: "Existing tools", detail: "Your saved mixes, imported audio and history are kept intact.") {
                HStack(spacing: 10) {
                    Button("Personal audio & mixes") { model.sheet = .personal }.buttonStyle(EspaceButtonStyle())
                    Button("Agent & CLI") { model.sheet = .cli }.buttonStyle(EspaceButtonStyle())
                }
            }
        }
    }
}

private struct EspaceChimeSettings: View {
    @EnvironmentObject var model: AppModel
    @State private var draft = ""
    @State private var error = ""
    @State private var conflict = false
    private func format(_ markers: [Double]) -> String { markers.map { String(format: "%g", $0 / 60) }.joined(separator: ", ") }
    var body: some View {
        EspaceSection(title: "Meditation chimes", detail: "A soft glass chime marks each time you choose. After the last chime, the timer and music continue.") {
            Toggle("Enable chimes", isOn: Binding(get: { model.store.preferences.chimesEnabled }, set: { value in
                _ = model.handle(["command": "settings", "key": "chimesEnabled", "value": value])
            })).toggleStyle(.switch).font(.system(size: 13))
            Text("Times in minutes from the start of the session").font(.system(size: 13))
            TextField("10, 20, 30", text: $draft).textFieldStyle(.roundedBorder).font(.system(size: 14, design: .monospaced))
                .onSubmit(apply).accessibilityLabel("Chime times in minutes, separated by commas")
            Text("Separate times with commas. Leave empty for no chimes. Past times are not replayed.")
                .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(4)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xEAB2A4)).accessibilityLabel(error) }
            if conflict {
                Text("Chime times changed elsewhere. Reload before applying an edit.").font(.system(size: 12)).foregroundStyle(Color(hex: 0xEAB2A4))
                Button("Reload current times") { draft = format(model.store.preferences.markers); conflict = false; error = "" }.buttonStyle(EspaceButtonStyle())
            }
            HStack(spacing: 10) {
                Button("Apply times", action: apply).buttonStyle(EspaceButtonStyle(primary: true, tint: EspaceTheme.accent(.meditation))).disabled(conflict || draft == format(model.store.preferences.markers))
                Button("Use 10, 20, 30") { draft = "10, 20, 30" }.buttonStyle(EspaceButtonStyle())
            }
            Divider().overlay(EspaceTheme.line)
            EspaceSettingSlider(title: "Chime level", value: Binding(get: { model.store.preferences.chimeVolume }, set: model.setChime))
            HStack {
                Text("Also affected by master volume.").font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary)
                Spacer()
                Button { model.previewChime() } label: { Label("Listen", systemImage: "bell") }.buttonStyle(EspaceButtonStyle())
            }
        }
        .onAppear { draft = format(model.store.preferences.markers) }
        .onChange(of: model.store.preferences.markers) { old, new in
            if draft == format(new) { conflict = false }
            else if draft == format(old) { draft = format(new); conflict = false }
            else { conflict = true }
        }
    }
    private func apply() {
        guard !conflict else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.isEmpty ? [] : text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let values = parts.compactMap(Double.init)
        guard values.count == parts.count, values.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1440 }), values.count <= 32 else {
            error = "Use up to 32 positive times, no greater than 1440 minutes."; return
        }
        do {
            try model.setMarkers(values.map { $0 * 60 }); draft = format(model.store.preferences.markers)
            error = ""; model.notify("Chime times updated.")
        } catch { self.error = error.localizedDescription }
    }
}
