#!/usr/bin/env python3
"""Original, deterministic, stationary stereo white-noise bed. Rendered audio CC0.

No fade at the circular seam: independent white-noise samples already have the
same distribution there. Transport fade-in/out is applied by Onde during playback.
"""
import array, math, pathlib, random, sys, wave
path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'Assets/white.wav')
if path.exists():
    with wave.open(str(path)) as f:
        assert (f.getnchannels(), f.getsampwidth(), f.getframerate(), f.getnframes()) == (2, 2, 44100, 2646000)
    print('Verified existing white-noise bed.'); sys.exit(0)
path.parent.mkdir(parents=True, exist_ok=True)
rng = random.Random(0x0D3_110)
scale = 0.07 * math.sqrt(3) * 32767 / math.sqrt(0.6**2 + 0.4**2)
with wave.open(str(path), 'wb') as output:
    output.setnchannels(2); output.setsampwidth(2); output.setframerate(44100)
    for _ in range(60):
        block = array.array('h')
        for _ in range(44100):
            common = rng.uniform(-1, 1)
            block.extend(int(scale * (0.6 * common + 0.4 * rng.uniform(-1, 1))) for _ in range(2))
        if sys.byteorder != 'little': block.byteswap()
        output.writeframes(block.tobytes())
print('Generated original 60-second white-noise bed, stereo PCM, RMS approximately 0.07.')
