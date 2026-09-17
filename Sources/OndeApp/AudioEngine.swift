import Foundation
import AVFoundation
import OndeCore

/// Local recorded layers and real-time synthesis share the same entrance curve.
/// Chimes are deliberately outside that transport envelope.
final class AudioEngine {
    private var players: [String: RecordedLayer] = [:]
    private let living = GenerativeEngine()
    private var rampTimer: Timer?
    private var wasPlaying = false
    private var lastDesired: Set<String> = []
    private var startFade: Double = 8
    var transitionSeconds: Double { get { living.transitionSeconds } set { living.transitionSeconds = newValue } }
    var generatorStatus: [String: Any] { living.snapshot() }
    private var bell: AVAudioPlayer?
    var playingIDs: [String] {
        lastDesired.filter { $0 == "living" ? living.running : players[$0]?.selected == true && players[$0]?.player.isPlaying == true }.sorted()
    }
    var playbackSnapshot: [String: Any] {
        ["start_fade_seconds": startFade, "resume_fade_seconds": min(2, startFade),
         "curve": "squared_smoothstep", "recorded_layers": players.mapValues { $0.snapshot }]
    }
    var soundsDirectory: URL { Bundle.main.resourceURL!.appendingPathComponent("Sounds") }
    func url(for sound: Sound) -> URL {
        (sound.imported ? OndePaths.imports : soundsDirectory).appendingPathComponent(sound.filename)
    }
    func available(_ sound: Sound) -> Bool { sound.id == "living" || FileManager.default.fileExists(atPath: url(for: sound).path) }
    deinit { rampTimer?.invalidate() }
    private func runRamps() {
        guard rampTimer == nil, players.values.contains(where: { $0.needsTick }) else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            for layer in self.players.values { layer.tick() }
            if !self.players.values.contains(where: { $0.needsTick }) {
                self.rampTimer?.invalidate(); self.rampTimer = nil
            }
        }
        rampTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func apply(sounds: [Sound], layers: [String: Layer], master: Double, playing: Bool, fade: Double,
               mode: SessionMode, generatorConfig: GenerativeSettings, startFadeSeconds: Double = 8, freshStart: Bool = false) throws {
        startFade = min(20, max(0, startFadeSeconds))
        let desired = Set(sounds.filter { layers[$0.id]?.enabled == true && playing }.map(\.id))
        let resuming = playing && !wasPlaying && !freshStart
        let sum = desired.reduce(0.0) { $0 + (layers[$1]?.volume ?? 0) }
        let normalization = 1.0 / max(1.0, sum)
        var errors: [String] = []
        do {
            try living.apply(mode: mode, config: generatorConfig,
                             gain: (layers["living"]?.volume ?? 0.65) * master * normalization,
                             playing: desired.contains("living"), startFadeSeconds: startFade,
                             freshStart: freshStart || (playing && wasPlaying && !lastDesired.contains("living")))
        } catch { errors.append(error.localizedDescription) }
        for sound in sounds where desired.contains(sound.id) && sound.id != "living" {
            do {
                if players[sound.id] == nil { players[sound.id] = try RecordedLayer(url: url(for: sound)) }
                guard let layer = players[sound.id] else { continue }
                let entrance = resuming && layer.hasPlayed ? min(2, startFade) : startFade
                try layer.configure(enabled: true, gain: Float((layers[sound.id]?.volume ?? 0) * master * normalization),
                                    adjustment: fade, entrance: entrance)
            } catch { errors.append("\(sound.title): \(error.localizedDescription)") }
        }
        for (id, layer) in players where !desired.contains(id) {
            // Muting transport leaves the stored volume unchanged.
            do { try layer.configure(enabled: false, gain: Float((layers[id]?.volume ?? 0) * master * normalization), adjustment: fade, entrance: startFade) }
            catch { errors.append(error.localizedDescription) }
        }
        wasPlaying = playing; lastDesired = desired; runRamps()
        if !playing { bell?.setVolume(0, fadeDuration: 0.15) }
        if !errors.isEmpty { throw OndeError("audio_error", errors.joined(separator: "\n")) }
    }
    func chime(volume: Double) throws {
        if bell == nil {
            bell = try AVAudioPlayer(contentsOf: soundsDirectory.appendingPathComponent("chime.m4a"))
            bell?.prepareToPlay()
        }
        bell?.stop(); bell?.currentTime = 0; bell?.volume = Float(volume)
        guard bell?.play() == true else { throw OndeError("chime_error", "The chime could not be played.") }
    }
    func stopImmediately() {
        rampTimer?.invalidate(); rampTimer = nil; living.reset()
        for layer in players.values { layer.stop() }
        bell?.stop(); wasPlaying = false; lastDesired = []
    }
}
