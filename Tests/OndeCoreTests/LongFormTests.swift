import XCTest
import OndeDSP
@testable import OndeCore

final class LongFormTests: XCTestCase {
    private func fingerprint(_ style: Int32, _ seed: UInt64, _ phrase: UInt64) -> UInt64 {
        var plan = OndePhrasePlan()
        XCTAssertEqual(onde_phrase_plan(style, seed, phrase, 0.38, &plan), 1)
        return plan.fingerprint
    }
    func testPlansHaveLongRangeDevelopmentWithoutChangingTheirIdentity() {
        for style: Int32 in 1...7 {
            let plans = (0..<128).map { fingerprint(style, 8100 + UInt64(style), UInt64($0)) }
            XCTAssertGreaterThan(Set(plans).count, 12, "Not a short cyclic playlist of chord/motif states")
            XCTAssertNotEqual(Array(plans[0..<16]), Array(plans[16..<32]))
            XCTAssertEqual(plans, (0..<128).map { fingerprint(style, 8100 + UInt64(style), UInt64($0)) })
        }
    }
    func testQuestionAndAnswerAreNotTheSameFourNotes() {
        for style: Int32 in 1...7 {
            for phrase: UInt64 in 0..<32 {
                var p = OndePhrasePlan(); XCTAssertEqual(onde_phrase_plan(style, 42, phrase, 0.4, &p), 1)
                let notes = withUnsafeBytes(of: p.melody) { Array($0.bindMemory(to: Int32.self)) }
                XCTAssertEqual(notes.count, 16)
                XCTAssertTrue(notes.allSatisfy { (0...4).contains($0) })
                XCTAssertNotEqual(Array(notes[0..<8]), Array(notes[8..<16]))
                XCTAssertEqual(p.chapter, phrase / 8)
            }
        }
    }
    func testEvolutionCanBeFrozenAndBadPlansRejected() {
        var a = OndePhrasePlan(), b = OndePhrasePlan()
        XCTAssertEqual(onde_phrase_plan(1, 42, 0, 0, &a), 1)
        XCTAssertEqual(onde_phrase_plan(1, 42, 10000, 0, &b), 1)
        // Explicit still mode retains harmony/theme (bass inversions remain musical anchors).
        XCTAssertEqual(a.variant, b.variant); XCTAssertEqual(a.harmony, b.harmony)
        XCTAssertEqual(onde_phrase_plan(8, 42, 0, 0.4, &a), 0)
        XCTAssertEqual(onde_phrase_plan(1, 42, 0, .nan, &a), 0)
        XCTAssertEqual(onde_phrase_plan(1, 42, UInt64.max - 1, 0.4, &a), 1)
    }
    private func core(_ id: String, rate: Double = 22050) throws -> OpaquePointer {
        let p = try XCTUnwrap(SoundProfile.find(id))
        let core = try XCTUnwrap(onde_dsp_create(rate, 0, p.configuration.seed))
        for (i, v) in p.configuration.values.enumerated() { onde_dsp_set(core, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1); return core
    }
    private func advance(_ mixer: OpaquePointer, seconds: Double, rate: Double = 22050) -> (Float, Float) {
        var left = [Float](repeating: 0, count: 511), right = left
        var remaining = Int(seconds * rate); var peak: Float = 0, jump: Float = 0, previous: Float = 0
        while remaining > 0 {
            let n = min(remaining, left.count)
            onde_scene_mixer_render(mixer, &left, &right, UInt32(n))
            for i in 0..<n { XCTAssertTrue(left[i].isFinite && right[i].isFinite); peak = max(peak, abs(left[i]), abs(right[i])); jump = max(jump, abs(left[i] - previous)); previous = left[i] }
            onde_scene_mixer_collect(mixer); remaining -= n
        }
        return (peak, jump)
    }
    func testSceneHandoverCompletesWithBoundedAudio() throws {
        let mixer = try XCTUnwrap(onde_scene_mixer_create(22050)); defer { onde_scene_mixer_destroy(mixer) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("sillage"), 4), 1)
        onde_scene_mixer_gain(mixer, 1)
        _ = advance(mixer, seconds: 6)
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("meridien"), 4), 1)
        let result = advance(mixer, seconds: 10)
        XCTAssertGreaterThan(result.0, 0.015); XCTAssertLessThanOrEqual(result.0, 0.951)
        XCTAssertLessThan(result.1, 0.25)
        XCTAssertEqual(onde_scene_mixer_state(mixer), 0)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(mixer)), 7)
        XCTAssertEqual(onde_scene_mixer_progress(mixer), 1)
    }
    func testRapidSelectionsKeepLastPendingRequestAndPauseRemainsAvailable() throws {
        let mixer = try XCTUnwrap(onde_scene_mixer_create(22050)); defer { onde_scene_mixer_destroy(mixer) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("sillage"), 2), 1)
        onde_scene_mixer_gain(mixer, 1); _ = advance(mixer, seconds: 3)
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("ambre"), 2), 1)
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("meridien"), 2), 1)
        _ = advance(mixer, seconds: 7)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(mixer)), 7)
        onde_scene_mixer_gain(mixer, 0); _ = advance(mixer, seconds: 3)
        XCTAssertLessThan(onde_scene_mixer_peak(mixer), 0.0001)
        onde_scene_mixer_gain(mixer, 1); XCTAssertGreaterThan(advance(mixer, seconds: 3).0, 0.02)
    }
    func testRetirementCanWaitWithoutOverwritingOrLeakingAScene() throws {
        let mixer = try XCTUnwrap(onde_scene_mixer_create(22050)); defer { onde_scene_mixer_destroy(mixer) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("sillage"), 2), 1)
        var l = [Float](repeating: 0, count: 1024), r = l
        for _ in 0..<65 { onde_scene_mixer_render(mixer, &l, &r, 1024) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("meridien"), 2), 1)
        for _ in 0..<160 { onde_scene_mixer_render(mixer, &l, &r, 1024) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("ambre"), 2), 1)
        for _ in 0..<60 { onde_scene_mixer_render(mixer, &l, &r, 1024) }
        XCTAssertEqual(onde_scene_mixer_pending(mixer), 1)
        onde_scene_mixer_collect(mixer)
        _ = advance(mixer, seconds: 7)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(mixer)), 5)
    }
}
