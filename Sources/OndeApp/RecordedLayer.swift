import Foundation
import AVFoundation
import OndeDSP

/// The transport envelope is independent of user gain: moving a slider cannot
/// bypass/restart the entrance. Audio-device time, not time spent loading, drives it.
final class RecordedLayer {
    let player: AVAudioPlayer
    private var envelope = OndePlaybackEnvelope()
    private var firstGain: Float = 0
    private var intermediateTicks: UInt64 = 0
    private var entranceSerial: UInt64 = 0
    private var audioTime: TimeInterval = 0
    private var level: Float = 0
    private var target: Float = 0
    private var adjustmentSeconds: Double = 0.2
    private(set) var selected = false
    private(set) var hasPlayed = false
    private(set) var entranceSeconds: Double = 0
    private(set) var outputGain: Float = 0

    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        onde_envelope_reset(&envelope, 0)
    }
    func configure(enabled: Bool, gain: Float, adjustment: Double, entrance: Double) throws {
        tick()
        let proposed = max(0, min(1, gain))
        target = enabled ? proposed : min(target, proposed)
        adjustmentSeconds = max(0.015, adjustment / 4)
        if enabled && !selected {
            if !player.isPlaying {
                player.volume = 0
                onde_envelope_reset(&envelope, 0)
                level = target
                guard player.play() else { throw NSError(domain: "Onde.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio output is unavailable."]) }
            }
            audioTime = player.deviceCurrentTime
            entranceSeconds = entrance
            firstGain = envelope.value; intermediateTicks = 0; entranceSerial &+= 1
            onde_envelope_to(&envelope, 1, max(0.015, entrance))
            hasPlayed = true
        } else if !enabled && selected {
            onde_envelope_to(&envelope, 0, 0.20)
        }
        selected = enabled
    }
    func tick() {
        guard player.isPlaying else { return }
        let now = player.deviceCurrentTime
        let dt = max(0, now - audioTime)
        audioTime = now
        _ = onde_envelope_step(&envelope, dt)
        if selected && envelope.value > 0 && envelope.value < 1 { intermediateTicks &+= 1 }
        level += Float(1 - exp(-dt / adjustmentSeconds)) * (target - level)
        if abs(level-target) < 0.000001 { level = target }
        outputGain = level * envelope.value
        // Interpolate between control ticks in AVFoundation, never make volume steps.
        player.setVolume(outputGain, fadeDuration: 1.0 / 60.0)
        if !selected && envelope.value <= 0.000001 {
            player.pause(); player.volume = 0; outputGain = 0
            onde_envelope_reset(&envelope, 0)
        }
    }
    var needsTick: Bool {
        player.isPlaying && (!selected || onde_envelope_progress(&envelope) < 1 || abs(level-target) >= 0.000001)
    }
    var snapshot: [String: Any] {
        ["playing": player.isPlaying && selected, "position_seconds": player.currentTime,
         "duration_seconds": player.duration, "first_gain": firstGain, "intermediate_ticks": intermediateTicks, "entrance_serial": entranceSerial, "entrance_gain": envelope.value,
         "entrance_progress": onde_envelope_progress(&envelope), "entrance_seconds": entranceSeconds,
         "output_gain": outputGain, "target_gain": target]
    }
    func stop() {
        player.stop(); player.currentTime = 0; player.volume = 0; selected = false; hasPlayed = false
        level = 0; target = 0; outputGain = 0; onde_envelope_reset(&envelope, 0)
    }
}
