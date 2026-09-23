import Foundation
import AVFoundation

/// One short-lived chime, outside the music transport envelope. All commands
/// arrive on the main thread; delegate cleanup is deferred to that same queue.
final class ChimePlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var fadeOutWork: DispatchWorkItem?
    private var generation: UInt64 = 0

    var snapshot: [String: Any] {
        ["retained": player != nil, "playing": player?.isPlaying == true,
         "volume": Double(player?.volume ?? 0), "fading_out": fadeOutWork != nil]
    }

    func play(url: URL, volume: Double) throws {
        stop()
        let next = try AVAudioPlayer(contentsOf: url)
        next.delegate = self
        next.volume = gain(volume)
        player = next
        guard next.play() else {
            stop()
            throw NSError(domain: "Onde.Audio", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "The chime could not be played."])
        }
    }

    /// A master-volume change also affects a chime already playing. Muting must
    /// not wait for a fade; increasing gain must not revive a transport fade-out.
    func setVolume(_ volume: Double) {
        let value = gain(volume)
        if fadeOutWork == nil || value == 0 { player?.setVolume(value, fadeDuration: 0) }
    }

    func fadeOut() {
        guard let player else { return }
        fadeOutWork?.cancel()
        generation &+= 1
        let ticket = generation
        player.setVolume(0, fadeDuration: 0.15)
        let work = DispatchWorkItem { [weak self, weak player] in
            guard let self, let player, self.generation == ticket, self.player === player else { return }
            self.stop()
        }
        fadeOutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    func stop() {
        generation &+= 1
        fadeOutWork?.cancel(); fadeOutWork = nil
        let previous = player
        player = nil
        previous?.delegate = nil
        previous?.stop()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        releaseWhenCurrent(player)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        releaseWhenCurrent(player)
    }

    private func releaseWhenCurrent(_ finished: AVAudioPlayer) {
        // A delayed callback from an old preview must never stop its replacement.
        DispatchQueue.main.async { [weak self, weak finished] in
            guard let self, let finished, self.player === finished else { return }
            self.stop()
        }
    }

    private func gain(_ volume: Double) -> Float {
        Float(volume.isFinite ? min(1, max(0, volume)) : 0)
    }

    deinit { stop() }
}
