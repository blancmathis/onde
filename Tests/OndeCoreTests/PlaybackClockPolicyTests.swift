import XCTest
@testable import OndeCore

final class PlaybackClockPolicyTests: XCTestCase {
    func testInactiveTransportNeverCountsEvenIfAudioIsFadingOut() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: false, mode: .focus, hasSelection: true, hasRunningAudio: true, preparing: false, failed: false, at: 0), .idle)
    }
    func testNoSourcesPauseFocusAndRelaxButNotSilentMeditation() {
        for mode in SessionMode.allCases {
            var p = PlaybackClockPolicy()
            XCTAssertEqual(p.evaluate(requested: true, mode: mode, hasSelection: false, hasRunningAudio: false, preparing: false, failed: false, at: 0), mode == .meditation ? .count : .noSources)
        }
    }
    func testPreparingDoesNotCountAndHasAFiniteDeadline() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 10), .wait)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 39.9), .wait)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 40), .unavailable)
    }
    func testOutputLossFreezesImmediatelyThenPauses() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: true, mode: .relax, hasSelection: true, hasRunningAudio: true, preparing: false, failed: false, at: 1), .count)
        XCTAssertEqual(p.evaluate(requested: true, mode: .relax, hasSelection: true, hasRunningAudio: false, preparing: false, failed: false, at: 2), .wait)
        XCTAssertEqual(p.evaluate(requested: true, mode: .relax, hasSelection: true, hasRunningAudio: false, preparing: false, failed: false, at: 4), .unavailable)
    }
    func testAudioRecoveryClearsTheGraceWindow() {
        var p = PlaybackClockPolicy()
        _ = p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: false, failed: false, at: 0)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: true, preparing: false, failed: false, at: 1), .count)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: false, failed: false, at: 100), .wait)
    }
    func testActiveOldSceneOrBackgroundKeepsCountingDuringPreparation() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: true, preparing: true, failed: false, at: 0), .count)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: true, preparing: false, failed: true, at: 100), .count)
    }
    func testFailedMeditationAudioIsNotMistakenForDeliberateSilence() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: true, mode: .meditation, hasSelection: true, hasRunningAudio: false, preparing: false, failed: true, at: 0), .unavailable)
    }
    func testExplicitPauseAndNewRequestResetDeadline() {
        var p = PlaybackClockPolicy()
        _ = p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 0)
        _ = p.evaluate(requested: false, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 1)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 100), .wait)
    }
    func testNonFiniteAndBackwardsTimeDoNotCreateInfiniteCounting() {
        var p = PlaybackClockPolicy()
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: .nan), .unavailable)
        _ = p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 100)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 90), .wait)
        XCTAssertEqual(p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: false, preparing: true, failed: false, at: 120), .unavailable)
    }
    func testClockCountsOnlyTheReadyIntervalsAndDoesNotCatchUp() {
        var p = PlaybackClockPolicy(), c = SessionClock()
        for (time, ready) in [(0.0,false),(5.0,true),(15.0,false),(16.0,true),(26.0,false)] {
            let decision = p.evaluate(requested: true, mode: .focus, hasSelection: true, hasRunningAudio: ready, preparing: true, failed: false, at: time)
            if decision == .count { c.resume(at: time) } else { c.pause(at: time) }
        }
        XCTAssertEqual(c.elapsed(at: 500), 20)
        c.stop(); XCTAssertEqual(c.elapsed(at: 900), 0)
    }
    func testMenuBarLabelIsConstantAndHasNoClockOrPlaybackDependency() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/OndeApp/OndeApp.swift"))
        let label = try XCTUnwrap(source.components(separatedBy: "MenuBarExtra {").last?.components(separatedBy: "}.menuBarExtraStyle").first?.components(separatedBy: "} label: {").last)
        XCTAssertTrue(label.contains("OndeStatusIcon.image"))
        XCTAssertFalse(label.contains("model.")); XCTAssertFalse(label.contains("Text(")); XCTAssertFalse(label.contains("systemName:"))
    }
}
