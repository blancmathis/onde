import Foundation

/// A wall-clock interval during which the session was running (silence counts,
/// pause and sleep do not). Never persists a running anchor across launches.
public struct ActivityInterval: Codable, Equatable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}

/// Separate from session history and the unlimited stopwatch. Half-open intervals
/// are clipped to the user's calendar day, then unioned to avoid double counting.
/// There is no hard-coded 86,400-second "day": DST can make a day 23 or 25 hours.
public struct ActivityLedger: Codable, Equatable {
    public var version = 1
    public private(set) var intervals: [ActivityInterval] = []
    public private(set) var legacyRecordCount = 0
    public init() {}

    public mutating func record(start: Date, end: Date) {
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite, end > start else { return }
        // Normal playback extends one interval, not a new record each heartbeat.
        if let last = intervals.last, start >= last.start, start.timeIntervalSince(last.end) <= 0.002 {
            if end > last.end { intervals[intervals.count - 1].end = end }
        } else {
            intervals.append(ActivityInterval(start: start, end: end))
        }
    }

    public func seconds(on date: Date, until cutoff: Date? = nil,
                        calendar: Calendar = .autoupdatingCurrent) -> Double {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return 0 }
        let end = min(day.end, cutoff ?? day.end)
        guard end > day.start else { return 0 }
        let clipped = intervals.compactMap { item -> ActivityInterval? in
            guard item.start.timeIntervalSinceReferenceDate.isFinite,
                  item.end.timeIntervalSinceReferenceDate.isFinite else { return nil }
            let a = max(day.start, item.start), b = min(end, item.end)
            return b > a ? ActivityInterval(start: a, end: b) : nil
        }.sorted { $0.start < $1.start }
        var total = 0.0
        var previous: ActivityInterval?
        for interval in clipped {
            if var p = previous {
                if interval.start <= p.end { p.end = max(p.end, interval.end); previous = p }
                else { total += p.end.timeIntervalSince(p.start); previous = interval }
            } else { previous = interval }
        }
        if let p = previous { total += p.end.timeIntervalSince(p.start) }
        return max(0, min(total, end.timeIntervalSince(day.start)))
    }

    /// Old files contain only a start date and total active duration, not pauses.
    /// Preserve history verbatim; derive an explicitly approximate day allocation
    /// once, bounded by the migration date. New sessions never use this estimate.
    public static func migrating(_ records: [SessionRecord], asOf now: Date) -> Self {
        var ledger = Self()
        for record in records.sorted(by: { $0.date < $1.date }) {
            guard record.seconds.isFinite, record.seconds > 0,
                  record.date.timeIntervalSinceReferenceDate.isFinite, record.date < now else { continue }
            let duration = min(record.seconds, now.timeIntervalSince(record.date))
            ledger.record(start: record.date, end: record.date.addingTimeInterval(duration))
            ledger.legacyRecordCount += 1
        }
        return ledger
    }
}

/// Reconciles a monotonic clock with wall-clock calendar dates. Clock adjustments
/// cannot create fictitious hours: discontinuous wall-clock jumps re-anchor the
/// next interval. Pauses and restarts are explicit and do not catch up lost time.
public struct ActivityTracker {
    public private(set) var ledger: ActivityLedger
    private var wallAnchor: Date?
    private var uptimeAnchor: Double?
    public var running: Bool { wallAnchor != nil }
    public init(ledger: ActivityLedger = ActivityLedger()) { self.ledger = ledger }
    public mutating func resume(at wall: Date, uptime: Double) {
        guard !running, uptime.isFinite else { return }
        wallAnchor = wall; uptimeAnchor = uptime
    }
    public mutating func sample(at wall: Date, uptime: Double) {
        guard let a = wallAnchor, let u = uptimeAnchor else { return }
        defer { wallAnchor = wall; uptimeAnchor = uptime }
        let elapsed = uptime - u, wallElapsed = wall.timeIntervalSince(a)
        guard elapsed.isFinite, wallElapsed.isFinite, elapsed >= 0, wallElapsed >= 0,
              abs(elapsed - wallElapsed) <= 2.0 else { return }
        // Small clock corrections must not increase active time. Matching clocks
        // preserve exact contiguity, allowing constant memory per running span.
        let duration = min(elapsed, wallElapsed)
        if duration > 0 { ledger.record(start: a, end: a.addingTimeInterval(duration)) }
    }
    public mutating func pause(at wall: Date, uptime: Double) {
        sample(at: wall, uptime: uptime); wallAnchor = nil; uptimeAnchor = nil
    }
}
