# Menu-bar identity and transport timing — 1.11.2

The menu-bar item is a constant, cached 18-point template of the original Onde app icon (concentric organic waves and their orbit point). No clock title, waveform swap, or audio-state decoration. The popover still exposes the playback controls and the current session time.

## Timing contract

Play requests playback; it does not by itself mean an audio graph is ready. SessionClock is now independent of that request. Focus/Relax time runs while a selected generated or recorded source is running. Preparation and output recovery freeze the clock and daily ledger. An empty source selection pauses transport immediately. Re-enabling a layer alone never resumes it. Active background-only listening counts. Muting via volume is not Pause and intentionally preserves the stream timeline.

Pause freezes current and daily time immediately. Resume waits for the graph to run, then continues without catching up the pause. Stop resets the current session only, retaining today's accumulated activity. Same-mode live selection/crossfade retains the session. Switching modes ends the preceding one. Closing the window is not Stop: audio intentionally continues via the menu-bar player.

Silent Meditation remains deliberate practice: no selected layers means its stopwatch/chimes continue. A selected but failed meditation source is not treated as intentional silence. All personalised chime markers are retained; no repeating or terminal timer is introduced. Failed synchronous playback cancels intent and stops the graph. Failed asynchronous preparation or output loss cancels intent after detection; a two-second recovery window and 30-second preparation deadline prevent indefinite ghost sessions. No waiting time is added to either clock. Detection uses the existing 0.25-second heartbeat and status reads; it is not sample-accurate auditory or attention measurement.

## Evidence and limits

Unit tests exercise the policy and no-catch-up arithmetic. A real native app/IPC integration fixture covers pause/resume/stop, empty Focus/Relax, last-source removal, re-enabling without autoplay, background-only playback, rapid controls, silent Meditation/chimes, synchronous missing-file failure, asynchronous missing-bank failure and daily persistence. Fixtures stay muted, use temporary ONDE_HOME directories, and alter only their own copied bundle. These are shared-model/CLI tests, not a claim that every pointer gesture or physical audio-device disconnection was reproduced on the user's Mac.

The older daily-ledger test deliberately used silent Focus. It now performs the same unchanged accounting assertions in silent Meditation, where that behaviour remains supported. The user's historical records are not recalculated or deleted.

Apple references consulted 20 September 2026:
- NSImage template rendering: https://developer.apple.com/documentation/appkit/nsimage/istemplate
- Audio engine running state: https://developer.apple.com/documentation/avfaudio/avaudioengine/isrunning
- Hardware configuration-change notification: https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange
