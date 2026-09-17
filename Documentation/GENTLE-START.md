# Gentle start

Since 1.9.2, local playback enters gradually rather than arriving at the selected volume.

- **New session or new recorded layer:** eight-second entrance by default.
- **Resume:** up to two seconds, beginning at the current envelope value during rapid pause/resume.
- **Change of generative composition:** the existing bar-boundary crossfade stays in charge. No second start fade is imposed on an already playing scene.
- **Pause / stop:** a short release to silence. There is no delayed restart after pausing during preparation.

Choose **Settings → Sound without interruptions → Gentle start**. The duration is 0–20 seconds; zero disables the intentional fade (a tiny de-click ramp remains). The setting applies to the next start, not to a ramp already in progress.

```sh
onde settings startFadeSeconds 8
onde settings startFadeSeconds 12
onde settings startFadeSeconds 0
onde status
```

This is independent of `fadeSeconds` (recorded-layer gain adjustments), `generate transition` (scene crossfades), master volume, meditation chimes and both time counters. The sound is not filtered or time-stretched. The music, its rhythm and the selected volume stay unchanged.

## Implementation

`PlaybackEnvelope.c` implements a squared S-curve for the entrance. It is monotonic, starts at silence, has flat endpoint slopes and reaches the target without overshoot. With the eight-second default, amplitude reaches about 2.4% at two seconds, 25% at four seconds and 71.2% at six seconds, relative to the user's selected gain. These are amplitude ratios, not perceived-loudness percentages.

The generative mixer advances that envelope from its rendered sample count **only after a prepared scene exists**. Previously its master smoothing could finish while the graph was rendering silence during asynchronous preparation, so the first actual sound arrived at almost full gain.

Recorded layers use the same curve, advanced by `AVAudioPlayer.deviceCurrentTime`; short native volume ramps interpolate the control updates. The control timer runs only during an entrance, release or gain adjustment. Routine UI/CLI adjustments change gain without restarting or bypassing the entrance. Meditation chimes are not routed through this envelope.

The UI and CLI expose the configured duration. Generator `entrance` and `playback.recorded_layers` expose progress for deterministic/native testing. A zero master volume is always retained; the fade never edits preferences to make itself audible.

Standalone composition exports remain unchanged: this is a playback feature, not an extra fade baked into the generated music. Optional external streaming players are not routed through the local audio transport.

## Verification

Unit tests cover the curve, delayed scene preparation, gain edits, pause/resume, crossfades and backward-compatible preference decoding. `Tools/gentle_start_integration_test.py` exercises real native playback with an isolated, muted profile, both generated music and a recorded layer. It also checks persistence and daily accounting.

API references:
- https://developer.apple.com/documentation/avfaudio/avaudioplayer/setvolume(_:fadeduration:)
- https://developer.apple.com/documentation/avfaudio/avaudioplayer/devicecurrenttime

The eight-second duration and curve are design choices, not a measured replica of a third-party implementation or a claim of cognitive efficacy.
