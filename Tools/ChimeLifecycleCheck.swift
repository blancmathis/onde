import Foundation
import AVFoundation

/// Exercise AVAudioPlayer lifecycle with digital silence: gain assertions never
/// generate audible output. This is not a subjective audio-quality test.
@main struct ChimeLifecycleCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("silence.wav")
        var data = Data()
        func text(_ s: String) { data.append(contentsOf: s.utf8) }
        func u16(_ n: UInt16) { var n = n.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var n = n.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        let bytes: UInt32 = 44_100 * 2 * 2 / 2 // half a second, stereo PCM16
        text("RIFF"); u32(36 + bytes); text("WAVEfmt "); u32(16); u16(1); u16(2)
        u32(44_100); u32(176_400); u16(4); u16(16); text("data"); u32(bytes)
        data.append(Data(count: Int(bytes))); try data.write(to: url)
        let chime = ChimePlayer()
        var checks: [String] = []
        func check(_ passed: Bool, _ name: String) throws {
            guard passed else { throw NSError(domain: "ChimeCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
            checks.append(name); print("PASS \(name)")
        }
        func pump(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func retained() -> Bool { chime.snapshot["retained"] as? Bool == true }
        func volume() -> Double { chime.snapshot["volume"] as? Double ?? -1 }
        try check(!retained(), "No audio player allocated before a chime")
        try chime.play(url: url, volume: 0.4)
        try check(retained(), "Playback retains its active player")
        chime.setVolume(0)
        try check(volume() == 0, "Muting affects an already-playing chime immediately")
        chime.setVolume(0.25)
        try check(abs(volume() - 0.25) < 0.001, "Live chime gain follows the requested combined volume")
        chime.setVolume(.nan)
        try check(volume() == 0, "Nonfinite gain becomes silence")
        chime.setVolume(3)
        try check(volume() == 1, "Gain remains bounded")
        chime.stop(); chime.stop()
        try check(!retained(), "Repeated stop releases the player safely")
        try chime.play(url: url, volume: 0)
        pump(1.2)
        try check(!retained(), "Natural completion releases the player")
        try chime.play(url: url, volume: 0)
        chime.fadeOut(); chime.setVolume(0.7)
        try check(volume() == 0, "A gain edit cannot revive a fading-out chime")
        pump(0.3)
        try check(!retained(), "Transport fade-out releases the player")
        try chime.play(url: url, volume: 0)
        chime.fadeOut(); pump(0.03)
        try chime.play(url: url, volume: 0)
        pump(0.25)
        try check(retained(), "Old fade completion does not stop a new preview")
        chime.stop()
        var rejectedMissingAudio = false
        do { try chime.play(url: directory.appendingPathComponent("missing.wav"), volume: 0) }
        catch { rejectedMissingAudio = true }
        try check(rejectedMissingAudio && !retained(), "Failed playback throws and leaves no retained player")
        let summary: [String: Any] = ["ok": true, "passed": checks.count, "checks": checks, "fixture": "digital silence"]
        print(String(data: try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
