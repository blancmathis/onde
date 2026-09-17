import XCTest
@testable import OndeCore

final class DailyActivityTests: XCTestCase {
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    var paris: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Paris")!; return c }
    func test26HourSessionIsSplitAtLocalMidnight() {
        var l = ActivityLedger()
        l.record(start: date("2026-09-16T18:00:00Z"), end: date("2026-09-17T20:00:00Z"))
        XCTAssertEqual(l.seconds(on: date("2026-09-16T12:00:00Z"), calendar: paris), 4 * 3600)
        XCTAssertEqual(l.seconds(on: date("2026-09-17T20:00:00Z"), calendar: paris), 22 * 3600)
    }
    func testLiveMidnightRollsOverWithoutStoppingSession() {
        var t = ActivityTracker()
        let start = date("2026-09-17T21:59:50Z")
        t.resume(at: start, uptime: 0); t.sample(at: start.addingTimeInterval(20), uptime: 20)
        XCTAssertTrue(t.running)
        XCTAssertEqual(t.ledger.seconds(on: start, calendar: paris), 10)
        XCTAssertEqual(t.ledger.seconds(on: start.addingTimeInterval(20), calendar: paris), 10)
    }
    func testPausedSessionIsZeroOnTheNextDay() {
        var t = ActivityTracker(); let a = date("2026-09-17T12:00:00Z")
        t.resume(at: a, uptime: 0); t.pause(at: a.addingTimeInterval(60), uptime: 60)
        t.sample(at: a.addingTimeInterval(90000), uptime: 90000)
        XCTAssertEqual(t.ledger.seconds(on: a.addingTimeInterval(90000), calendar: paris), 0)
    }
    func testPauseGapsDoNotCountAcrossDays() {
        var t = ActivityTracker(); let a = date("2026-09-17T21:50:00Z")
        t.resume(at: a, uptime: 100); t.pause(at: a.addingTimeInterval(300), uptime: 400)
        let b = a.addingTimeInterval(1200)
        t.resume(at: b, uptime: 1300); t.pause(at: b.addingTimeInterval(300), uptime: 1600)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 300)
        XCTAssertEqual(t.ledger.seconds(on: b, calendar: paris), 300)
    }
    func testStopwatchResetDoesNotLoseOrDuplicateLedger() {
        var t = ActivityTracker(); var c = SessionClock(); let a = date("2026-09-17T10:00:00Z")
        c.start(at: 0); t.resume(at: a, uptime: 0); t.pause(at: a.addingTimeInterval(60), uptime: 60)
        c.reset(at: 60); t.resume(at: a.addingTimeInterval(60), uptime: 60)
        t.pause(at: a.addingTimeInterval(90), uptime: 90)
        XCTAssertEqual(c.elapsed(at: 90), 30)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 90)
    }
    func testSerializationNeverResumesOfflineTime() throws {
        var t = ActivityTracker(); let a = date("2026-09-17T10:00:00Z")
        t.resume(at: a, uptime: 0); t.sample(at: a.addingTimeInterval(60), uptime: 60)
        let data = try JSONEncoder().encode(t.ledger)
        var restored = ActivityTracker(ledger: try JSONDecoder().decode(ActivityLedger.self, from: data))
        XCTAssertFalse(restored.running)
        restored.sample(at: a.addingTimeInterval(7200), uptime: 7200)
        XCTAssertEqual(restored.ledger.seconds(on: a, calendar: paris), 60)
    }
    func testResumeAndCheckpointAreIdempotent() {
        var t = ActivityTracker(); let a = date("2026-09-17T10:00:00Z")
        t.resume(at: a, uptime: 0); t.resume(at: a.addingTimeInterval(20), uptime: 20)
        t.sample(at: a.addingTimeInterval(60), uptime: 60); t.sample(at: a.addingTimeInterval(60), uptime: 60)
        t.pause(at: a.addingTimeInterval(60), uptime: 60); t.pause(at: a.addingTimeInterval(60), uptime: 60)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 60)
    }
    func testClockJumpDoesNotInventHours() {
        var t = ActivityTracker(); let a = date("2026-09-17T10:00:00Z")
        t.resume(at: a, uptime: 0); t.sample(at: a.addingTimeInterval(3600), uptime: 1)
        t.sample(at: a.addingTimeInterval(3601), uptime: 2)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 1)
    }
    func testClockMovingBackDoesNotDoubleCount() {
        var t = ActivityTracker(); let a = date("2026-09-17T10:00:00Z")
        t.resume(at: a, uptime: 0); t.sample(at: a.addingTimeInterval(60), uptime: 60)
        t.sample(at: a, uptime: 61); t.sample(at: a.addingTimeInterval(60), uptime: 121)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 60)
    }
    func testDaylightSavingUses23And25HourDays() {
        let spring = date("2026-03-29T12:00:00Z"), autumn = date("2026-10-25T12:00:00Z")
        for (day, hours) in [(spring, 23), (autumn, 25)] {
            let span = paris.dateInterval(of: .day, for: day)!
            var l = ActivityLedger(); l.record(start: span.start, end: span.end)
            XCTAssertEqual(l.seconds(on: day, calendar: paris), Double(hours * 3600))
        }
    }
    func testTimeZoneReallocationUsesAbsoluteIntervals() {
        var l = ActivityLedger(); l.record(start: date("2026-09-17T21:30:00Z"), end: date("2026-09-17T22:30:00Z"))
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(l.seconds(on: date("2026-09-17T12:00:00Z"), calendar: utc), 3600)
        XCTAssertEqual(l.seconds(on: date("2026-09-17T12:00:00Z"), calendar: paris), 1800)
    }
    func testDuplicateAndOverlappingHistoryAreUnioned() {
        let a = date("2026-09-17T10:00:00Z")
        let r = SessionRecord(date: a, mode: .focus, seconds: 3600)
        let l = ActivityLedger.migrating([r, r, SessionRecord(date: a.addingTimeInterval(1800), mode: .relax, seconds: 3600)], asOf: a.addingTimeInterval(6000))
        XCTAssertEqual(l.seconds(on: a, calendar: paris), 5400)
        XCTAssertEqual(l.legacyRecordCount, 3)
    }
    func testLegacy26HoursAreClippedNotResetOrDeleted() {
        let a = date("2026-09-16T18:00:00Z"), now = date("2026-09-17T20:00:00Z")
        let l = ActivityLedger.migrating([SessionRecord(date: a, mode: .focus, seconds: 93600)], asOf: now)
        XCTAssertEqual(l.seconds(on: now, until: now, calendar: paris), 79200)
        XCTAssertEqual(l.seconds(on: a, calendar: paris), 14400)
    }
    func testFutureAndInvalidIntervalsNeverCount() {
        let a = date("2026-09-17T10:00:00Z"); var l = ActivityLedger()
        l.record(start: a.addingTimeInterval(60), end: a)
        l.record(start: a, end: Date(timeIntervalSinceReferenceDate: .infinity))
        l.record(start: a.addingTimeInterval(3600), end: a.addingTimeInterval(7200))
        XCTAssertEqual(l.seconds(on: a, until: a, calendar: paris), 0)
    }
    func testCheckpointsCoalesceToOneInterval() {
        var t = ActivityTracker(); let a = date("2026-09-17T10:00:00Z")
        t.resume(at: a, uptime: 0)
        for i in 1...10000 { t.sample(at: a.addingTimeInterval(Double(i) / 4), uptime: Double(i) / 4) }
        XCTAssertEqual(t.ledger.intervals.count, 1)
        XCTAssertEqual(t.ledger.seconds(on: a, calendar: paris), 2500)
    }
    func testOldStoredStateDecodesWithoutLedger() throws {
        var object = jsonObject(StoredState()) as! [String: Any]; object.removeValue(forKey: "activityLedger")
        let s = try JSONDecoder().decode(StoredState.self, from: jsonData(object))
        XCTAssertNil(s.activityLedger)
    }
}
