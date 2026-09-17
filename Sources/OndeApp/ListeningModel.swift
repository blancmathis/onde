import Foundation
import OndeCore

/// Secondary tools are sheets, not competing top-level destinations.
enum ListeningSheet: String, Identifiable {
    case settings, sound, personal, history, cli, credits, updates
    var id: String { rawValue }
    var title: String {
        switch self {
        case .settings: return "Settings"
        case .sound: return "Adjust this music"
        case .personal: return "Personal audio & mixes"
        case .history: return "Session history"
        case .cli: return "Agent & CLI"
        case .credits: return "About Onde"
        case .updates: return "Updates"
        }
    }
    static func legacyPage(_ page: String) -> Self? {
        switch page {
        case "library", "mixes": return .personal
        case "settings": return .settings
        case "history": return .history
        case "cli": return .cli
        case "credits": return .credits
        case "updates": return .updates
        default: return nil
        }
    }
}

extension AppModel {
    var listeningPreferences: ListeningPreferences { store.listening ?? .migrating(store) }
    var musicProfiles: [SoundProfile] { MusicCatalog.profiles(for: mode) }
    var musicRenderMode: SessionMode {
        // Preserve the authored piece: choosing Meditation must not relabel a
        // Relax choice or silently apply the old meditation synthesizer palette.
        generatorConfiguration.profileID.flatMap { SoundProfile.find($0)?.mode } ?? mode
    }
    var selectedMusicID: String? { generatorActive ? generatorConfiguration.profileID : nil }
    var currentMusicTitle: String {
        if generatorActive { return generatorConfiguration.displayName }
        let names = activeSounds.filter { !BackgroundKind.soundIDs.contains($0.id) }.map(\.title)
        return names.isEmpty ? "Music off" : names.joined(separator: " + ")
    }
    var musicLevel: Double { store.layers["living"]?.volume ?? listeningPreferences.musicLevels[mode.rawValue] ?? 0.65 }
    func defaultMusicID(for mode: SessionMode) -> String { listeningPreferences.defaultID(for: mode) }
    func defaultMusicTitle(for mode: SessionMode) -> String { SoundProfile.find(defaultMusicID(for: mode))?.title ?? "Music" }
    var currentBackground: BackgroundMix {
        let actual = BackgroundMix.infer(from: store.layers)
        if actual.kind != .off { return actual }
        // Retain the selected color at zero, but never claim a muted layer plays.
        if let stored = listeningPreferences.backgrounds[mode.rawValue], stored.kind != .off, stored.volume == 0 { return stored }
        return .init(kind: .off, volume: listeningPreferences.backgrounds[mode.rawValue]?.volume ?? 0.15)
    }
    var listeningSnapshot: [String: Any] {
        let prefs = listeningPreferences
        return ["catalog": mode == .focus ? "focus" : "relax",
                "selected_music_id": selectedMusicID as Any? ?? NSNull(), "music_title": currentMusicTitle,
                "music_volume": musicLevel,
                "defaults": Dictionary(uniqueKeysWithValues: SessionMode.allCases.map { ($0.rawValue, prefs.defaultID(for: $0)) }),
                "background": jsonObject(currentBackground),
                "meditation_uses_relax_music": true,
                "sheet": sheet?.rawValue as Any? ?? NSNull()]
    }
    func setDefaultMusic(_ id: String, for selected: SessionMode) throws {
        var prefs = listeningPreferences
        try prefs.setDefault(id, for: selected)
        store.listening = prefs; persist()
        notify("\(SoundProfile.find(id)!.title) is your \(selected.title) default.")
    }
    /// A mode shortcut always chooses its explicit default, not the last preview.
    func startDefaultMode(_ selected: SessionMode, autostart: Bool = true, reset: Bool = false) {
        do { try selectMusic(defaultMusicID(for: selected), in: selected, autostart: autostart, reset: reset) }
        catch { fail(error) }
    }
    func rememberCurrentMusic() {
        var prefs = listeningPreferences
        if let id = generatorConfiguration.profileID, SoundProfile.find(id) != nil {
            prefs.customizations[MusicCatalog.settingKey(id, mode: mode)] = generatorConfiguration
        }
        prefs.musicLevels[mode.rawValue] = musicLevel
        prefs.backgrounds[mode.rawValue] = currentBackground
        store.listening = prefs
    }
    func selectMusic(_ id: String, in selected: SessionMode, autostart: Bool = true, reset: Bool = false) throws {
        guard let profile = SoundProfile.find(id) else { throw OndeError("not_found", "Unknown music. Use onde music list.") }
        guard MusicCatalog.allows(id, in: selected) else { throw OndeError("wrong_catalog", "Choose music from the current mode's catalog.") }
        rememberCurrentMusic()
        let prefs = listeningPreferences
        let key = MusicCatalog.settingKey(id, mode: selected)
        let config = try (prefs.customizations[key] ?? profile.configuration).validated()
        let background = prefs.backgrounds[selected.rawValue] ?? .init()
        // startMode(...false) marks paused selection as fresh; its intermediate
        // audio application must not start an old scene. No mode switch for
        // Relax music selected while a meditation is already in progress.
        startMode(selected, autostart: false, reset: reset, deferAudio: true)
        var configs = store.generatorSettings ?? [:]; configs[selected.rawValue] = config; store.generatorSettings = configs
        for k in Array(store.layers.keys) { store.layers[k]?.enabled = false }
        store.layers["living"] = Layer(true, prefs.musicLevels[selected.rawValue] ?? 0.65)
        if let soundID = background.kind.soundID, sounds.contains(where: { $0.id == soundID }) {
            store.layers[soundID] = Layer(background.volume > 0, background.volume)
        }
        if autostart { if playing { applyAudio() } else { play() } } else { applyAudio() }
        page = "studio"; persist(); event("music_selected", ["id": id, "mode": selected.rawValue])
    }
    func resetCurrentMusicTuning() {
        guard let id = selectedMusicID, let profile = SoundProfile.find(id) else { return }
        var configs = store.generatorSettings ?? [:]; configs[mode.rawValue] = profile.configuration; store.generatorSettings = configs
        rememberCurrentMusic(); applyAudio(); persist(); notify("Sound settings restored.")
    }
    func setMusicLevel(_ value: Double) {
        let level = value.isFinite ? min(1, max(0, value)) : 0
        var prefs = listeningPreferences; prefs.musicLevels[mode.rawValue] = level; store.listening = prefs
        // Adjust without auto-starting or changing a remembered default.
        setSound("living", volume: level)
    }
    func setBackground(_ kind: BackgroundKind, volume: Double? = nil) throws {
        if let id = kind.soundID, !sounds.contains(where: { $0.id == id }) {
            throw OndeError("sound_missing", "This background is unavailable. Install the complete app.")
        }
        let old = currentBackground
        let level = volume ?? old.volume
        guard level.isFinite, (0...1).contains(level) else { throw OndeError("invalid_argument", "Background level must be between 0 and 1.") }
        var prefs = listeningPreferences
        prefs.backgrounds[mode.rawValue] = .init(kind: kind, volume: level)
        store.listening = prefs
        // One intentional background, instead of hidden accumulated noise layers.
        for id in BackgroundKind.soundIDs { store.layers[id]?.enabled = false }
        if let id = kind.soundID { store.layers[id] = Layer(level > 0, level) }
        applyAudio(); persist(); event("background", ["kind": kind.rawValue, "volume": level])
    }
    func changeBackground(_ kind: BackgroundKind, volume: Double? = nil) {
        do { try setBackground(kind, volume: volume) } catch { fail(error) }
    }
}
