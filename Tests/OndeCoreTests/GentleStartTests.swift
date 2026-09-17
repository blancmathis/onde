import XCTest
import OndeDSP
@testable import OndeCore

final class GentleStartTests: XCTestCase {
    func testLegacyPreferencesReceiveGentleStartWithoutChangingVolumesOrChimes() throws {
        let raw = #"{"masterVolume":0.7,"chimeVolume":0.2,"fadeSeconds":1.5,"markers":[600,1200,1800,2400],"chimesEnabled":true,"preventSleep":true,"reducedMotion":false}"#
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(raw.utf8))
        XCTAssertEqual(preferences.startFadeSeconds, 8)
        XCTAssertEqual(preferences.masterVolume, 0.7); XCTAssertEqual(preferences.chimeVolume, 0.2)
        XCTAssertEqual(preferences.fadeSeconds, 1.5); XCTAssertEqual(preferences.markers, [600,1200,1800,2400])
        var adjusted = preferences; adjusted.startFadeSeconds = 12
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(adjusted)).startFadeSeconds, 12)
    }
    func testCurveStartsQuietAndArrivesExactlyWithoutOvershoot() {
        var e = OndePlaybackEnvelope(); onde_envelope_reset(&e, 0); onde_envelope_to(&e, 1, 8)
        XCTAssertEqual(e.value, 0)
        XCTAssertEqual(onde_envelope_step(&e, 2), 0.0244140625, accuracy: 0.000001)
        XCTAssertEqual(onde_envelope_step(&e, 2), 0.25, accuracy: 0.000001)
        XCTAssertEqual(onde_envelope_step(&e, 2), 0.7119140625, accuracy: 0.000001)
        XCTAssertEqual(onde_envelope_step(&e, 2), 1)
        XCTAssertEqual(onde_envelope_step(&e, 1000), 1)
    }
    func testEnvelopeRejectsInvalidInputsAndSupportsDisabledFade() {
        var e = OndePlaybackEnvelope(); onde_envelope_reset(&e, 0.4)
        for duration in [-1.0, 31, Double.nan, Double.infinity] { onde_envelope_to(&e, 1, duration); XCTAssertEqual(e.value, 0.4) }
        onde_envelope_to(&e, .nan, 1); XCTAssertEqual(e.target, 0.4)
        onde_envelope_to(&e, 1, 0); XCTAssertEqual(e.value, 1)
        onde_envelope_to(&e, 0, 0); XCTAssertEqual(e.value, 0)
    }
    func testRapidPauseResumeRetargetsFromTheCurrentLevelWithoutJump() {
        var e = OndePlaybackEnvelope(); onde_envelope_reset(&e, 0); onde_envelope_to(&e, 1, 8)
        _ = onde_envelope_step(&e, 4); let initial = e.value
        onde_envelope_to(&e, 0, 0.2); XCTAssertEqual(e.value, initial)
        _ = onde_envelope_step(&e, 0.05); let paused = e.value
        onde_envelope_to(&e, 1, 2); XCTAssertEqual(e.value, paused)
        var previous = paused
        for _ in 0..<200 { let value = onde_envelope_step(&e, 0.01); XCTAssertGreaterThanOrEqual(value, previous); XCTAssertLessThanOrEqual(value, 1); previous = value }
        XCTAssertEqual(e.value, 1, accuracy: 0.00001)
    }
    private let rate: Double = 8000
    private func makeCore(_ name: String = "sillage") throws -> OpaquePointer {
        let config = try XCTUnwrap(SoundProfile.find(name)).configuration
        let p = try XCTUnwrap(onde_dsp_create(rate, 0, config.seed))
        for (i,v) in config.values.enumerated() { onde_dsp_set(p, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(p, Int32(ONDE_GAIN), 1)
        return p
    }
    @discardableResult private func render(_ m: OpaquePointer, _ seconds: Double) -> Float {
        var l = [Float](repeating: 0, count: 256), r = l
        var remaining = Int((seconds * rate).rounded()); var peak: Float = 0
        while remaining > 0 {
            let n = min(256, remaining); onde_scene_mixer_render(m, &l, &r, UInt32(n))
            for i in 0..<n { XCTAssertTrue(l[i].isFinite && r[i].isFinite); peak = max(peak, abs(l[i]), abs(r[i])) }
            onde_scene_mixer_collect(m); remaining -= n
        }
        return peak
    }
    func testSlowPreparationCannotConsumeTheEntranceBeforeAnyAudioExists() throws {
        let m = try XCTUnwrap(onde_scene_mixer_create(rate)); defer { onde_scene_mixer_destroy(m) }
        onde_scene_mixer_gain(m, 0.5); onde_scene_mixer_playback(m, 1, 8)
        XCTAssertEqual(render(m, 12), 0)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 0)
        XCTAssertEqual(onde_scene_mixer_entrance_progress(m), 0)
        XCTAssertEqual(onde_scene_mixer_submit(m, try makeCore(), 10), 1)
        var l: Float = 123, r: Float = 123
        onde_scene_mixer_render(m, &l, &r, 1); XCTAssertEqual(l, 0); XCTAssertEqual(r, 0)
        render(m, 2)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 0.024414, accuracy: 0.0001)
        XCTAssertLessThan(onde_scene_mixer_actual_gain(m), 0.013)
        render(m, 6)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 1)
        XCTAssertEqual(onde_scene_mixer_actual_gain(m), 0.5, accuracy: 0.001)
    }
    func testMasterVolumeChangeDoesNotRestartOrBypassTheEntrance() throws {
        let m = try XCTUnwrap(onde_scene_mixer_create(rate)); defer { onde_scene_mixer_destroy(m) }
        XCTAssertEqual(onde_scene_mixer_submit(m, try makeCore(), 10), 1)
        onde_scene_mixer_gain(m, 0.2); onde_scene_mixer_playback(m, 1, 8); render(m, 2)
        onde_scene_mixer_gain(m, 0.8); render(m, 2)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 0.25, accuracy: 0.00001)
        XCTAssertLessThanOrEqual(onde_scene_mixer_actual_gain(m), 0.201)
        render(m, 4); XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 1)
        onde_scene_mixer_gain(m, 0); render(m, 2)
        XCTAssertLessThan(onde_scene_mixer_actual_gain(m), 0.000001)
    }
    func testPauseSettlesToSilenceAndResumeTakesTwoSeconds() throws {
        let m = try XCTUnwrap(onde_scene_mixer_create(rate)); defer { onde_scene_mixer_destroy(m) }
        XCTAssertEqual(onde_scene_mixer_submit(m, try makeCore(), 2), 1)
        onde_scene_mixer_gain(m, 0.6); onde_scene_mixer_playback(m, 1, 8); render(m, 3)
        onde_scene_mixer_playback(m, 0, 0.2); render(m, 1)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 0); XCTAssertEqual(render(m, 0.25), 0)
        onde_scene_mixer_playback(m, 1, 2); render(m, 1)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 0.25, accuracy: 0.00001)
        render(m, 1.001); XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 1)
    }
    func testSceneCrossfadeDoesNotRestartTransportFade() throws {
        let m = try XCTUnwrap(onde_scene_mixer_create(rate)); defer { onde_scene_mixer_destroy(m) }
        XCTAssertEqual(onde_scene_mixer_submit(m, try makeCore(), 2), 1)
        onde_scene_mixer_gain(m, 0.5); onde_scene_mixer_playback(m, 1, 2); render(m, 3)
        XCTAssertEqual(onde_scene_mixer_submit(m, try makeCore("meridien"), 2), 1)
        render(m, 6)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(m), 1)
        XCTAssertEqual(onde_scene_mixer_state(m), 0)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(m)), 7)
    }
}
