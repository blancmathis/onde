import SwiftUI
import AppKit
import OndeCore

/// Browsing never starts playback. Explicit actions use the existing AppModel.
struct EspaceRootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @State private var browse: SessionMode = .focus
    @State private var query = ""
    @State private var initialized = false
    @FocusState private var searchFocused: Bool
    @AppStorage("onde.espace.visualMotion") private var visualMotion = true
    @AppStorage("onde.espace.showArtwork") private var showArtwork = true
    init(browse initialBrowse: SessionMode? = nil, query initialQuery: String = "") {
        _browse = State(initialValue: initialBrowse ?? .focus)
        _query = State(initialValue: initialQuery)
        _initialized = State(initialValue: initialBrowse != nil)
    }
    private var reduced: Bool { systemReduced || model.store.preferences.reducedMotion }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header(compact: geometry.size.width < 1040)
                HStack(alignment: .top, spacing: 28) {
                    Group {
                        if model.quietView { EspaceQuietPane() }
                        else { EspaceListeningPane(visualMotion: $visualMotion, showArtwork: showArtwork, compact: geometry.size.height < 730) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !model.quietView { collection.frame(width: geometry.size.width < 1040 ? 292 : 338) }
                }.padding(.horizontal, 30).padding(.top, 8).padding(.bottom, 24)
                if model.updates.available { updateBanner }
                footer
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .background(EspaceTheme.background).foregroundStyle(EspaceTheme.ink)
        .tint(EspaceTheme.accent(model.mode)).preferredColorScheme(.dark)
        .environment(\.espaceReduceMotion, reduced)
        .sheet(item: $model.sheet, onDismiss: { model.page = "studio" }) { sheet in
            EspaceSheetView(sheet: sheet).environmentObject(model)
                .environment(\.locale, Locale(identifier: "en")).environment(\.espaceReduceMotion, reduced)
        }
        .overlay(alignment: .top) {
            if let text = model.toast {
                Text(text).font(.system(size: 13, weight: .medium)).multilineTextAlignment(.center)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(EspaceTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(EspaceTheme.line))
                    .padding(.top, 76).padding(.horizontal, 24).allowsHitTesting(false)
                    .accessibilityIdentifier("feedback-toast")
            }
        }
        .alert("Onde", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Close", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .onAppear { if !initialized { browse = model.mode; initialized = true } }
        .onChange(of: model.mode) { _, mode in browse = mode; query = "" }
        .onChange(of: model.toast) { _, text in
            if let text { NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue]) }
        }
        .onExitCommand { if model.quietView { model.quietView = false } else { query = "" } }
        .background {
            Button("Find music") { model.quietView = false; searchFocused = true }
                .keyboardShortcut("f", modifiers: .command).frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
    }
    private func header(compact: Bool) -> some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path").font(.system(size: 25, weight: .light)).foregroundStyle(EspaceTheme.accent(model.mode))
                Text("onde").font(.system(size: 33, design: .serif)).tracking(-1.5).lineLimit(1).fixedSize()
            }.fixedSize().frame(width: compact ? 124 : 150, alignment: .leading)
                .accessibilityElement(children: .ignore).accessibilityLabel("Onde")
            Spacer(minLength: 0)
            if !model.quietView {
                Picker("Browse music", selection: $browse) {
                    ForEach(SessionMode.allCases) { mode in Text(mode.title).tag(mode) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: compact ? 300 : 324)
                    .controlSize(.large).accessibilityLabel("Browse music without changing playback")
                    .accessibilityIdentifier("browse-mode").onChange(of: browse) { _, _ in query = "" }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if !compact && !model.quietView {
                    Button { model.sheet = .history } label: {
                        Text("\(Int(model.todaySeconds / 60)) min today").font(.system(size: 12)).monospacedDigit()
                    }.buttonStyle(.plain).foregroundStyle(EspaceTheme.secondary)
                        .help("Active listening time. Pauses do not count; this is not a measure of attention.")
                }
                EspaceIconButton(symbol: "gearshape", title: "Settings · ⌘,") { model.sheet = .settings }
                Menu {
                    Toggle("Show artwork", isOn: $showArtwork)
                    Toggle("Animate artwork", isOn: $visualMotion).disabled(reduced || !showArtwork)
                    Divider()
                    Button("Personal audio & mixes…") { model.sheet = .personal }
                    Button("Session history…") { model.sheet = .history }
                    Divider()
                    Button("Agent & CLI…") { model.sheet = .cli }
                    Button("Check for Updates…") { model.sheet = .updates; model.updates.check() }
                    Button("About & credits…") { model.sheet = .credits }
                } label: { Image(systemName: "ellipsis").frame(width: 30, height: 38) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .foregroundStyle(EspaceTheme.secondary).accessibilityLabel("More options")
            }
        }.padding(.horizontal, 30).frame(height: 84)
    }
    private var profiles: [SoundProfile] {
        // Keep row positions stable while the user changes a default.
        MusicCatalog.profiles(for: browse).enumerated()
            .filter { ListeningDesign.matches(query: query, title: $0.element.title, id: $0.element.id, description: $0.element.description + " " + ListeningDesign.detail($0.element.id)) }
            .sorted {
                let a = ListeningDesign.rank(id: $0.element.id, defaultID: "")
                let b = ListeningDesign.rank(id: $1.element.id, defaultID: "")
                return a == b ? $0.offset < $1.offset : a < b
            }.map(\.element)
    }
    private var collection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("For \(browse.title.lowercased())").font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                Spacer()
                Text("\(profiles.count) sounds").font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary)
            }.padding(.top, 12)
            Button { model.startDefaultMode(browse) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill").font(.system(size: 10)).frame(width: 28, height: 28)
                        .background(EspaceTheme.accent(browse).opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start \(browse.title)").font(.system(size: 13, weight: .semibold))
                        Text("Your default · \(model.defaultMusicTitle(for: browse))").font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(EspaceTheme.accent(browse).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).foregroundStyle(EspaceTheme.accent(browse))
                .accessibilityLabel("Start \(browse.title) with \(model.defaultMusicTitle(for: browse))")
                .accessibilityIdentifier("mode-\(browse.rawValue)")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary)
                TextField("Find a sound or an instrument", text: $query).textFieldStyle(.plain)
                    .font(.system(size: 12)).focused($searchFocused).accessibilityLabel("Find music")
                    .accessibilityIdentifier("music-search")
                if !query.isEmpty {
                    Button { query = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(EspaceTheme.secondary) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(.horizontal, 11).frame(height: 40)
                .background(EspaceTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(searchFocused ? EspaceTheme.accent(browse) : EspaceTheme.line, lineWidth: searchFocused ? 2 : 1))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(browse == model.mode ? "Click to play. The star sets your default." : "Browsing \(browse.title). \(model.mode.title) \(model.playing ? "continues." : "is unchanged.")")
                    .font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary).fixedSize(horizontal: false, vertical: true)
                if browse != model.mode {
                    Spacer(minLength: 0)
                    Button("Show current") { browse = model.mode; query = "" }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(EspaceTheme.accent(model.mode))
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if profiles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass").font(.system(size: 25, weight: .light))
                                Text("No matching sounds").font(.system(size: 15, weight: .medium))
                                Text("Try an instrument, a texture or a title.").font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary)
                                Button("Clear search") { query = ""; searchFocused = true }.buttonStyle(EspaceButtonStyle())
                            }.padding(.vertical, 35).frame(maxWidth: .infinity)
                        }
                        ForEach(profiles) { profile in EspaceMusicRow(profile: profile, browse: browse).id(profile.id) }
                    }.padding(.horizontal, 3).padding(.bottom, 12)
                }.scrollIndicators(.automatic)
                .onChange(of: model.selectedMusicID) { _, id in
                    if query.isEmpty, browse == model.mode, let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }.padding(.leading, 23)
            .overlay(alignment: .leading) { Rectangle().fill(EspaceTheme.line.opacity(0.55)).frame(width: 1) }
    }
    private var footer: some View {
        HStack(spacing: 20) {
            Label("On your Mac. Just for you.", systemImage: "lock").font(.system(size: 11))
            Spacer(minLength: 0)
            Button { model.sheet = .sound } label: {
                Label("Background · \(model.currentBackground.kind.title)", systemImage: "waveform.path").font(.system(size: 12)).lineLimit(1)
            }.buttonStyle(.plain).accessibilityLabel("Adjust background sound, currently \(model.currentBackground.kind.title)")
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Image(systemName: model.store.preferences.masterVolume == 0 ? "speaker.slash" : "speaker.wave.2").font(.system(size: 13))
                Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1)
                    .frame(width: 116).accessibilityLabel("Master volume").accessibilityIdentifier("master-volume")
                Text("\(Int(model.store.preferences.masterVolume * 100))%")
                    .font(.system(size: 11)).monospacedDigit().frame(width: 34, alignment: .trailing)
            }
        }.foregroundStyle(EspaceTheme.secondary).padding(.horizontal, 32).frame(height: 62)
            .overlay(alignment: .top) { Rectangle().fill(EspaceTheme.line.opacity(0.55)).frame(height: 1) }
    }
    private var updateBanner: some View {
        HStack {
            Label("An update is available", systemImage: "arrow.down.circle")
            Spacer()
            Button("View update") { model.sheet = .updates }.buttonStyle(.plain)
        }.font(.system(size: 12)).foregroundStyle(EspaceTheme.accent(model.mode))
            .padding(.horizontal, 32).padding(.vertical, 10).background(EspaceTheme.surface)
    }
}

