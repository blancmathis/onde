# Agent control contract

1. Invoke `~/.local/bin/onde schema` for the complete JSON command schema.
2. Inspect `status` and `sounds` before modifying a session.
3. Use `--launch` only when opening the application is intended.
4. Treat nonzero exit or `ok:false` as a failure. Inspect `last_error` after
   playback changes; hardware/audio-file failures are also surfaced in the UI.
5. Do not describe the soundscapes as clinically validated.
6. Never send private imports to a repository or external service.

Examples of raw JSON protocol via `onde call '<json>'`:

```json
{"command":"mode","mode":"meditation","play":true,"reset":true}
{"command":"timer.markers","seconds":[600,1200,1800]}
{"command":"sound","id":"aube","enabled":true,"volume":0.35}
{"command":"settings","key":"chimeVolume","value":0.18}
{"command":"ui","page":"settings","show":true}
{"command":"ui","quiet":true}
```

`mode` is idempotent for the current mode: it resumes rather than resets unless
`reset:true`. Changing mode ends the old session and starts elapsed at zero.
`play/pause` control both audio and stopwatch. `silence` only disables the beds;
use `settings chimesEnabled false` to silence chimes too. No automatic stop at
30 minutes. `timer markers` CLI takes minutes unless `--seconds`; raw API always
uses seconds. Marker edits consume past markers without replaying them.

For a read-only state stream use `onde watch`. `events` includes emitted chimes
and their marker_seconds values. The last 100 events are memory-only.

Security: one JSON line per UNIX-socket connection, same-user processes only.
No API token is needed or exposed. This interface confers local file import and
app control, not arbitrary shell execution. Missing IPC doesn't authorize
launch unless `--launch` was explicitly requested.


## Complete Endel sessions

First run `onde endel list` (works even with the app stopped). Choose a known ID,
then `onde endel play <id> --launch`. Use `--meditation` to retain the configured
meditation chimes with a complete Endel recording. Read `onde endel status`.
A queued/opened player is not success: `playback_confirmed` must be true and the
provider-reported duration must be long. `minutes_approx` is publisher metadata,
NOT a measured playback duration. Network errors are reported explicitly.
Do not read, export or manipulate browser/Endel credentials or protected files.
The player remains visible with its controls and advertising intact.
Browser fallback: `onde endel browser <id>`. This does NOT synchronize a timer.

## Original living generator (1.2)

Use `onde generate presets` for default configurations and
`onde generate play focus|relax|meditation --seed 42 --launch` to activate
original realtime synthesis. `generate status` returns a flat JSON result with
`running`, `rendered_seconds`, `scheduled_events`, `output_peak`, `output_rms`,
`configuration`, `active`, and `last_error`.

`generate set KEY VALUE`: density, brightness, movement, space, texture,
pulse, evolution in 0...1; settleMinutes in 0...120 (0 disables simplification).
`generate seed INTEGER` changes future choices without resetting the stopwatch.
`generate defaults` restores synthesis settings only, never chime preferences.
`mix save/load` also stores/restores generator settings. `silence` stops the
living layer without stopping the meditation timer or chimes.

Offline command, app not required:
`onde generate render MODE /absolute/new.wav --minutes 10 --seed 42`
Optional `--seconds` and `--settings '{"density":0.3,"space":0.8}'`.
WAV export does not overwrite. It uses fresh default settings for MODE unless
`--settings` is supplied; it does NOT implicitly read the currently playing mix.
Read `generate status` first when reproducing current settings.
No Endel samples, network, ML weights, or subscription required.

### Living Engine II (Onde 1.3)

`generate status` reports `engine: onde-living-2`, plus `note_events`,
`grain_events`, `bars`, `bpm`, `active_voices`, `harmony_index` and
`arrangement_section`. Existing synthesis controls and commands are unchanged.
The `texture` control changes both organic air and self-generated grains;
`movement` affects oscillator drift and grain intensity. Existing personal
presets retain their numeric values. An old seed does not recreate Engine I's
music after this engine update; keep a prior export when comparing versions.

## Living III profiles (1.4)

`generate profiles` is an offline discovery command. `generate profile ID`
starts `ancrage`, `abysses`, `courant`, `velours`, `rive`, or `immersion`.
Raw API: `generate.profiles` and `generate.profile` with `id`.
It preserves master volume, chimes and saved mixes; choosing a profile replaces
only the active mode's synthesis configuration and selects the living layer.

New controls: `bass`, `warmth`, `stability`, `character` in 0...1, `tempo` in
40...120 BPM. Density does not change the tempo. All controls are persisted
and saved with mixes. `generate render` accepts either mode IDs or profile IDs.
Current API engine identifier: `onde-living-3`. The noise and granular layers
are disabled. See `Documentation/MOTIFS-STABLES-1.4.md` for complete semantics.
