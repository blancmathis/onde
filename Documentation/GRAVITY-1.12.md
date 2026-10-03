# Gravity — Onde 1.12

One new Focus piece: **Gravity** (`gravite`, score 13). A soft four-on-the-floor
kick and a sustained sub share one deep pulse at 120 BPM; an offbeat bass, a slow
chord layer and a few quiet notes sit above it. It is written for listeners who
work better with a strong low end.

It follows the seven featured Focus pieces in the list and is the Focus default
for new installations, replacing Slipstream. A Focus default you have already
saved is kept: choose Gravity with its star, or run
`onde music default focus gravite`. Saved mixes, the other 25 pieces,
backgrounds, chimes and timers are unchanged.

## What the evidence does and does not support

This is an evidence-informed composition, not a clinical trial. No paper
establishes that this piece is optimal, better than silence or helpful for every
listener or task. The studies below informed production choices. Several were
funded by, or written with, companies that sell focus music; that is noted where
it applies.

### Preference comes first

**Kiss and Linnell, 2024** ran two home experiments (N=106 and N=77) using a
vigilance task. Preferred background music reduced mind-wandering, increased
task-focus and shortened reaction times compared with quiet or office noise.
Mood and arousal statistically mediated the effect. The task was simple and the
samples were mostly young students; it says nothing about reading or reasoning.

Source: *The role of mood and arousal in the effect of background music on
attentional state and performance during a sustained attention task*,
Scientific Reports. https://doi.org/10.1038/s41598-024-60218-z

**Implementation:** Gravity is one more identity to choose from, for people who
like bass. It is the starting choice for new installations, as a choice made by
the maintainer, not because it has been shown to be superior to the others.

### A clear pulse, carried by the low register

**Orpella et al., 2025** assigned 196 online participants to one of four ten-minute
backgrounds during a flanker task. A "work flow" style, described as strong
rhythm with high pulse clarity, moderately fast tempo, simple tonality, energy
mostly below about 6 kHz and moderate dynamics, improved mood (d = 0.83–1.01)
and sped responses over time. A minimal "deep focus" style did not. There was no
silent condition, accuracy did not differ, and three of the four authors report
ties to the company that supplied the work-flow tracks.

Source: *Effects of music advertised to support focus on mood and processing
speed*, PLOS ONE. https://doi.org/10.1371/journal.pone.0316047

**Lenc et al., 2018** recorded EEG while people listened to the same rhythms
played with low (130 Hz) or high (1237 Hz) tones. Brain activity at the beat
frequency was selectively larger for the low tones. The study measured neural
tracking of a rhythm, not performance on another task.

Source: *Neural tracking of the musical beat is enhanced by low-frequency
sounds*, PNAS. https://doi.org/10.1073/pnas.1801421115

**Implementation:** a steady 2 Hz pulse in the bass register, one tonal centre,
no fills, drops, breaks or random omissions, and almost no energy above 3 kHz.
The tempo and the key are artistic choices; no study names an optimal value.

### Fast modulation: one supportive study, with caveats

**Woods et al., 2024** tested music with added amplitude modulation in four
experiments using a sustained-attention task (behavioural N=83 and N=175, fMRI
N=34, EEG N=40). The music ran at 120 BPM; modulation at 8, 16 or 32 Hz was
aligned to the metrical grid and confined to 200 Hz–1 kHz. Listeners with more
ADHD symptoms did better over time with the 16 Hz rate than with the others.
Effects for listeners with few symptoms were not shown separately, blocks lasted
about five minutes, and the work is linked to a company that sells such music;
author corrections were published in 2025 and 2026.

Source: *Rapid modulation in music supports attention in listeners with
attentional difficulties*, Communications Biology.
https://doi.org/10.1038/s42003-024-07026-3

**Implementation:** Gravity's chord layer, and only that layer, carries a
tremolo of a whole number of cycles per beat: 16 Hz at 120 BPM, and the nearest
value to 16 Hz at any other tempo (13–19 Hz across the tempo range). The bass,
kick and notes are not modulated. It is an ordinary synthesizer tremolo on one
voice of an original piece, set by the **Fast pulse** control (`texture`); zero
removes it and leaves everything else identical. Onde makes no attention claim
for it. It is the only place in Onde where a fast modulation is used.

### Words, binaural beats and noise

