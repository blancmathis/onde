import XCTest
import OndeDSP
@testable import OndeCore
final class LivingV3Tests: XCTestCase {
    func advance(_ core: OpaquePointer, _ frames: Int) {
        var l = [Float](repeating: 0, count: 1024), r = l
        for start in stride(from: 0, to: frames, by: 1024) {
            onde_dsp_render(core, &l, &r, UInt32(min(1024, frames-start)))
            XCTAssertTrue(l.allSatisfy { $0.isFinite && abs($0) <= 0.951 })
        }
    }
    func testBeatGridIsExactForOneMinute() throws {
        let p = try XCTUnwrap(onde_dsp_create(44100, 0, 42)); defer { onde_dsp_destroy(p) }
        onde_dsp_set(p, Int32(ONDE_GAIN), 1); advance(p, 44100*60)
        XCTAssertEqual(onde_dsp_beats(p), 72)
        XCTAssertEqual(onde_dsp_ticks(p), 288)
        XCTAssertEqual(onde_dsp_min_beat_gap(p), 36750)
        XCTAssertEqual(onde_dsp_max_beat_gap(p), 36750)
        XCTAssertEqual(onde_dsp_note_events(p), 36)
        XCTAssertEqual(onde_dsp_grain_events(p), 0)
    }
    func testDensityDoesNotChangeTempo() throws {
        let p = try XCTUnwrap(onde_dsp_create(22050, 0, 42)); defer { onde_dsp_destroy(p) }
        onde_dsp_set(p, Int32(ONDE_GAIN), 1)
        advance(p, 22050*5); onde_dsp_set(p, Int32(ONDE_DENSITY), 1); advance(p, 22050*5)
        XCTAssertEqual(onde_dsp_bpm(p), 72, accuracy: 0.0001)
    }
    func testSeventeenProfilesAndDifferentFocusChoices() throws {
        XCTAssertEqual(SoundProfile.all.count, 17)
        XCTAssertEqual(SoundProfile.all.filter { $0.mode == .focus }.count, 14)
        XCTAssertEqual(SoundProfile.find("abysses")?.configuration.tempo, 64)
        XCTAssertGreaterThan(SoundProfile.find("abysses")!.configuration.bass, SoundProfile.find("courant")!.configuration.bass)
        for p in SoundProfile.all { _ = try p.configuration.validated() }
    }
    func testOldConfigurationPreservesEveryOldValue() throws {
        let raw = #"{"seed":81,"density":0.27,"brightness":0.16,"movement":0.3,"space":0.81,"texture":0.2,"pulse":0.06,"evolution":0.16,"settleMinutes":42}"#
        let restored = try JSONDecoder().decode(GenerativeSettings.self, from: Data(raw.utf8))
        XCTAssertEqual(restored.seed, 81); XCTAssertEqual(restored.density, 0.27)
        XCTAssertEqual(restored.space, 0.81); XCTAssertEqual(restored.settleMinutes, 42)
        XCTAssertEqual(restored.tempo, 72); XCTAssertEqual(restored.bass, 0.78)
        XCTAssertNil(restored.profileID)
    }
    func testNewConfigurationRoundTrips() throws {
        let p = SoundProfile.find("abysses")!.configuration
        XCTAssertEqual(try JSONDecoder().decode(GenerativeSettings.self, from: JSONEncoder().encode(p)), p)
    }
    func testGainSlotIsNeverUsedByBass() {
        XCTAssertEqual(GenerativeSettings.dspIndex(8), Int32(ONDE_BASS))
        XCTAssertEqual(GenerativeSettings.dspIndex(9), Int32(ONDE_TEMPO))
        XCTAssertEqual(GenerativeSettings.dspIndex(12), Int32(ONDE_CHARACTER))
    }
    func testTempoBoundsRejectNonsense() throws {
        var c = GenerativeSettings()
        XCTAssertThrowsError(try c.set("tempo", 0))
        XCTAssertThrowsError(try c.set("tempo", 121))
        XCTAssertThrowsError(try c.set("bass", 2))
        try c.set("tempo", 64); XCTAssertEqual(c.tempo, 64)
    }
    func testFixedTempoWithFractionalSamplePeriod() throws {
        let p = try XCTUnwrap(onde_dsp_create(22050, 0, 1042)); defer { onde_dsp_destroy(p) }
        onde_dsp_set(p, Int32(ONDE_TEMPO), 64); advance(p, 22050*30)
        XCTAssertEqual(onde_dsp_beats(p), 32)
        XCTAssertLessThanOrEqual(onde_dsp_max_beat_gap(p) - onde_dsp_min_beat_gap(p), 1)
    }
}
