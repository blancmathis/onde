import XCTest
@testable import OndeCore
final class ClockTests: XCTestCase {
    func testDefaultMarkersAndUnlimitedTimer() {
        var c = SessionClock(); c.start(at: 100)
        XCTAssertNil(c.tick(at: 699, markers: [600,1200,1800]))
        XCTAssertEqual(c.tick(at: 700, markers: [600,1200,1800]), 600)
        XCTAssertNil(c.tick(at: 700.5, markers: [600,1200,1800]))
        XCTAssertEqual(c.tick(at: 1300, markers: [600,1200,1800]), 1200)
        XCTAssertEqual(c.tick(at: 1900, markers: [600,1200,1800]), 1800)
        XCTAssertNil(c.tick(at: 2500, markers: [600,1200,1800]))
        XCTAssertNil(c.tick(at: 10900, markers: [600,1200,1800]))
        XCTAssertEqual(c.elapsed(at: 10900), 10800)
        XCTAssertTrue(c.running)
    }
    func testPauseDoesNotCountPausedTime() {
        var c = SessionClock(); c.start(at: 100); c.pause(at: 250)
        XCTAssertEqual(c.elapsed(at: 1000), 150)
        c.resume(at: 1000); XCTAssertEqual(c.elapsed(at: 1450), 600)
        XCTAssertEqual(c.tick(at: 1450, markers: [600]), 600)
    }
    func testNoCatchupChimesAfterStall() {
        var c = SessionClock(); c.start(at: 0)
        XCTAssertNil(c.tick(at: 2000, markers: [600,1200,1800]))
        XCTAssertEqual(c.fired.count, 3)
    }
    func testOnlyNewestCrossingEmits() {
        var c = SessionClock(); c.start(at: 0)
        XCTAssertEqual(c.tick(at: 1800.1, markers: [600,1200,1800]), 1800)
        XCTAssertEqual(c.fired.count, 3)
    }
    func testEditingMarkersDoesNotReplayPast() {
        var c = SessionClock(); c.start(at: 0); c.skipPastMarkers([30,100], at: 40)
        XCTAssertNil(c.tick(at: 40, markers: [30,100]))
        XCTAssertEqual(c.tick(at: 100, markers: [30,100]), 100)
    }
    func testResetAllowsNewSession() {
        var c = SessionClock(); c.start(at: 0)
        _ = c.tick(at: 600, markers: [600]); c.reset(at: 700)
        XCTAssertEqual(c.elapsed(at: 700), 0)
        XCTAssertEqual(c.tick(at: 1300, markers: [600]), 600)
        c.stop(); XCTAssertFalse(c.running); XCTAssertEqual(c.elapsed(at: 10000), 0)
    }
    func testValidateMarkers() throws {
        XCTAssertEqual(try validMarkers([1200,600,600]), [600,1200])
        XCTAssertEqual(try validMarkers([]), [])
        XCTAssertThrowsError(try validMarkers([-1]))
        XCTAssertThrowsError(try validMarkers([.nan]))
        XCTAssertThrowsError(try validMarkers([.infinity]))
        XCTAssertThrowsError(try validMarkers([86401]))
    }
    func testFormatting() {
        XCTAssertEqual(clockText(30 * 60), "30:00")
        XCTAssertEqual(clockText(3661), "1:01:01")
    }
    func testPersistenceRoundTrip() throws {
        let value = StoredState()
        let restored = try JSONDecoder().decode(StoredState.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.preferences.markers, [600,1200,1800])
        XCTAssertEqual(restored.layers["aube"]?.enabled, true)
    }
}