private struct EspaceListeningPane: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.espaceReduceMotion) private var reduced
    @Binding var visualMotion: Bool
    let showArtwork: Bool
    let compact: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(model.mode.title, systemImage: model.mode.symbol)
                Spacer()
                Text(model.generatorActive ? "Continuous sound, on your Mac" : "Your listening space")
            }.font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary).padding(.top, 14)
            if showArtwork {
                EspaceArtwork(id: model.selectedMusicID ?? "personal", mode: model.mode,
                              enabled: visualMotion && !reduced && model.sheet == nil)
                    .frame(minHeight: compact ? 105 : 145, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        Button { visualMotion.toggle() } label: {
                            Text(reduced ? "Motion reduced" : visualMotion ? "Pause visual" : "Resume visual")
                                .font(.system(size: 11)).padding(.horizontal, 8).frame(height: 30)
                        }.buttonStyle(.plain).foregroundStyle(EspaceTheme.secondary).disabled(reduced)
                            .help("Pauses the visual only. Your music and timer are unchanged.")
                            .accessibilityLabel(reduced ? "Motion reduced" : visualMotion ? "Pause decorative motion" : "Resume decorative motion")
                            .accessibilityIdentifier("visual-motion")
                    }
            } else { Spacer(minLength: 32) }
            EspacePlaybackStatus().padding(.top, 8)
            Text(model.currentMusicTitle).font(.system(size: compact ? 39 : 49, weight: .regular, design: .serif))
                .tracking(-1.3).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                .padding(.top, compact ? 9 : 13).padding(.horizontal, 12)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("current-music-title")
            Text(model.selectedMusicID.map(ListeningDesign.detail) ?? "Choose a sound or keep this session silent.")
                .font(.system(size: 13)).foregroundStyle(EspaceTheme.secondary).multilineTextAlignment(.center)
                .lineLimit(2).padding(.top, 10).padding(.horizontal, 12)
            HStack(spacing: 23) {
                Button { model.togglePlayback() } label: {
                    Label(model.playing ? "Pause" : model.elapsed > 0 ? "Resume" : "Play", systemImage: model.playing ? "pause.fill" : "play.fill")
                }.buttonStyle(EspaceButtonStyle(primary: true, tint: EspaceTheme.accent(model.mode)))
                    .accessibilityLabel(model.playing ? "Pause" : model.elapsed > 0 ? "Resume" : "Play")
                    .accessibilityIdentifier("transport-play").help("Play or pause · ⌘P")
                VStack(alignment: .leading, spacing: 5) {
                    Text(clockText(model.elapsed)).font(.system(size: 23, weight: .light)).monospacedDigit()
                    Text("Elapsed · no time limit").font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary)
                }.accessibilityElement(children: .ignore).accessibilityLabel("Elapsed \(clockText(model.elapsed)); no time limit")
                EspaceIconButton(symbol: "stop", title: "End session · ⌘.") { model.stop() }
            }.padding(.top, compact ? 22 : 28).padding(.bottom, compact ? 19 : 24)
            if model.mode == .meditation {
                Text(chimeCaption).font(.system(size: 12)).foregroundStyle(EspaceTheme.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.bottom, 16)
            }
            HStack(spacing: 10) {
                Button { model.sheet = .sound } label: { Label("Adjust sound", systemImage: "slider.horizontal.3") }
                    .buttonStyle(EspaceButtonStyle()).accessibilityIdentifier("adjust-sound")
                Button { model.quietView = true } label: {
                    Label("Quiet view", systemImage: "arrow.up.left.and.arrow.down.right")
                }.buttonStyle(EspaceButtonStyle()).help("Quiet view · ⇧⌘F").accessibilityIdentifier("quiet-view")
            }.padding(.bottom, 10)
            if !showArtwork { Spacer(minLength: 32) }
        }.padding(.horizontal, 6)
    }
    private var chimeCaption: String {
        guard model.store.preferences.chimesEnabled, !model.store.preferences.markers.isEmpty else { return "No chimes. Stay as long as you like." }
        if let next = model.nextMarker { return "Next chime at \(clockText(next)). Stay as long as you like." }
        return "No more chimes. The timer keeps going."
    }
}

