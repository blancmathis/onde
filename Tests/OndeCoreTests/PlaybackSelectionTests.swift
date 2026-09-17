import XCTest
@testable import OndeCore

final class PlaybackSelectionTests: XCTestCase {
    func testPlainResumeDoesNotRequestRestart() {
        var selection = PlaybackSelection()
        XCTAssertFalse(selection.consumeRestart())
        XCTAssertFalse(selection.consumeRestart())
    }
    func testPausedSelectionRequestsOneFreshStart() {
        var selection = PlaybackSelection()
        selection.select(whilePlaying: false)
        XCTAssertTrue(selection.restartPending)
        XCTAssertTrue(selection.consumeRestart())
        XCTAssertFalse(selection.consumeRestart())
    }
    func testLiveSelectionRetainsCrossfade() {
        var selection = PlaybackSelection()
        selection.select(whilePlaying: true)
        XCTAssertFalse(selection.consumeRestart())
    }
    func testRepeatedDeferredSelectionsRemainOneRestart() {
        var selection = PlaybackSelection()
        for _ in 0..<100 { selection.select(whilePlaying: false) }
        XCTAssertTrue(selection.consumeRestart())
        XCTAssertFalse(selection.consumeRestart())
    }
    func testStopThenPlayIsFreshRatherThanResume() {
        var selection = PlaybackSelection()
        selection.stop()
        XCTAssertTrue(selection.consumeRestart())
        XCTAssertFalse(selection.consumeRestart())
    }
    func testPlaybackIntentDoesNotModifySessionTiming() {
        var clock = SessionClock(); var selection = PlaybackSelection()
        clock.start(at: 100); clock.pause(at: 140)
        selection.select(whilePlaying: clock.running)
        XCTAssertTrue(selection.consumeRestart())
        clock.resume(at: 200)
        XCTAssertEqual(clock.elapsed(at: 210), 50)
    }
}
