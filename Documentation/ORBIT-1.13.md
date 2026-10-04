# Orbit — Onde 1.13

**Orbit** (`orbite`, score 14) is the warm sibling of Gravity. It keeps every
production rule Gravity was built on and changes only the style: deep house and
dub in A Dorian, where Gravity is dark, minimal techno in F minor.

It follows Gravity in the Focus list. Gravity stays the Focus default for new
installations; a default you have already saved is kept. Saved mixes, the other
26 pieces, backgrounds, chimes and timers are unchanged.

The studies behind these rules, with their sample sizes, conflicts of interest
and limits, are in [the Gravity guide](GRAVITY-1.12.md#what-the-evidence-does-and-does-not-support).
None of them shows that either piece improves concentration.

## Same rules, different style

| Rule | Gravity | Orbit |
|---|---|---|
| The pulse lives in the bass | Kick and sub on F1 (43.7 Hz) | Kick and sub on A1 (55 Hz) |
| Every beat has the same low end | One oscillator restarted by the sequencer | Same mechanism, a rounder and shorter kick |
| Nothing sudden | Harmony every 32 bars, home every second change | Same |
| Clear pulse, simple key, few highs | 120 BPM, F minor, no leading tone | 120 BPM, A Dorian, no leading tone |
| 16 Hz tremolo on the middle layer only | Sustained chords | Organ-like chords |
| Sparse melody, no voice | 7 soft mallet notes per 8 bars | 7 soft electric-piano notes per 8 bars, with dub echo |
| Offbeat bass audible on small speakers | F2 with pickups, six bright harmonics | A2 eighth notes, six rounder harmonics |
| No binaural beats, no noise layer | Yes | Yes |

What you hear differently:

- **Key and colour.** A Dorian has a raised sixth (F♯) that sounds open and warm
  rather than dark. The chords sit a third higher, between A3 and D5.
- **Groove.** The bass plays a plain eighth note on every offbeat, the classic
  house figure, instead of Gravity's pickups. Only the last offbeat of bars four
  and eight steps down to G, E or D.
- **Pump.** The chords duck further under each kick and come back more slowly,
  so the whole pad breathes with the beat.
- **Keys and echo.** The seven notes per eight bars are a soft electric piano
  that feeds the beat-synchronous echo (one beat and one and a half beats), so
  each note repeats quietly in time. Calls fall on beat two, answers on the
  "and" of beat three; the last bar stays open.
- **Tick.** A soft pitched tick on beats two and four from bar seventeen, in
  place of Gravity's wooden one.

## Controls

The same controls as Gravity, with the same meaning: Bass, Impact, Drive, Pulse,
Notes, Fast pulse (`texture`, zero removes the tremolo), Brightness, Warmth,
Movement, Space, Evolution and Tempo. Space starts higher (0.55) for the echo.

## Measurements

Twelve minutes at the default settings, 44.1 kHz. Engineering checks of the
signal, not measurements of attention.

- Integrated loudness −21.2 LUFS; short-term loudness stays within 0.5 LU after
  the entrance. Sample peak −10.5 dBFS.
- A-weighted level within 0.5 dB of Gravity and of Meridian.
- Energy by band, relative to the total: 45–90 Hz −1.6 dB, 90–180 Hz −6.1 dB,
  180–355 Hz −13.5 dB, 355–710 Hz −18.4 dB, 710–1400 Hz −28.0 dB,
  1.4–2.8 kHz −49.2 dB. 99% of the energy is below 440 Hz.
- With the offbeat bass and notes switched off, the low-band level of individual
  beats differs by a factor of 1.002 at most.
- Envelope modulation of the 200 Hz–1 kHz band at 16 Hz: index about 0.23 by
  default, 0.04 with Fast pulse at zero, about 0.5 at its maximum.
- After a live tempo change the kick, sub, bass line and notes stay on one grid.
  No clicks in live tempo, control and scene changes (residual above 6 kHz below
  −80 dBFS).
- No noise layer, sample or voice; the acoustic bank is not loaded.

## CLI

```sh
~/.local/bin/onde music play orbite --launch
~/.local/bin/onde music default focus orbite
~/.local/bin/onde generate set texture 0
~/.local/bin/onde generate render orbite "$HOME/Desktop/Orbit.wav" --minutes 60
```

## Verification and limits

Orbit has its own planner (`onde_orbit_plan`) and score, and shares no code
with Gravity's synthesis: Gravity and the 25 earlier profiles render
bit-identically before and after this change (8, 44.1 and 48 kHz, without the
acoustic bank). The change adds planner, audio, block-size, sample-rate,
live-tempo and scene-handover tests, and the new code was run under address and
undefined-behaviour sanitizers.

No listening study has compared Orbit with silence, with Gravity or with your
usual music. Choose the one you prefer: preference is the factor the evidence
supports best. Keep the volume moderate.
