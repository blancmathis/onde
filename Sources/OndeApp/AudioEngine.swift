import Foundation
import AVFoundation
import OndeCore

/// AVAudioPlayer keeps decoding and mixing off the UI thread. No audio capture,
/// network streaming, subscriptions, or third-party audio runtime is involved.
final class AudioEngine {
    private var players: [String: AVAudioPlayer] = [:]
    private let living = GenerativeEngine()
    var transitionSeconds: Double { get { living.transitionSeconds } set { living.transitionSeconds = newValue } }
    var generatorStatus: [String: Any] { living.snapshot() }
    private var generation = 0
    private var bell: AVAudioPlayer?
    private(set) var playingIDs: [String] = []
    var soundsDirectory: URL { Bundle.main.resourceURL!.appendingPathComponent("Sounds") }
    func url(for sound: Sound) -> URL {
        (sound.imported ? OndePaths.imports : soundsDirectory).appendingPathComponent(sound.filename)
    }
    func available(_ sound: Sound) -> Bool { sound.id == "living" || FileManager.default.fileExists(atPath: url(for: sound).path) }
    func apply(sounds: [Sound], layers: [String: Layer], master: Double, playing: Bool, fade: Double, mode: SessionMode, generatorConfig: GenerativeSettings) throws {
        generation += 1
        let ticket = generation
        let desired = Set(sounds.filter { layers[$0.id]?.enabled == true && playing }.map(\.id))
        let sum = desired.reduce(0.0) { $0 + (layers[$1]?.volume ?? 0) }
        // Normalized sum of gains <= master: avoid clipping when adding layers.
        let normalization = 1.0 / max(1.0, sum)
        var errors: [String] = []
        do { try living.apply(mode: mode, config: generatorConfig, gain: (layers["living"]?.volume ?? 0.65) * master * normalization, playing: desired.contains("living")) }
        catch { errors.append(error.localizedDescription) }
        for sound in sounds where desired.contains(sound.id) && sound.id != "living" {
            do {
                if players[sound.id] == nil {
                    let player = try AVAudioPlayer(contentsOf: url(for: sound))
                    player.numberOfLoops = -1; player.volume = 0; player.prepareToPlay()
                    players[sound.id] = player
                }
                guard let player = players[sound.id] else { continue }
                if !player.isPlaying { player.volume = 0; guard player.play() else { throw OndeError("audio_unavailable", "La sortie audio n’est pas disponible.") } }
                player.setVolume(Float((layers[sound.id]?.volume ?? 0) * master * normalization), fadeDuration: fade)
            } catch { errors.append("\(sound.title) : \(error.localizedDescription)") }
        }
        for (id, player) in players where !desired.contains(id) {
            player.setVolume(0, fadeDuration: min(1.2, fade))
            DispatchQueue.main.asyncAfter(deadline: .now() + min(1.2, fade) + 0.05) { [weak self, weak player] in
                guard self?.generation == ticket else { return }
                player?.pause()
            }
        }
        if !playing { bell?.setVolume(0, fadeDuration: 0.15) }
        playingIDs = desired.filter { $0 == "living" ? living.running : players[$0]?.isPlaying == true }.sorted()
        if !errors.isEmpty { throw OndeError("audio_error", errors.joined(separator: "\n")) }
    }
    func chime(volume: Double) throws {
        if bell == nil {
            bell = try AVAudioPlayer(contentsOf: soundsDirectory.appendingPathComponent("chime.m4a"))
            bell?.prepareToPlay()
        }
        bell?.stop(); bell?.currentTime = 0; bell?.volume = Float(volume)
        guard bell?.play() == true else { throw OndeError("chime_error", "Le carillon n’a pas pu être lu.") }
    }
    func stopImmediately() { living.reset(); for p in players.values { p.stop() }; bell?.stop(); playingIDs = [] }
}
