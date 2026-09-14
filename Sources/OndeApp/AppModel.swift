import AppKit
import SwiftUI
import AVFoundation
import IOKit.pwr_mgt
import OndeCore

final class AppModel: ObservableObject {
    @Published var store = StoredState()
    @Published var clock = SessionClock()
    @Published var elapsed: Double = 0
    @Published var page = "studio"
    @Published var quietView = false
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var events: [[String: Any]] = []
    @Published var sounds: [Sound] = []
    @Published var generatorExporting = false
    @Published var generatorExportStatus: String?
    let updates = UpdateManager()
    let endel = EndelPlayer()
    private var ownsProfile = false
    private let audio = AudioEngine()
    private let server = CommandServer()
    private var heartbeat: Timer?
    private var saveTask: DispatchWorkItem?
    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var sessionActivity: NSObjectProtocol?
    private var sessionStarted: Date?
    private var sleepObserver: NSObjectProtocol?
    private var toastTicket = 0
    private var shuttingDown = false
    var now: Double { ProcessInfo.processInfo.systemUptime }
    var playing: Bool { clock.running }
    var mode: SessionMode { store.mode }
    var activeSounds: [Sound] { sounds.filter { store.layers[$0.id]?.enabled == true } }
    var nextMarker: Double? {
        guard mode == .meditation, store.preferences.chimesEnabled else { return nil }
        return store.preferences.markers.first { $0 > elapsed && !clock.fired.contains($0) }
    }
    var todaySeconds: Double {
        store.history.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.seconds } + elapsed
    }

    init() {
        do {
            try OndePaths.prepare()
            if FileManager.default.fileExists(atPath: OndePaths.state.path) {
                do { store = try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: OndePaths.state)) }
                catch {
                    // Never silently overwrite a malformed profile.
                    let backup = OndePaths.support.appendingPathComponent("state-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                    try FileManager.default.copyItem(at: OndePaths.state, to: backup)
                    errorMessage = "Les anciens réglages sont illisibles. Une copie a été conservée : \(backup.lastPathComponent)."
                }
            }
            store.preferences.masterVolume = clamp(store.preferences.masterVolume)
            store.preferences.chimeVolume = clamp(store.preferences.chimeVolume)
            store.preferences.fadeSeconds = min(10, max(0, store.preferences.fadeSeconds))
            store.preferences.markers = try validMarkers(store.preferences.markers)
            // Imported paths must be leaf filenames even when loading an edited state file.
            store.imported = store.imported.filter { $0.filename == URL(fileURLWithPath: $0.filename).lastPathComponent && !$0.filename.hasPrefix(".") }
            for id in Array(store.layers.keys) { store.layers[id]?.volume = clamp(store.layers[id]?.volume ?? 0) }
            sounds = (Sound.builtins + [Sound.living]).filter { audio.available($0) } + store.imported.filter { audio.available($0) }
            audio.transitionSeconds = min(30, max(2, store.transitionSeconds ?? 10))
            try server.start { [weak self] request in self?.handle(request) ?? ["ok": false] }
            ownsProfile = true
        } catch let e as OndeError where e.code == "already_running" {
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?.activate()
            DispatchQueue.main.async { NSApp.terminate(nil) }
        } catch { errorMessage = error.localizedDescription }
        heartbeat = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        if let heartbeat { RunLoop.main.add(heartbeat, forMode: .common) }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.playing else { return }; self.pause(); self.notify("Session en pause pendant la veille.")
        }
        endel.onState = { [weak self] state in
            guard let self, self.endel.selected != nil else { return }
            if state == "playing" && !self.playing {
                if self.sessionStarted == nil { self.sessionStarted = Date() }
                self.clock.resume(at: self.now); self.applyAudio()
            } else if ["paused", "error", "needs_click"].contains(state) && self.playing {
                self.clock.pause(at: self.now); self.elapsed = self.clock.elapsed(at: self.now); self.applyAudio()
            }
            self.event("endel_state", ["state": state])
        }
        event("app_ready")
    }
    private func clamp(_ n: Double) -> Double { n.isFinite ? min(1, max(0, n)) : 0 }
    func tick() {
        let current = clock.elapsed(at: now)
        if current != elapsed { elapsed = current }
        if mode == .meditation && clock.running {
            if let marker = clock.tick(at: now, markers: store.preferences.markers), store.preferences.chimesEnabled {
                do { try audio.chime(volume: store.preferences.chimeVolume * store.preferences.masterVolume); event("chime", ["marker_seconds": marker]) }
                catch { fail(error) }
            }
        }
    }
    func event(_ name: String, _ values: [String: Any] = [:]) {
        var item = values; item["type"] = name; item["at"] = ISO8601DateFormatter().string(from: Date()); item["elapsed_seconds"] = elapsed
        events.append(item); if events.count > 100 { events.removeFirst(events.count - 100) }
    }
    func notify(_ text: String) {
        toastTicket += 1; let ticket = toastTicket; toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in if self?.toastTicket == ticket { self?.toast = nil } }
    }
    func fail(_ error: Error) { errorMessage = error.localizedDescription; event("error", ["message": error.localizedDescription]) }
    func persist() {
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.persistNow() }
        saveTask = task; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
    func persistNow() {
        guard ownsProfile else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(store).write(to: OndePaths.state, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: OndePaths.state.path)
        } catch { errorMessage = "Impossible d’enregistrer les réglages : \(error.localizedDescription)" }
    }
    var transitionSeconds: Double { min(30, max(2, store.transitionSeconds ?? 10)) }
    func setTransitionSeconds(_ seconds: Double) { store.transitionSeconds = min(30, max(2, seconds)); audio.transitionSeconds = transitionSeconds; persist() }
    func applyAudio() {
        audio.transitionSeconds = transitionSeconds;
        do { try audio.apply(sounds: sounds, layers: store.layers, master: store.preferences.masterVolume, playing: playing && endel.selected == nil, fade: store.preferences.fadeSeconds, mode: mode, generatorConfig: generatorConfiguration) }
        catch { fail(error) }
        updateSleepAssertion()
    }
    private func updateSleepAssertion() {
        if playing && sessionActivity == nil {
            sessionActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Onde session timer")
        } else if !playing, let activity = sessionActivity {
            ProcessInfo.processInfo.endActivity(activity); sessionActivity = nil
        }
        let needed = playing && store.preferences.preventSleep
        if needed && !hasAssertion {
            hasAssertion = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Onde sound session" as CFString, &assertionID) == kIOReturnSuccess
        } else if !needed && hasAssertion { IOPMAssertionRelease(assertionID); hasAssertion = false }
    }
    func defaults(for mode: SessionMode) -> [String: Layer] {
        switch mode {
        case .focus: return ["aube": Layer(true, 0.55), "brown": Layer(true, 0.18)]
        case .relax: return ["piano": Layer(true, 0.50), "ocean": Layer(true, 0.26)]
        case .meditation: return ["aube": Layer(true, 0.32), "pink": Layer(true, 0.08)]
        }
    }
    func startMode(_ newMode: SessionMode, autostart: Bool = true, reset: Bool = false) {
        if endel.selected != nil { endel.clear() }
        if newMode != mode {
            recordSession(); store.modeMixes[mode.rawValue] = store.layers
            store.mode = newMode; store.layers = store.modeMixes[newMode.rawValue] ?? defaults(for: newMode)
            clock.stop(); elapsed = 0; sessionStarted = nil
        } else if reset { recordSession(); clock.stop(); elapsed = 0; sessionStarted = nil }
        page = "studio"
        if autostart { if playing { applyAudio() } else { play() } } else { applyAudio() }
        persist(); event("mode", ["mode": newMode.rawValue])
    }
    func play() {
        if endel.selected != nil { endel.play(); return }
        guard !playing else { return }
        if sessionStarted == nil { sessionStarted = Date() }
        clock.resume(at: now); applyAudio(); event("play")
    }
    func pause() { if endel.selected != nil { endel.pause() }; guard playing else { return }; clock.pause(at: now); elapsed = clock.elapsed(at: now); applyAudio(); event("pause") }
    func togglePlayback() { playing ? pause() : play() }
    private func recordSession() {
        let duration = clock.elapsed(at: now)
        if duration >= 1 {
            store.history.insert(SessionRecord(date: sessionStarted ?? Date(), mode: mode, seconds: duration), at: 0)
            if store.history.count > 200 { store.history = Array(store.history.prefix(200)) }
        }
    }
    func stop() { endel.clear(); recordSession(); clock.stop(); elapsed = 0; sessionStarted = nil; applyAudio(); persist(); event("stop") }
    func resetTimer() { clock.reset(at: now); elapsed = 0; sessionStarted = playing ? Date() : nil; event("timer_reset") }
    func shutdown() { guard ownsProfile, !shuttingDown else { return }; shuttingDown = true; endel.clear(); saveTask?.cancel(); recordSession(); persistNow(); audio.stopImmediately(); if let activity = sessionActivity { ProcessInfo.processInfo.endActivity(activity); sessionActivity = nil }; if hasAssertion { IOPMAssertionRelease(assertionID) } }
    func toggle(_ sound: Sound) { setSound(sound.id, enabled: !(store.layers[sound.id]?.enabled ?? false)) }
    func setSound(_ id: String, enabled: Bool? = nil, volume: Double? = nil) {
        var layer = store.layers[id] ?? Layer()
        if let enabled { layer.enabled = enabled }; if let volume { layer.volume = clamp(volume) }
        store.layers[id] = layer; applyAudio(); persist()
    }
    func setMaster(_ n: Double) { store.preferences.masterVolume = clamp(n); endel.setVolume(store.preferences.masterVolume); applyAudio(); persist() }
    func setChime(_ n: Double) { store.preferences.chimeVolume = clamp(n); persist() }
    func setMarkers(_ values: [Double]) throws {
        store.preferences.markers = try validMarkers(values)
        clock.skipPastMarkers(store.preferences.markers, at: now); persist(); event("markers_updated")
    }
    func previewChime() { do { try audio.chime(volume: store.preferences.chimeVolume * store.preferences.masterVolume) } catch { fail(error) } }
    func saveMix(name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw OndeError("invalid_name", "Le nom doit contenir entre 1 et 80 caractères.") }
        guard store.mixes.count < 200 else { throw OndeError("mix_limit", "La limite est de 200 ambiances.") }
        store.mixes.insert(Mix(name: name, mode: mode, layers: store.layers, generatorSettings: generatorConfiguration), at: 0); persist(); notify("Ambiance enregistrée.")
    }
    func loadMix(_ id: String, autostart: Bool = true) throws {
        guard let mix = store.mixes.first(where: { $0.id == id || $0.name == id }) else { throw OndeError("not_found", "Ambiance introuvable.") }
        startMode(mix.mode, autostart: false); store.layers = mix.layers
        if let settings = mix.generatorSettings { var all = store.generatorSettings ?? [:]; all[mix.mode.rawValue] = settings; store.generatorSettings = all }
        if autostart { play() }; applyAudio(); persist(); notify(mix.name)
    }
    func importSound(path: String, title: String? = nil) throws -> Sound {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        guard ["mp3","m4a","wav","aif","aiff","caf","flac"].contains(url.pathExtension.lowercased()) else { throw OndeError("unsupported_format", "Formats : MP3, M4A, WAV, AIFF, CAF et FLAC.") }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 500_000_000 else { throw OndeError("invalid_file", "Choisis un fichier audio local de moins de 500 Mo.") }
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.duration > 0 else { throw OndeError("invalid_audio", "Le fichier ne contient pas de son lisible.") }
        let id = "local-" + UUID().uuidString.lowercased()
        let filename = id + "." + url.pathExtension.lowercased()
        try FileManager.default.copyItem(at: url, to: OndePaths.imports.appendingPathComponent(filename))
        let sound = Sound(id: id, title: String((title ?? url.deletingPathExtension().lastPathComponent).prefix(100)), subtitle: "Import personnel · \(clockText(player.duration))", symbol: "music.note", kind: "Personnel", filename: filename, author: "Fichier personnel", license: "Privé · non redistribué", source: url.lastPathComponent, imported: true)
        store.imported.append(sound); sounds.append(sound); persist(); notify("Son importé dans ta bibliothèque locale."); return sound
    }
    func importFromPanel() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.message = "Les fichiers restent sur ce Mac. Les imports ne font pas partie du code publié."
        if panel.runModal() == .OK { for url in panel.urls { do { _ = try importSound(path: url.path) } catch { fail(error) } } }
    }
    func removeImport(_ id: String) throws {
        guard let sound = store.imported.first(where: { $0.id == id }) else { throw OndeError("not_imported", "Seuls les imports personnels peuvent être supprimés.") }
        setSound(id, enabled: false)
        try FileManager.default.removeItem(at: OndePaths.imports.appendingPathComponent(sound.filename))
        store.imported.removeAll { $0.id == id }; sounds.removeAll { $0.id == id }; store.layers.removeValue(forKey: id)
        for k in Array(store.modeMixes.keys) { store.modeMixes[k]?.removeValue(forKey: id) }
        for i in store.mixes.indices { store.mixes[i].layers.removeValue(forKey: id) }
        persist()
    }

    var generatorConfiguration: GenerativeSettings { store.generatorSettings?[mode.rawValue] ?? .preset(mode) }
    var generatorActive: Bool { store.layers["living"]?.enabled == true && endel.selected == nil }
    var generatorSnapshot: [String: Any] {
        var state = audio.generatorStatus
        state["configuration"] = jsonObject(generatorConfiguration)
        state["active"] = generatorActive
        state["mode"] = mode.rawValue
        state["title"] = generatorConfiguration.displayName
        return state
    }
    func startSoundProfile(_ id: String) {
        guard let profile = SoundProfile.find(id) else { return }
        startMode(profile.mode, autostart: false)
        var all = store.generatorSettings ?? [:]
        all[profile.mode.rawValue] = profile.configuration
        store.generatorSettings = all
        for key in Array(store.layers.keys) { store.layers[key]?.enabled = false }
        store.layers["living"] = Layer(true, store.layers["living"]?.volume ?? 0.65)
        if playing { applyAudio() } else { play() }
        page = "generative"; persist(); event("sound_profile", ["profile": id])
    }
    func startGenerator(_ selected: SessionMode, seed: UInt64? = nil, reset: Bool = false) {
        startMode(selected, autostart: false, reset: reset)
        if let seed { setGeneratorSeed(seed) }
        for key in Array(store.layers.keys) { store.layers[key]?.enabled = false }
        store.layers["living"] = Layer(true, store.layers["living"]?.volume ?? 0.65)
        if playing { applyAudio() } else { play() }
        page = "generative"; persist(); event("generator_play", ["mode": selected.rawValue, "seed": generatorConfiguration.seed])
    }
    func setGeneratorValue(_ key: String, _ value: Double) {
        do {
            var config = generatorConfiguration; try config.set(key, value)
            var all = store.generatorSettings ?? [:]; all[mode.rawValue] = config; store.generatorSettings = all
            applyAudio(); persist()
        } catch { fail(error) }
    }
    func setGeneratorSeed(_ seed: UInt64) {
        var config = generatorConfiguration; config.seed = seed
        do { _ = try config.validated() } catch { fail(error); return }
        var all = store.generatorSettings ?? [:]; all[mode.rawValue] = config; store.generatorSettings = all
        applyAudio(); persist(); event("generator_seed", ["seed": seed])
    }
    func resetGeneratorSettings() {
        var all = store.generatorSettings ?? [:]; all[mode.rawValue] = .preset(mode); store.generatorSettings = all
        applyAudio(); persist()
    }
    func exportGenerator(seconds: Double, path: String) {
        guard !generatorExporting else { return }
        generatorExporting = true; generatorExportStatus = "Composition du fichier en cours…"
        let mode = self.mode, config = generatorConfiguration
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let result = try GenerativeRenderer.render(mode: mode, configuration: config, seconds: seconds, path: path)
                DispatchQueue.main.async {
                    self?.generatorExporting = false; self?.generatorExportStatus = "Fichier créé : \(URL(fileURLWithPath: path).lastPathComponent)"
                    self?.notify("Paysage exporté."); self?.event("generator_export", ["seconds": result["seconds"] ?? 0, "path": path])
                }
            } catch {
                DispatchQueue.main.async { self?.generatorExporting = false; self?.generatorExportStatus = "Export non terminé."; self?.fail(error) }
            }
        }
    }

    func startEndel(_ id: String, meditation: Bool = false) {
        guard let session = EndelSession.find(id) else { return }
        startMode(meditation ? .meditation : session.mode, autostart: false, reset: true)
        endel.load(session, volume: store.preferences.masterVolume)
        page = "endel"; applyAudio()
        event("endel_selected", ["session": id, "offline": false])
    }
    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Onde" })?.makeKeyAndOrderFront(nil)
    }
    func snapshot() -> [String: Any] {
        ["version": AppBuild.version, "updates": updates.snapshot(), "generator": generatorSnapshot, "endel": endel.snapshot(), "mode": mode.rawValue, "status": playing ? "playing" : (elapsed > 0 ? "paused" : "stopped"),
         "elapsed_seconds": clock.elapsed(at: now), "formatted_elapsed": clockText(clock.elapsed(at: now)),
         "next_chime_seconds": nextMarker as Any? ?? NSNull(), "fired_markers": clock.fired.sorted(),
         "preferences": jsonObject(store.preferences), "layers": jsonObject(store.layers),
         "active_sound_ids": activeSounds.map(\.id), "audio_playing_ids": audio.playingIDs,
         "quiet_view": quietView, "page": page, "last_error": errorMessage as Any? ?? NSNull(), "socket": OndePaths.socket]
    }
    func handle(_ r: [String: Any]) -> [String: Any] {
        do {
            guard let cmd = r["command"] as? String else { throw OndeError("missing_command", "Missing command string. Run onde schema.") }
            var result: Any = NSNull()
            func number(_ key: String, min: Double = 0, max: Double = 1) throws -> Double {
                guard let n = r[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, n.doubleValue >= min, n.doubleValue <= max else { throw OndeError("invalid_argument", "\(key) must be a number in \(min)...\(max).") }
                return n.doubleValue
            }
            func string(_ key: String) throws -> String {
                guard let s = r[key] as? String, !s.isEmpty else { throw OndeError("invalid_argument", "Missing string: \(key).") }; return s
            }
            switch cmd {
            case "status": result = snapshot()
            case "mode":
                guard let m = SessionMode(rawValue: try string("mode")) else { throw OndeError("invalid_mode", "Use focus, relax, or meditation.") }
                startMode(m, autostart: r["play"] as? Bool ?? true, reset: r["reset"] as? Bool ?? false)
            case "play": play()
            case "pause": pause()
            case "stop": stop()
            case "volume": setMaster(try number("value"))
            case "sounds": result = sounds.map { s -> [String: Any] in
                var object = jsonObject(s) as! [String: Any]; object["layer"] = jsonObject(store.layers[s.id] ?? Layer()); return object
            }
            case "sound":
                let id = try string("id")
                guard sounds.contains(where: { $0.id == id }) else { throw OndeError("not_found", "Unknown sound id: \(id).") }
                guard r["enabled"] is Bool || r["volume"] != nil else { throw OndeError("invalid_argument", "Provide enabled or volume.") }
                let v = r["volume"] == nil ? nil : try number("volume")
                setSound(id, enabled: r["enabled"] as? Bool, volume: v)
            case "solo":
                let id = try string("id"); guard sounds.contains(where: { $0.id == id }) else { throw OndeError("not_found", "Unknown sound id.") }
                for k in Array(store.layers.keys) { store.layers[k]?.enabled = false }; setSound(id, enabled: true)
            case "silence":
                for k in Array(store.layers.keys) { store.layers[k]?.enabled = false }; applyAudio(); persist()
            case "timer.reset": resetTimer()
            case "timer.markers":
                guard let values = r["seconds"] as? [Double] else { throw OndeError("invalid_argument", "seconds must be an array of numbers.") }; try setMarkers(values)
            case "chime.preview": previewChime()
            case "settings":
                let key = try string("key")
                switch key {
                case "chimeVolume": setChime(try number("value"))
                case "fadeSeconds": store.preferences.fadeSeconds = try number("value", max: 10)
                case "chimesEnabled", "preventSleep", "reducedMotion":
                    guard let value = r["value"] as? Bool else { throw OndeError("invalid_argument", "value must be boolean.") }
                    if key == "chimesEnabled" { store.preferences.chimesEnabled = value; clock.skipPastMarkers(store.preferences.markers, at: now) }
                    if key == "preventSleep" { store.preferences.preventSleep = value }
                    if key == "reducedMotion" { store.preferences.reducedMotion = value }
                default: throw OndeError("invalid_key", "Keys: chimeVolume, fadeSeconds, chimesEnabled, preventSleep, reducedMotion.")
                }
                updateSleepAssertion(); persist()
            case "mixes": result = jsonObject(store.mixes)
            case "mix.save": try saveMix(name: string("name"))
            case "mix.load": try loadMix(string("id"), autostart: r["play"] as? Bool ?? true)
            case "mix.delete":
                let id = try string("id"); guard store.mixes.contains(where: { $0.id == id || $0.name == id }) else { throw OndeError("not_found", "Unknown mix.") }
                store.mixes.removeAll { $0.id == id || $0.name == id }; persist()
            case "import": result = jsonObject(try importSound(path: string("path"), title: r["title"] as? String))
            case "sound.remove": try removeImport(string("id"))
            case "history": result = jsonObject(store.history)
            case "history.clear": store.history = []; persist()
            case "events": result = events
            case "ui":
                if let p = r["page"] as? String { guard ["studio","library","mixes","settings","cli","history","credits","endel","generative","updates"].contains(p) else { throw OndeError("invalid_page", "Unknown page.") }; page = p }
                if let q = r["quiet"] as? Bool { quietView = q }
                if r["show"] as? Bool == true { showWindow() }

            case "generate.profiles": result = jsonObject(SoundProfile.all)
            case "generate.profile":
                let id = try string("id")
                guard SoundProfile.find(id) != nil else { throw OndeError("not_found", "Unknown sound profile. Use onde generate profiles.") }
                startSoundProfile(id); result = generatorSnapshot
            case "generate.status": result = generatorSnapshot
            case "generate.play":
                guard let selected = SessionMode(rawValue: try string("mode")) else { throw OndeError("invalid_mode", "Use focus, relax or meditation.") }
                var seed: UInt64? = nil
                if r["seed"] != nil { let n = try number("seed", max: 9_007_199_254_740_991); guard n.rounded(.down) == n else { throw OndeError("invalid_seed", "Seed must be an integer.") }; seed = UInt64(n) }
                startGenerator(selected, seed: seed, reset: r["reset"] as? Bool ?? false); result = generatorSnapshot
            case "generate.transition":
                setTransitionSeconds(try number("seconds", min: 2, max: 30)); result = generatorSnapshot
            case "generate.set":
                let key = try string("key"); let value = try number("value", min: GenerativeSettings.range(key).lowerBound, max: GenerativeSettings.range(key).upperBound)
                var copy = generatorConfiguration; try copy.set(key, value)
                setGeneratorValue(key, value); result = generatorSnapshot
            case "generate.seed":
                let n = try number("value", max: 9_007_199_254_740_991); guard n.rounded(.down) == n else { throw OndeError("invalid_seed", "Seed must be an integer.") }
                setGeneratorSeed(UInt64(n)); result = generatorSnapshot
            case "generate.defaults": resetGeneratorSettings(); result = generatorSnapshot
            case "endel.sessions": result = EndelSession.all.map(\.descriptor)
            case "endel.status": result = endel.snapshot()
            case "endel.play":
                let id = try string("id")
                guard EndelSession.find(id) != nil else { throw OndeError("not_found", "Session Endel inconnue. Utilisez onde endel list.") }
                startEndel(id, meditation: r["meditation"] as? Bool ?? false); result = endel.snapshot()
            case "endel.pause": pause(); result = endel.snapshot()
            case "endel.resume":
                guard endel.selected != nil else { throw OndeError("not_selected", "Choisissez une session Endel.") }
                endel.play(); result = endel.snapshot()
            case "endel.stop": stop(); result = endel.snapshot()
            case "endel.seek": try endel.seek(number("seconds", max: 86400)); result = endel.snapshot()
            case "endel.browser":
                let id = try string("id")
                guard let session = EndelSession.find(id), let url = URL(string: session.url), NSWorkspace.shared.open(url) else { throw OndeError("open_failed", "Impossible d’ouvrir cette session officielle.") }
                result = ["opened_url": session.url, "playback_confirmed": false, "timer_started": false]
            case "endel.web":
                guard NSWorkspace.shared.open(URL(string:"https://play.endel.io/")!) else { throw OndeError("open_failed", "Impossible d’ouvrir Endel.") }
                result = ["opened_url":"https://play.endel.io/", "playback_confirmed":false]
            case "updates.status": result = updates.snapshot()
            case "updates.check": updates.check(); result = updates.snapshot()
            case "updates.download":
                guard updates.candidate != nil else { throw OndeError("update_not_checked", "Vérifiez les mises à jour avant de télécharger.") }
                updates.download(); result = updates.snapshot()
            case "updates.automatic":
                guard let n = r["enabled"] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { throw OndeError("invalid_argument", "enabled must be a boolean.") }
                updates.automatic = n.boolValue; result = updates.snapshot()
            case "errors.clear": errorMessage = nil
            case "quit": shutdown(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { NSApp.terminate(nil) }
            default: throw OndeError("unknown_command", "Unknown command: \(cmd). Run onde schema.")
            }
            if result is NSNull { result = snapshot() }
            return ["ok": true, "result": result]
        } catch {
            let e = error as? OndeError ?? OndeError("operation_failed", error.localizedDescription)
            return ["ok": false, "error": ["code": e.code, "message": e.message]]
        }
    }
}
