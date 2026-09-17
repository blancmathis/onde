# Listening in Onde 1.10

## One screen, three intentions

The main window is the music picker and the player. There is no separate Studio,
Library or Living Soundscapes destination. Focus shows its 17 compositions (the
seven featured pieces first); Relax and Meditation share the same three relaxing
pieces: Velvet, Shore and Immersion.

Click **Focus**, **Relax** or **Meditation** to start that mode's default. Each mode
shows its current default underneath its name. Click a music card to choose
something just for now. Click its **star** to make it the default for this mode,
without starting it or interrupting the current music. Trying another card does
not change the default. Settings also offers all three default pickers together.

Relax and Meditation have independent defaults and backgrounds. Choosing a piece
while meditating never switches to Relax or resets the practice timer. The same
piece uses its authored audio palette in both modes; meditation adds session
chimes. Switching between modes ends the previous session and starts that mode's
stopwatch; selecting music within a mode preserves it. Pauses remain excluded
from Today.

## The controls you actually need

The right-hand panel stays visible beside the music:

- **Music** changes its level without changing background or master volume.
- **Background sound** chooses Off, White noise, Pink noise, Brown noise, Rain or
  Ocean. **Amount** adjusts that background. Only one is enabled by this picker;
  changing music preserves it. The choice and amount are remembered per mode.
- **Gentle start** controls the entrance from silence (0–20 seconds).
- **Between music** controls the live crossfade (2–30 seconds).

The master volume in the bottom player affects the whole output, including
chimes. Adding noise does not restart the music. Editing a background while
paused never starts playback. Zero background volume keeps the chosen color but
is silent; Off removes the background and leaves the music running. Mixture
headroom is still managed by the audio engine.

**Adjust this music** opens optional tone controls. Bass, note density, warmth,
space and relevant voice/piano levels come first. Rhythm, instrument balance,
seed and WAV export are tucked into disclosures. Tuning is remembered for each
music within each mode. **Reset sound** restores that piece, not another genre,
and does not touch mode defaults, background, master volume or chimes.

## Playback remains explicit

Selecting any card after a pause starts only the selected piece from the
beginning, with its gentle entrance. A paused old scene is discarded before
sound returns. Selecting music while it is playing keeps the live crossfade.
The ordinary Play button resumes the existing position. Closing settings does
not stop the session. Closing the main window leaves the menu-bar player active.

For meditation, the current chime times are summarized on the main screen.
Settings edits the times, enables/disables chimes and controls their level. By
default the chimes occur at 10, 20 and 30 minutes, then stop while the stopwatch
and music continue. Existing personal chime settings are preserved.

## Optional tools, without extra navigation

The gear opens Settings. The more-options menu holds personal audio/mixes,
session history, Agent & CLI, updates, and credits. These are dismissible sheets,
not top-level pages. Existing audio imports and saved mixes remain available;
legacy recorded music is tucked into Personal audio & mixes. Nothing is deleted
from the user's library by this migration.

The interface stays English. Existing CLI IDs, original scores and source audio
are unchanged. White noise is an additional original CC0 recording generated
locally by `Tools/white_noise.py`; the label does not stand in for pink or brown
noise. It has no cognitive or therapeutic guarantee.

## CLI

```sh
onde music list focus
onde music list relax
onde music list meditation
onde music defaults
onde music default focus ambre
onde music default relax rive
onde music default meditation immersion
onde focus --launch
onde music play sillage
onde music play velours --mode meditation
onde music play rive --mode meditation --no-play
onde music volume 0.65
onde background white 0.15
onde background brown 0.10
onde background off
onde generate transition 10
onde settings startFadeSeconds 8
```

`music list` works offline. Commands return JSON. `status.result.listening`
reports the selected ID, default IDs, catalog, music/background levels and sheet.
The raw API also supports `music.list`, `music.select`, `music.defaults`,
`music.default`, `music.volume` and `background`; discover the schema with
`onde schema`. Specifying an incompatible mode/music pair fails without playing.

The original `generate profile`, `generate play`, mixing, import and export
commands remain compatible. These lower-level commands can explicitly choose
profiles outside the streamlined UI flow. Legacy `ui page studio` and
`ui page generative` both show the listening screen; `ui page library` and
`ui page mixes` open optional personal tools. Other old page routes open the
corresponding sheet.

## Migration and tests

A new optional `StoredState.listening` stores mode defaults, background choices,
music levels and per-piece tuning. A suitable existing generated selection seeds
the initial default; otherwise the defaults are Slipstream, Velvet and Immersion.
Existing layers, personal imports, mixes, history and preferences are not rewritten.
A brand-new install is ready on Slipstream with no background and no autoplay.

Run `swift test -c release -j 2`, `Tools/check_english.py`, and
`python3 Tools/listening_integration_test.py dist/Onde.app`.
The native test covers category boundaries, migration, independent defaults,
noise mixing, paused selection, tuning persistence, meditation timer continuity,
CLI aliases, restart and the daily ledger, using a private muted profile.