Music with lyrics interfered with cognitive tasks in **Souza and Barbosa, 2023**
(https://journalofcognition.org/articles/10.5334/joc.273). Gravity has no voice
of any kind.

**Ingendoh et al., 2023** reviewed fourteen EEG studies of binaural beats: five
supported brainwave entrainment, eight contradicted it and one was mixed
(https://doi.org/10.1371/journal.pone.0286023). Gravity uses none. Its chord
voices are detuned by about a cent for width, as in any stereo synthesizer.

A meta-analysis of white and pink noise, **Nigg et al., 2024**, found a small
benefit on laboratory tasks for youth with ADHD or elevated attention problems
(g = 0.25) and a small cost for comparison participants without them
(g = −0.21) (https://doi.org/10.1016/j.jaac.2023.12.014). Gravity adds no noise
layer. The optional backgrounds remain a separate, personal choice.

### Generative soundscapes

**Haruvi et al., 2022** compared a commercial generative soundscape, two
streaming playlists and silence in 51 people at home, estimating focus from a
four-channel EEG headband. The soundscape differed from silence (p = 0.008); the
playlists did not. The study was funded by the soundscape's maker and the EEG
vendor and did not report which acoustic properties mattered.

Source: Frontiers in Computational Neuroscience.
https://doi.org/10.3389/fncom.2021.760561

**Implementation:** none taken from it. It is listed because it is often cited
for this kind of music and does not show that bass, in particular, helps.

## The score

Tempo 120 BPM, tonal centre F, a fixed six-note set (F G A♭ B♭ C E♭) with no
leading tone. Five layers:

1. **Kick and sub.** One oscillator is restarted by the sequencer on every beat,
   the same clock that places the bass line and the notes. Its pitch falls from
   about 130 Hz to the F1 pedal (43.65 Hz) in the first 80 ms, which is the kick;
   it then sustains with three added harmonics, which is the sub. Because both
   are the same oscillator, every beat has the same phase and level.
2. **Offbeat bass.** F2 on every offbeat, with pickups into beats three and one.
   Six harmonics, the upper ones fading first, so the line survives on speakers
   that cannot reproduce 44 Hz. Only the last pickup of bars four and eight
   leaves F, for one sixteenth.
3. **Chords.** Five sustained voices, two oscillators each. Common tones are
   held across changes; only the voices that change crossfade. The layer ducks
   under each kick and carries the optional tremolo.
4. **Notes.** Seven soft, slow-attack notes in eight bars at fixed positions,
   followed by an open bar; three quieter ones are added when Notes is above
   60%. They begin after sixteen seconds.
5. **Backbeat.** A very quiet wooden tick on beats two and four, from bar
   seventeen.

Phrases last eight bars. The upper harmony changes every 32 bars (64 seconds)
and every second harmony is the home chord. Chapters last 128 bars (about four
minutes) and tilt the balance of the layers by up to about 15%; no layer is ever
removed. Layers arrive during the first bars and then stay.

## Controls

| Control | In Gravity |
|---|---|
| Bass | Level of kick, sub and offbeat bass together |
| Impact (`punch`) | Kick level and how far the chords duck under it |
| Drive | Level of the offbeat bass; zero removes it |
| Pulse | How slowly the sub returns after each kick |
| Notes (`density`) | Level of the notes and the backbeat; zero removes both, above 60% adds three |
| Fast pulse (`texture`) | Depth of the tremolo on the chords; zero removes it |
| Brightness, Warmth | Harmonic content of chords and bass; overall tone |
| Movement, Space | Slow colour drift; stereo width, echo and reverb |
| Evolution | Zero freezes harmony and theme |
| Tempo | 40–120 BPM; the tremolo stays on the grid and near 16 Hz |

## Measurements

Twelve minutes at the default settings, 44.1 kHz. These are engineering checks
of the signal, not measurements of attention.

- Integrated loudness −21.0 LUFS; short-term loudness stays within 0.4 LU after
  the entrance. Sample peak −9.8 dBFS. The safety ceiling is never reached.
- A-weighted level about equal to Meridian (within 1 dB); unweighted level
  about 2 dB higher. The difference is low-frequency energy.
- Energy by band, relative to the total: 20–45 Hz −3.9 dB, 45–90 Hz −3.3 dB,
  90–180 Hz −10.2 dB, 180–355 Hz −17.0 dB, 355–710 Hz −19.4 dB, 710–1400 Hz
  −28.7 dB, 1.4–2.8 kHz −44.2 dB. 99% of the energy is below 400 Hz.
- Below 150 Hz the output is effectively mono (inter-channel correlation 1.00).
  Between 200 Hz and 2 kHz the side signal is about 4 dB below the mid signal.
- With the offbeat bass and notes switched off, the low-band level of individual
  beats differs by a factor of 1.002 at most. The same measurement gives 1.5–1.7
  for Slipstream, Meridian and Reactor, whose kick and free-running sub drift
  against each other.
- Envelope modulation of the 200 Hz–1 kHz band at 16 Hz: index about 0.25 by
  default, 0.05 with Fast pulse at zero, about 0.5 at its maximum.
- After a live tempo change the kick, sub, bass line and notes stay on one grid.
- No clicks were found in live tempo, control and scene changes: the residual
  above 6 kHz stays below −80 dBFS.
- No noise layer, sample or voice is used; the app does not load the acoustic
  bank for this piece.

## CLI

```sh
~/.local/bin/onde music play gravite --launch
~/.local/bin/onde music default focus gravite
~/.local/bin/onde generate set texture 0
~/.local/bin/onde generate set bass 1
~/.local/bin/onde generate set tempo 108
~/.local/bin/onde generate render gravite "$HOME/Desktop/Gravity.wav" --minutes 60
```

The default command is an explicit preference; simply listening does not run it.

## Verification and limits

The change adds planner, audio, block-size, sample-rate, live-tempo and
scene-handover tests.
All 25 earlier profiles were rendered with the DSP before and after the change,
at 8, 44.1 and 48 kHz with identical inputs and without the acoustic bank: every
file was bit-identical. The new code was also run under address and
undefined-behaviour sanitizers, including live score changes.

None of this shows that Gravity improves concentration. A fair test compares it
with the listener's usual choice and with silence, on real work, at matched
perceived loudness, across several days. Keep the volume moderate: a loud low
end is tiring, and louder is not more effective. If the tremolo or the kick
draws attention to itself, turn it down or choose another piece.
