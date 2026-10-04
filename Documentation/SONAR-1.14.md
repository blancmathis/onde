# Sonar — Onde 1.14

**Sonar** (`sonar`, score 15) is the third bass-led Focus piece. It keeps every
production rule of Gravity and Orbit and moves to a stripped-back, minimal
deep-techno style: a filtered bass line whose tone changes slowly while its
notes stay the same, a dark open drone, distant pings and very little else.

It follows Orbit in the Focus list. Gravity stays the Focus default for new
installations; a default you have already saved is kept. Saved mixes, the other
27 pieces, backgrounds, chimes and timers are unchanged.

The studies behind the rules, with their sample sizes, conflicts of interest and
limits, are in [the Gravity guide](GRAVITY-1.12.md#what-the-evidence-does-and-does-not-support).
None of them shows that any of these pieces improves concentration.

## Same rules, third style

| Rule | Gravity | Orbit | Sonar |
|---|---|---|---|
| Pulse in the bass | F1, 43.7 Hz | A1, 55 Hz | G1, 49 Hz |
| Same low end on every beat | One oscillator restarted by the sequencer | Same | Same, tighter kick |
| Nothing sudden | Harmony every 32 bars, home every second change | Same | Same |
| Clear pulse, simple key, few highs | 120 BPM, F minor | 120 BPM, A Dorian | 120 BPM, G Aeolian, the fewest highs of the three |
| 16 Hz tremolo on the middle layer only | Sustained chords | Organ-like chords | Dark open drone |
| Sparse melody, no voice | 7 mallet notes per 8 bars | 7 electric-piano notes | 7 glassy pings with echo |
| Offbeat bass with harmonics | F2 with pickups | A2 eighth notes | Filtered riff that never lands on the beat |
| No binaural beats, no noise layer | Yes | Yes | Yes |

## What makes it different

- **The bass line changes its tone, not its notes.** A bright waveform passes
  through a resonant low-pass filter. The filter opens briefly on each note,
  more on accents, and its centre drifts over about five minutes: in a typical
  render, the share of the line above 400 Hz moves between about −15 dB and
  −4 dB. The riff itself repeats every bar; only the last sixteenth of bars four
  and eight changes. Brightness raises the filter, Movement deepens the drift.
- **Stripped back.** Fewer elements than Gravity and Orbit, a drier room
  (Space 0.35) and a lighter pump: the drone only leans away from the kick.
- **Open harmony.** The chords are stacked fourths and fifths in G Aeolian,
  closer to a drone than to a progression.
- **Pings and ticks.** Seven glassy pings per eight bars feed the
  beat-synchronous echo; very soft pitched ticks mark every offbeat from bar
  seventeen. Neither uses noise.
- **Tempo.** Fixed at 120 BPM, like the other two. Onde does not read heart rate
  or any other body signal; the Tempo control is the only way to change it.

## Measurements

Twelve minutes at the default settings, 44.1 kHz. Engineering checks of the
signal, not measurements of attention.

- Integrated loudness −21.0 LUFS, the same as Gravity; short-term loudness stays
  within 1 LU after the entrance.
- The least high-frequency energy of the three pieces (1.4–2.8 kHz −51 dB
  relative to the total, against −44 dB for Gravity and −49 dB for Orbit).
- With the bass line and pings switched off, the low-band level of individual
  beats differs by a factor of 1.003 at most.
- Envelope modulation of the 200 Hz–1 kHz band at 16 Hz: index about 0.26 by
  default, 0.02 with Fast pulse at zero. Fast pulse starts at 0.70 instead of
  0.55, because the bass line shares that band and would otherwise dilute it.
- After a live tempo change the kick, sub, bass line and pings stay on one grid,
  and even an abrupt jump from 48 to 120 BPM leaves the residual above 6 kHz
  below −84 dBFS.
- No noise layer, sample or voice; the acoustic bank is not loaded.

## CLI

```sh
~/.local/bin/onde music play sonar --launch
~/.local/bin/onde music default focus sonar
~/.local/bin/onde generate set brightness 0.6
~/.local/bin/onde generate set texture 0
~/.local/bin/onde generate render sonar "$HOME/Desktop/Sonar.wav" --minutes 60
```

## Verification and limits

Sonar has its own planner (`onde_sonar_plan`) and score. It reuses the shared
state of the bass-led pieces but none of their synthesis code: Gravity, Orbit
and the 25 earlier profiles render bit-identically before and after this change.
The change adds planner, audio, block-size, sample-rate, live-tempo and
scene-handover tests, and the new code was run under address and
undefined-behaviour sanitizers.

No listening study has compared Sonar with silence, with the other two pieces or
with your usual music. Choose the one you prefer, at a moderate volume.
