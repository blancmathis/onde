import SwiftUI
import OndeCore

struct EspaceSheetView: View {
    @EnvironmentObject var model: AppModel
    let sheet: ListeningSheet
    @State private var settingsTab: EspaceSettingsTab
    @State private var chimeDraft = EspaceChimeDraft(markers: [])
    @State private var initialized = false
    @State private var confirmDiscard = false
    @State private var pendingSheet: ListeningSheet?
    init(sheet: ListeningSheet, initialSettingsTab: EspaceSettingsTab = .general) {
        self.sheet = sheet
        _settingsTab = State(initialValue: initialSettingsTab)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(sheet == .sound ? "Adjust sound" : sheet.title).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                Spacer()
                Button("Done") { requestExit() }.keyboardShortcut(.cancelAction).buttonStyle(EspaceButtonStyle())
            }.padding(24)
            if sheet == .settings && chimeDraft.isDirty {
                HStack(spacing: 12) {
                    Label("Unapplied chime times", systemImage: "pencil.circle")
                    Spacer()
                    Button("Review") { settingsTab = .meditation }.buttonStyle(.plain)
                    Button("Discard edit") { chimeDraft.reload() }.buttonStyle(.plain)
                }.font(.system(size: 12)).foregroundStyle(EspaceTheme.accent(.meditation))
                    .padding(.horizontal, 26).padding(.bottom, 16)
                    .accessibilityIdentifier("chime-draft-banner")
            }
            Divider().overlay(EspaceTheme.line)
            if sheet == .settings {
                Picker("Settings section", selection: $settingsTab) {
                    ForEach(EspaceSettingsTab.allCases) { item in Text(item.rawValue).tag(item) }
                }.pickerStyle(.segmented).labelsHidden().controlSize(.large)
                    .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 4)
                    .accessibilityIdentifier("settings-section")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch sheet {
                    case .settings: EspacePreferencesView(tab: $settingsTab, chimeDraft: $chimeDraft, navigate: { requestExit(to: $0) })
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
            .interactiveDismissDisabled(sheet == .settings && chimeDraft.isDirty)
            .onAppear {
                if !initialized { chimeDraft = EspaceChimeDraft(markers: model.store.preferences.markers); initialized = true }
            }
            .onChange(of: model.store.preferences.markers) { _, markers in chimeDraft.receive(markers) }
            .confirmationDialog("Discard unapplied chime times?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard and continue", role: .destructive) { chimeDraft.reload(); model.sheet = pendingSheet }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("Your saved chime times have not changed.") }
    }
    private func requestExit(to next: ListeningSheet? = nil) {
        if sheet == .settings && chimeDraft.isDirty { pendingSheet = next; confirmDiscard = true }
        else { model.sheet = next }
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
            Slider(value: $value, in: range).accessibilityLabel(title + (seconds ? " in seconds" : " level")).accessibilityValue(formatted)
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
            HStack {
                Text("Background sound").font(.system(size: 13))
                Spacer()
                Menu {
                    ForEach(BackgroundKind.allCases) { kind in
                        Button { model.changeBackground(kind) } label: {
                            if kind == model.currentBackground.kind { Label(kind.title, systemImage: "checkmark") }
                            else { Text(kind.title) }
                        }
                    }
                } label: {
                    HStack {
                        Text(model.currentBackground.kind.title).font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }.padding(.horizontal, 12).frame(width: 205, height: 34)
                        .background(EspaceTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Background sound, currently \(model.currentBackground.kind.title)")
                    .accessibilityIdentifier("background-kind")
            }
            if model.currentBackground.kind != .off {
                EspaceSettingSlider(title: "Background amount", value: Binding(get: { model.currentBackground.volume }, set: { model.changeBackground(model.currentBackground.kind, volume: $0) }))
                    .accessibilityIdentifier("background-level")
            }
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
            DisclosureGroup("Instruments, composition & export", isExpanded: $advanced) { SoundControlsView().padding(.top, 18) }
                .font(.system(size: 13, weight: .medium))
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

enum EspaceSettingsTab: String, CaseIterable, Identifiable {
    case general = "General", defaults = "Defaults", meditation = "Meditation", advanced = "Advanced"
    var id: String { rawValue }
}

private struct EspacePreferencesView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.espaceReduceMotion) private var reduced
    @AppStorage("onde.espace.visualMotion") private var visualMotion = true
    @AppStorage("onde.espace.showArtwork") private var showArtwork = true
    @Binding var tab: EspaceSettingsTab
    @Binding var chimeDraft: EspaceChimeDraft
    let navigate: (ListeningSheet) -> Void
    var body: some View {
        switch tab {
        case .general:
            EspaceSection(title: "Your listening space", detail: "Opening Onde never starts playback. Browsing a mode does not change the current session.") {
                EspaceSettingToggle("Show artwork", isOn: $showArtwork).toggleStyle(.switch).font(.system(size: 13))
                EspaceSettingToggle("Animate artwork", isOn: $visualMotion).toggleStyle(.switch).font(.system(size: 13)).disabled(reduced || !showArtwork)
                Text(reduced ? "Reduce motion is enabled in the system or in Onde. The listening surface stays still." : "Only the listening surface moves. Choose its animation below the artwork. Hidden windows pause; visible background windows use reduced detail.")
                    .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(4)
                Divider().overlay(EspaceTheme.line)
                EspaceSettingToggle("Reduce motion in Onde", isOn: Binding(get: { model.store.preferences.reducedMotion }, set: { value in
                    _ = model.handle(["command": "settings", "key": "reducedMotion", "value": value])
                })).toggleStyle(.switch).font(.system(size: 13))
            }
            EspaceSection(title: "Playback") {
                EspaceSettingToggle("Keep playing with the display off", isOn: Binding(get: { model.store.preferences.preventSleep }, set: { value in
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
        case .meditation: EspaceChimeSettings(draft: $chimeDraft)
        case .advanced:
            EspaceSection(title: "Recorded audio", detail: "Smoothing for imported audio and background layers. Generated music uses its own crossfade.") {
                EspaceSettingSlider(title: "Recorded-layer smoothing", value: Binding(get: { model.store.preferences.fadeSeconds }, set: { value in
                    _ = model.handle(["command": "settings", "key": "fadeSeconds", "value": value])
                }), range: 0...10, seconds: true)
            }
            EspaceSection(title: "Existing tools", detail: "Your saved mixes, imported audio and history are kept intact.") {
                HStack(spacing: 10) {
                    Button("Personal audio & mixes") { navigate(.personal) }.buttonStyle(EspaceButtonStyle())
                    Button("Agent & CLI") { navigate(.cli) }.buttonStyle(EspaceButtonStyle())
                }
            }
        }
    }
}

private struct EspaceChimeSettings: View {
    @EnvironmentObject var model: AppModel
    @Binding var draft: EspaceChimeDraft
    @State private var error = ""
    var body: some View {
        EspaceSection(title: "Meditation chimes", detail: "A soft glass chime marks each time you choose. After the last chime, the timer and music continue.") {
            EspaceSettingToggle("Enable chimes", isOn: Binding(get: { model.store.preferences.chimesEnabled }, set: { value in
                _ = model.handle(["command": "settings", "key": "chimesEnabled", "value": value])
            })).toggleStyle(.switch).font(.system(size: 13))
            Text("Times in minutes from the start of the session").font(.system(size: 13))
            TextField("10, 20, 30", text: $draft.text).textFieldStyle(.roundedBorder).font(.system(size: 14, design: .monospaced))
                .onSubmit(apply).accessibilityLabel("Chime times in minutes, separated by commas")
            Text("Separate times with commas. Leave empty for no chimes. Past times are not replayed.")
                .font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).lineSpacing(4)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xEAB2A4)).accessibilityLabel(error) }
            if draft.hasConflict {
                Text("Chime times changed elsewhere. Reload before applying an edit.").font(.system(size: 12)).foregroundStyle(Color(hex: 0xEAB2A4))
                Button("Reload current times") { draft.reload(); error = "" }.buttonStyle(EspaceButtonStyle())
            }
            HStack(spacing: 10) {
                Button("Apply times", action: apply).buttonStyle(EspaceButtonStyle(primary: true, tint: EspaceTheme.accent(.meditation))).disabled(draft.hasConflict || !draft.isDirty)
                Button("Use 10, 20, 30") { draft.text = "10, 20, 30"; error = "" }.buttonStyle(EspaceButtonStyle())
            }
            Divider().overlay(EspaceTheme.line)
            EspaceSettingSlider(title: "Chime level", value: Binding(get: { model.store.preferences.chimeVolume }, set: model.setChime))
            HStack {
                Text(previewHint).font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { model.previewChime() } label: { Label("Listen", systemImage: "bell") }.buttonStyle(EspaceButtonStyle()).accessibilityHint(previewHint)
            }
        }
        .onChange(of: draft.text) { _, _ in error = "" }
    }
    private var previewHint: String {
        if model.store.preferences.masterVolume == 0 { return "Master volume is muted. Raise it to hear the preview." }
        if model.store.preferences.chimeVolume == 0 { return "Chime level is zero. Raise it to hear the preview." }
        return "Also affected by master volume."
    }
    private func apply() {
        do {
            draft.receive(model.store.preferences.markers)
            let seconds = try draft.parsedSeconds()
            try model.setMarkers(seconds)
            draft.didApply(model.store.preferences.markers)
            error = ""; model.notify("Chime times updated.")
        } catch { self.error = error.localizedDescription }
    }
}

/// Trailing switches share an alignment, independently of the label length.
private struct EspaceSettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    init(_ title: String, isOn: Binding<Bool>) { self.title = title; self._isOn = isOn }
    var body: some View {
        HStack(spacing: 24) {
            Text(title).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Spacer(minLength: 12)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).accessibilityLabel(title)
        }.frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }
}
