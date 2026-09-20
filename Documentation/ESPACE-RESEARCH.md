# Espace — design research and trade-offs

Public primary sources checked on 19 September 2026. This is a design review, not a controlled usability study or an audit of every paid competitor screen.

## Competitive reference

Endel's own product presentation emphasises generative visuals for its soundscapes, an adaptive Autoplay feature, and a discreet desktop interface [1]. The useful lesson for Onde is a recognisable listening identity without making the image a task. Espace keeps a single optional surface rather than a grid of continuously moving previews. It does not imitate Endel's visual assets or claim its physiological adaptation.

Brain.fm's own presentation emphasises task-specific modes, one-click access without searching, and several timer models [2]. The relevant lesson is a low-friction entrance. Espace preserves an explicit one-click Start-default action, while keeping catalogue browsing separate from audio. Onde's count-up timer and indefinite meditation remain intentional product constraints; extra countdowns were not added to copy a competitor.

These sources describe what each company promotes. They do not establish how an unobserved current screen behaves, which app is faster, or which design users prefer.

## Decisions and costs

| Decision | Benefit sought | Deliberate cost |
|---|---|---|
| Separate browsing and playback | Inspect another intention without interrupting a session | A mode tab alone no longer starts audio; explicit Start remains nearby |
| Stable rows, default in its own card | Changing a default does not shift the list under the pointer | The starred sound is not always the first row |
| Settings on demand | Listening remains visually primary | Tone changes take one extra action from the home screen |
| Static music covers | Recognition without continuous peripheral motion | Less visual spectacle in the catalogue |
| Optional single artwork | A visible identity while retaining a completely plain alternative | An additional appearance toggle |
| Quiet view without artwork | A dedicated, genuinely reduced screen | The animated identity is intentionally absent there |
| Six cover families, system typography | Consistent recognition and small source-only footprint | Not a unique illustrated painting for every track |

## Motion and rendering

W3C's explanation of animation from interactions supports disabling non-essential motion and respecting motion preferences [3]. Espace applies the same principle to its native SwiftUI interface: a system-plus-app reduction policy and an independent decorative pause. W3C is used as a design criterion, not claimed as a full native-app conformance assessment.

Apple's SwiftUI performance session stresses identifying a problem, measuring it, making changes and measuring again, as well as understanding view dependencies and identity [4]. Espace narrows the clock's observer subtree, keeps static cover IDs stable and caps work. Actual GPU, hitches, energy and prolonged playback measurements are still required; geometry counts are not a substitute.

The palette's computed foreground/background ratios are checked separately against W3C's contrast guidance [5]. Such a token-level check does not measure every rendered native state, system control, thin stroke or disabled label, and is not a blanket accessibility claim.

## A test that could establish superiority

Use the same Mac, tasks and audio conditions. Counterbalance the order of Onde, Endel and Brain.fm. Measure completion and unintended audio interruptions for starting an existing favourite, browsing another mode, changing a background, pausing/resuming, setting a default and entering an uncluttered listening state. Record errors and confidence, then collect preference ratings separately from speed. Include keyboard and reduced-motion users. Do not equate a pleasing screen, retention, time spent in the app, or the music's claimed science with better task usability.

## Primary sources

1. Endel, official product presentation: https://endel.io/
2. Brain.fm, official product presentation: https://www.brain.fm/
3. W3C, Understanding SC 2.3.3, Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html
4. Apple, WWDC23, Demystify SwiftUI performance: https://developer.apple.com/videos/play/wwdc2023/10160/
5. W3C, Understanding SC 1.4.3, Contrast (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