private struct EspacePlaybackStatus: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !model.playing || scenePhase != .active)) { _ in
            HStack(spacing: 7) {
                Circle().fill(EspaceTheme.accent(model.mode)).frame(width: 5, height: 5)
                Text(status.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.6)
            }.foregroundStyle(EspaceTheme.accent(model.mode)).accessibilityElement(children: .combine)
        }
    }
    private var status: String {
        guard model.playing else { return model.elapsed > 0 ? "Paused" : "Ready to play" }
        guard model.generatorActive else { return "Session active" }
        let snapshot = model.generatorSnapshot
        if snapshot["loading"] as? Bool == true { return "Preparing audio…" }
        let transition = snapshot["transition"] as? [String: Any] ?? [:]
        if transition["state"] as? String == "crossfading" { return "Blending into your sound…" }
        let entrance = snapshot["entrance"] as? [String: Any] ?? [:]
        if ((entrance["progress"] as? NSNumber)?.doubleValue ?? 1) < 1 { return "Easing in…" }
        return "Playing"
    }
}

private struct EspaceMusicRow: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    let profile: SoundProfile
    let browse: SessionMode
    @State private var hovered = false
    private var selected: Bool { model.mode == browse && model.selectedMusicID == profile.id }
    private var isDefault: Bool { model.defaultMusicID(for: browse) == profile.id }
    var body: some View {
        HStack(spacing: 4) {
            Button {
                do { try model.selectMusic(profile.id, in: browse) } catch { model.fail(error) }
            } label: {
                HStack(spacing: 12) {
                    EspaceThumbnail(id: profile.id, mode: browse)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(profile.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            if selected { Image(systemName: model.playing ? "waveform" : "checkmark").font(.system(size: 10)).foregroundStyle(EspaceTheme.accent(browse)) }
                        }
                        Text(ListeningDesign.detail(profile.id)).font(.system(size: 11)).foregroundStyle(EspaceTheme.secondary).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 12).contentShape(Rectangle())
            }.buttonStyle(EspaceRowButtonStyle()).accessibilityLabel("Play \(profile.title) in \(browse.title)")
                .accessibilityIdentifier("music-card-\(profile.id)")
                .help("Play \(profile.title) in \(browse.title). Your saved default does not change.")
            Button {
                do { try model.setDefaultMusic(profile.id, for: browse) } catch { model.fail(error) }
            } label: {
                Image(systemName: isDefault ? "star.fill" : "star").font(.system(size: 11))
                    .frame(width: 30, height: 38).foregroundStyle(isDefault ? EspaceTheme.accent(browse) : EspaceTheme.secondary)
            }.buttonStyle(.borderless).disabled(isDefault)
                .accessibilityLabel(isDefault ? "\(profile.title) is the \(browse.title) default" : "Set \(profile.title) as \(browse.title) default")
                .accessibilityIdentifier("default-\(profile.id)")
                .help(isDefault ? "Your starting sound for \(browse.title)" : "Use \(profile.title) when you start \(browse.title). Does not play audio.")
        }.padding(.leading, 8).padding(.trailing, 3)
            .background(selected ? EspaceTheme.accent(browse).opacity(0.10) : hovered ? EspaceTheme.surface : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? EspaceTheme.accent(browse).opacity(contrast == .increased ? 1 : 0.20) : .clear, lineWidth: contrast == .increased ? 2 : 1))
            .onHover { hovered = $0 }
    }
}

