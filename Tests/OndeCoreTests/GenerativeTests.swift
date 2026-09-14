import XCTest
import OndeDSP
@testable import OndeCore
final class GenerativeTests: XCTestCase {
    func samples(mode: Int32 = 0, seed: UInt64 = 42, frames: Int = 44100, block: Int = 511) -> [Float] {
        guard let dsp = onde_dsp_create(44100, mode, seed) else { XCTFail("allocation"); return [] }
        defer { onde_dsp_destroy(dsp) }
        onde_dsp_set(dsp, Int32(ONDE_GAIN), 1)
        var left = [Float](repeating: 0, count: frames), right = left
        left.withUnsafeMutableBufferPointer { l in right.withUnsafeMutableBufferPointer { r in
            for offset in stride(from: 0, to: frames, by: block) {
                onde_dsp_render(dsp, l.baseAddress!.advanced(by: offset), r.baseAddress!.advanced(by: offset), UInt32(min(block, frames-offset)))
            }
        } }
        XCTAssertEqual(onde_dsp_frames(dsp), UInt64(frames))
        return left + right
    }
    func testSameSeedReproducesOutput() { XCTAssertEqual(samples(seed: 65), samples(seed: 65)) }
    func testDifferentSeedsProduceDifferentMusic() { XCTAssertNotEqual(samples(seed: 65), samples(seed: 66)) }
    func testRenderIsIndependentOfBlockSize() { XCTAssertEqual(samples(block: 127), samples(block: 2048)) }
    func testEveryModeProducesFiniteBoundedNonSilentAudio() {
        for mode: Int32 in 0...2 {
            let x = samples(mode: mode, frames: 88200)
            XCTAssertTrue(x.allSatisfy { $0.isFinite && abs($0) <= 0.951 })
            XCTAssertGreaterThan(x.map { abs($0) }.max() ?? 0, 0.005)
        }
    }
    func testControlBoundsAndBooleansAreNotMeaningfulFrequencies() throws {
        var s = GenerativeSettings()
        XCTAssertThrowsError(try s.set("density", -1))
        XCTAssertThrowsError(try s.set("density", .nan))
        XCTAssertThrowsError(try s.set("unknown", 0.1))
        XCTAssertThrowsError(try s.set("settleMinutes", 121))
        try s.set("settleMinutes", 0); XCTAssertEqual(s.settleMinutes, 0)
    }
    func testAllDefaultsValidate() throws { for mode in SessionMode.allCases { _ = try GenerativeSettings.preset(mode).validated() } }
    func testOldProfilesStillDecode() throws {
        var object = jsonObject(StoredState()) as! [String: Any]
        object.removeValue(forKey: "generatorSettings")
        let restored = try JSONDecoder().decode(StoredState.self, from: jsonData(object))
        XCTAssertNil(restored.generatorSettings)
        XCTAssertEqual(restored.preferences.markers, [600,1200,1800])
    }
    func testLegacyMixStillDecodes() throws {
        var object = jsonObject(Mix(name: "legacy", mode: .focus, layers: [:])) as! [String: Any]
        object.removeValue(forKey: "generatorSettings")
        let restored = try JSONDecoder().decode(Mix.self, from: jsonData(object))
        XCTAssertNil(restored.generatorSettings)
    }
    func testRenderRejectsInvalidConfiguration() {
        XCTAssertThrowsError(try GenerativeRenderer.render(mode: .focus, configuration: .preset(.focus), seconds: -1, path: "/tmp/invalid.wav"))
        XCTAssertThrowsError(try GenerativeRenderer.render(mode: .focus, configuration: .preset(.focus), seconds: 1, path: "/tmp/invalid.mp3"))
    }
    func testBadSampleRateFailsCleanly() { XCTAssertNil(onde_dsp_create(0, 0, 0)); XCTAssertNil(onde_dsp_create(44100, 10, 0)) }
}
