import XCTest
import OndeDSP
@testable import OndeCore

final class LivingV2Tests: XCTestCase {
    private func render(_ core: OpaquePointer, seconds: Double, sr: Double = 22050) -> (Float, Float) {
        var l = [Float](repeating: 0, count: 1024), r = l
        var remaining = Int(seconds * sr), peak: Float = 0, maximumStep: Float = 0, previous: Float = 0
        while remaining > 0 {
            let n = min(remaining, l.count)
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                onde_dsp_render(core, lp.baseAddress!, rp.baseAddress!, UInt32(n))
            } }
            for i in 0..<n {
                XCTAssertTrue(l[i].isFinite && r[i].isFinite)
                peak = max(peak, abs(l[i]), abs(r[i]))
                maximumStep = max(maximumStep, abs(l[i] - previous)); previous = l[i]
            }
            remaining -= n
        }
        return (peak, maximumStep)
    }
    func testStableArrangementRemovesGranularNoiseAndEarlyHarmonyChanges() throws {
        let core = try XCTUnwrap(onde_dsp_create(22050, 0, 42)); defer { onde_dsp_destroy(core) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1)
        let result = render(core, seconds: 70)
        XCTAssertGreaterThan(onde_dsp_bars(core), 16)
        XCTAssertGreaterThan(onde_dsp_note_events(core), 30)
        XCTAssertEqual(onde_dsp_grain_events(core), 0)
        XCTAssertEqual(onde_dsp_section(core), 0)
        XCTAssertEqual(onde_dsp_harmony(core), 0)
        XCTAssertGreaterThan(result.0, 0.01); XCTAssertLessThanOrEqual(result.0, 0.951)
    }
    func testMeditationStopsNewNotesAndGrainsAfterSettling() throws {
        let core = try XCTUnwrap(onde_dsp_create(22050, 2, 2718)); defer { onde_dsp_destroy(core) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1)
        onde_dsp_set(core, Int32(ONDE_SETTLE_MINUTES), 0.2)
        _ = render(core, seconds: 22)
        let notes = onde_dsp_note_events(core), grains = onde_dsp_grain_events(core)
        let result = render(core, seconds: 22)
        XCTAssertEqual(notes, onde_dsp_note_events(core)); XCTAssertEqual(grains, onde_dsp_grain_events(core))
        XCTAssertGreaterThan(result.0, 0.002, "Continuous pad remains, without new transients")
    }
    func testExtremeSettingsStayFiniteAndBounded() throws {
        for mode: Int32 in 0...2 {
            let core = try XCTUnwrap(onde_dsp_create(22050, mode, 909))
            for p: Int32 in 0...6 { onde_dsp_set(core, p, 1) }
            onde_dsp_set(core, Int32(ONDE_GAIN), 1)
            let result = render(core, seconds: 12)
            XCTAssertLessThanOrEqual(result.0, 0.951)
            onde_dsp_destroy(core)
        }
    }
    func testModeAndSeedChangesKeepRunningWithoutNaN() throws {
        let core = try XCTUnwrap(onde_dsp_create(22050, 0, 42)); defer { onde_dsp_destroy(core) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1)
        _ = render(core, seconds: 3)
        onde_dsp_set_mode(core, 1); onde_dsp_set_seed(core, 812)
        let result = render(core, seconds: 4)
        XCTAssertEqual(onde_dsp_frames(core), 154350)
        XCTAssertLessThanOrEqual(result.0, 0.951)
        XCTAssertGreaterThan(onde_dsp_voices(core), 0)
    }
}
