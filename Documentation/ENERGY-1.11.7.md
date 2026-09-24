# Onde 1.11.7 — bounded native artwork rendering

The live artwork now redraws an isolated, layer-backed native surface hosting
only the Canvas. Its natural 12/24 Hz clock publishes a local frame dependency,
not a dependency of the listening hierarchy. Apple's accelerated Canvas and
its original gradient remain in use; the existing Intel virtual-GPU fallback
is preserved. A software-only prototype was rejected because its lower CPU
cost was not reproducible with every animation actually running. Contours,
line budgets, identities, music, volume, timing and visual-motion preferences
are preserved. Rendering builds four paths directly, without intermediate
arrays of 3,616 points per balanced frame.

The frame receiver is weak and ownership-scoped. An old detached view cannot
clear a new receiver. Transitions use the suspended artwork clock rather than
wall time, so pausing mid-blend freezes pixels. Window hiding, minimization,
occlusion, sheets and reduced-motion still suspend the decorative timer.

Read-only diagnostics distinguish requested FPS/time from actual draws,
drawn identity, drawn time and surface size. Performance measurements must
reject intervals where the supposed visible animation stopped or was covered.

The native CI fixture checks 375 exact contour comparisons, frame ownership,
25 naturally moving rendered surfaces, pause during a transition, selecting
while paused, pixel stability and actual window/setting lifecycle. Existing
audio and installation suites remain unchanged and required.

No files are automatically re-imported or deleted. The three unreferenced MP3
files found in the existing user's profile remain untouched; their absence
from the catalog predates 1.11.5.