/// A true quiet space: no catalogue or artwork allocation.
private struct EspaceQuietPane: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(model.mode.title, systemImage: model.mode.symbol)
                    .font(.system(size: 12)).foregroundStyle(EspaceTheme.accent(model.mode))
                Spacer()
                Button { model.quietView = false } label: {
                    Label("Back to music", systemImage: "arrow.down.right.and.arrow.up.left")
                }.buttonStyle(EspaceButtonStyle()).help("Leave quiet view · Escape").accessibilityIdentifier("quiet-view")
            }.padding(.top, 14)
            Spacer(minLength: 30)
            Text(model.currentMusicTitle).font(.system(size: 26, design: .serif))
                .foregroundStyle(EspaceTheme.secondary).multilineTextAlignment(.center).lineLimit(2)
            Text(clockText(model.elapsed)).font(.system(size: 94, weight: .ultraLight, design: .rounded))
                .monospacedDigit().tracking(-3).lineLimit(1).minimumScaleFactor(0.5).padding(.top, 24)
                .accessibilityLabel("Elapsed \(clockText(model.elapsed))")
            Text(caption).font(.system(size: 13)).foregroundStyle(EspaceTheme.secondary)
                .multilineTextAlignment(.center).padding(.top, 15)
            HStack(spacing: 16) {
                Button { model.togglePlayback() } label: {
                    Label(model.playing ? "Pause" : model.elapsed > 0 ? "Resume" : "Play", systemImage: model.playing ? "pause.fill" : "play.fill")
                }.buttonStyle(EspaceButtonStyle(primary: true, tint: EspaceTheme.accent(model.mode)))
                    .accessibilityIdentifier("transport-play").help("Play or pause · ⌘P")
                EspaceIconButton(symbol: "stop", title: "End session · ⌘.") { model.stop() }
            }.padding(.top, 32)
            Spacer(minLength: 30)
            EspacePlaybackStatus().padding(.bottom, 24)
        }.frame(maxWidth: 760)
    }
    private var caption: String {
        if model.mode == .meditation, model.store.preferences.chimesEnabled {
            if let next = model.nextMarker { return "Next chime at \(clockText(next)). No time limit." }
            return "No more chimes. Stay as long as you like."
        }
        return "No countdown. Stay as long as you like."
    }
}
