# Daily activity accounting

## Two independent clocks

The **session stopwatch** measures running time in the current session. It can exceed 24 hours. **Today** measures the intersection of recorded running intervals with the current local calendar day. It does not add the full session stopwatch to today's history.

The implementation is in `Sources/OndeCore/DailyActivity.swift` and its integration in `AppModel.swift`.

## Counting rules

Play starts a monotonic/wall-clock anchor. A heartbeat records the interval elapsed since the previous sample. Pause ends the interval. Resume starts another interval: the pause gap is excluded. Recorded-layer silence and intentional meditation silence still count when the session is running. This is session time, not a cognitive-productivity score.

A session crossing midnight is split by calendar intersection, without resetting the stopwatch, replaying chimes or changing audio. The UI refreshes while paused too, so yesterday's total does not remain displayed after midnight.

`Calendar.autoupdatingCurrent.dateInterval(of: .day, for:)` determines day boundaries. This handles local time zones and 23/25-hour daylight-saving days. Absolute intervals are reassigned to the current local calendar on a time-zone change.

Intervals are unioned before summation. Duplicate or overlapping records cannot inflate the result. Consecutive samples coalesce to avoid allocating a new record every heartbeat. Significant wall-clock changes compared with the monotonic clock re-anchor the tracker rather than adding fictitious hours. Sub-millisecond scheduling differences are coalesced.

Resetting the stopwatch records the completed segment but does not reset the daily ledger. Ending a session, switching mode and quitting commit activity exactly once to the ledger; session-history entries are not summed again. Normal quit persists all sampled activity. Active checkpoints are scheduled every 15 seconds. An unexpected kill can lose the most recent unsaved seconds; offline time is never added after a restart.

## Existing data

Before 1.9, history stores only `date` and `seconds` for each completed session. It does not record individual pauses. On first launch, a separate ledger is created once by estimating a continuous active interval from each historical start, capped at the migration time. Overlaps are merged. Original history entries, mixes, audio, preferences and identifiers are preserved.

This repairs impossible daily totals without pretending to reconstruct pauses that were never saved. `legacyRecordCount` records whether estimates were imported. The History screen explains this limitation. The estimate is not applied to new sessions.

## CLI

`onde status` returns:

- `today_seconds`: current-day active session time, through the present moment.
- `today_time_zone`: the time zone used by the current-day calculation.
- `daily_history_estimated`: whether historical pre-ledger records were imported.
- `elapsed_seconds`: the separate current-session stopwatch.

No test-only time-travel command is exposed in the app. Calendar tests inject their clocks into the pure core. Native integration tests use a temporary `ONDE_HOME` and keep output muted.

## Regression coverage

The deterministic tests cover a 26-hour session, live and paused midnight rollover, pause gaps, stopwatch reset, restart/checkpoint idempotence, duplicate and overlapping records, forward/backward clock changes, timezone changes, 23/25-hour days, future/invalid spans, and old-state decoding. Integration tests exercise the actual app/CLI with migrated history, pauses, resets, stop and restart.

Foundation reference: https://developer.apple.com/documentation/foundation/calendar/dateinterval(of:for:)
