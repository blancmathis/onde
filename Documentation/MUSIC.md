# Music, generation and evidence

Onde offers different musical identities rather than one supposedly universal focus track. The seven featured pieces use their own authored palettes, motifs and balances. Earlier soundscapes remain available. English titles map to stable IDs in the main README.

## How the music continues

The render engine is not a player looping the twelve-minute preview files. A phrase planner develops authored material over eight-bar questions and answers, common-tone harmony, and slower 64-bar orchestration chapters. Recurrence is intentional: the system is not a claim of mathematically unique music forever. Its working voice counts and audio buffers are bounded.

Acoustic notes are from a pinned, checksum-verified VSCO 2 Community Edition bank: 76 recordings, including soft piano. The arrangement is computed in real time. Electronic tones and vowel-like choir textures are generated locally. Sanctuary's voice layer is synthesized, not sampled from human singers or commercial recordings.

## Switching soundscapes

The next scene is prepared outside the audio callback. Two scenes overlap through a smooth crossfade beginning at a bar boundary; the default duration is 10 seconds, configurable from 2 to 30 seconds. Rhythmic parts hand over rather than competing at full level. Each piece retains its own tempo; this is not DJ beatmatching. Fast selections resolve to the last requested scene. Pausing suspends playback, including an ongoing transition. Switching between Focus pieces does not reset the stopwatch.

Use `generate transition-render` to export a comparison using the production crossfade mixer. Live mixing, previews and WAV exports share the same DSP core.

## What the studies informed

Avoiding intelligible lyrics, controlling information density, preserving musical predictability, and allowing personal choice are design directions—not clinical validation of these specific outputs. The arrangements avoid random beat omissions, abrupt drops and imposed bursts of novelty. No particular key, tempo, bass frequency or vocal vowel is claimed to be scientifically optimal.

Selected research discussed in the historical design notes:

- Preferred music and sustained attention, Kiss and Linnell (2024): https://www.nature.com/articles/s41598-024-60218-z
- Work-oriented background music (2025): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0316047
- Lyrics and cognition (2023): https://journalofcognition.org/articles/10.5334/joc.273
- Groove and syncopation, Witek et al. (2014): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0094446
- Fast modulation and sustained attention (2024, corrected disclosures): https://www.nature.com/articles/s42003-024-07026-3

These studies differ in populations, tasks, comparisons and conflicts of interest. Groove experiments measure musical pleasure/movement, not professional productivity. Vigilance-task benefits are not automatically reading-comprehension benefits. Modulation experiments do not establish a universal frequency rule. **Onde does not currently add a Brain.fm-like modulation protocol to these compositions.**

No controlled listener study has established that any Onde piece outperforms silence, another preferred track or a commercial service. Numerical checks for finite audio, headroom, beat timing and transition continuity are engineering tests, not cognitive-effect measurements. Prefer an enjoyable, comfortable volume and change or disable music that distracts you.

## Sound sources and rights

Code is MIT. The original generated material and VSCO 2 CE recordings use CC0. Personal imports keep their own rights and are not distributed with the project. Optional Kevin MacLeod recordings are separate CC BY assets and are excluded from originals-only public builds. See [third-party notices](../THIRD_PARTY_NOTICES.md).

Bank source: https://github.com/sgossner/VSCO-2-CE

Complete older research remains in [the historical French archive](archive/fr/), with limitations and source links retained.
