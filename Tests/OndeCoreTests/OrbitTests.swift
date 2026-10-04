import XCTest
import OndeDSP
@testable import OndeCore

/// Orbit is score 14: Gravity's rules in a warmer style, with its own planner. These
/// are signal and catalog checks; none of them measures concentration.
final class OrbitTests: XCTestCase {
    private var profile: SoundProfile { SoundProfile.find("orbite")! }
    private func create(_ config: GenerativeSettings, rate: Double = 8000) throws -> OpaquePointer {
        let p = try XCTUnwrap(onde_dsp_create(rate, 0, config.seed))
        for (i, v) in config.values.enumerated() { onde_dsp_set(p, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(p, Int32(ONDE_GAIN), 1); return p
    }
    private func audio(_ config: GenerativeSettings, seconds: Int, block: Int = 512) throws -> [Float] {
        let p = try create(config); defer { onde_dsp_destroy(p) }
        var output = [Float](), l = [Float](repeating: 0, count: block), r = l
        var remaining = 8000 * seconds
        while remaining > 0 {
            let n = min(remaining, block)
            onde_dsp_render(p, &l, &r, UInt32(n)); output.append(contentsOf: l.prefix(n)); remaining -= n
        }
        return output
    }
    func testOrbitJoinsFocusBesideGravityWithoutChangingTheDefault() throws {
        let p = profile
        XCTAssertEqual(p.title, "Orbit"); XCTAssertEqual(p.mode, .focus)
        XCTAssertEqual(p.configuration.composition, 14); XCTAssertEqual(p.configuration.tempo, 120)
        XCTAssertEqual(p.configuration.orchestra, 0); XCTAssertEqual(p.configuration.vocals, 0)
        XCTAssertEqual(p.configuration.piano, 0)
        XCTAssertGreaterThan(p.configuration.texture, 0)
        _ = try p.configuration.validated()
        XCTAssertTrue(MusicCatalog.allows("orbite", in: .focus))
        XCTAssertFalse(MusicCatalog.allows("orbite", in: .relax))
        XCTAssertFalse(MusicCatalog.allows("orbite", in: .meditation))
        XCTAssertEqual(MusicCatalog.fallback(for: .focus), "gravite")
        XCTAssertEqual(FocusCompositions.ids.firstIndex(of: "orbite"), 8)
        XCTAssertEqual(ListeningDesign.featured.firstIndex(of: "orbite"), 8)
        XCTAssertEqual(MusicArtworkIdentity.catalog["orbite"], .orbit)
        XCTAssertEqual(try JSONDecoder().decode(GenerativeSettings.self, from: JSONEncoder().encode(p.configuration)), p.configuration)
        var c = GenerativeSettings()
        try c.set("composition", 14); XCTAssertEqual(c.composition, 14)
        XCTAssertThrowsError(try c.set("composition", 15))
        XCTAssertThrowsError(try c.set("composition", 13.5))
    }
    func testPlannerIsDeterministicBoundedAndReturnsHome() {
        var fingerprints = Set<UInt64>(), previous = [Int32]()
        for phrase: UInt64 in 0..<160 {
            var a = OndePhrasePlan(), b = OndePhrasePlan()
            XCTAssertEqual(onde_orbit_plan(14, 8114, phrase, 0.38, &a), 1)
            XCTAssertEqual(onde_orbit_plan(14, 8114, phrase, 0.38, &b), 1)
            XCTAssertEqual(a.fingerprint, b.fingerprint); fingerprints.insert(a.fingerprint)
            XCTAssertEqual(a.phrase, phrase); XCTAssertEqual(a.chapter, phrase / 16)
            XCTAssertTrue((0...3).contains(a.variant)); XCTAssertTrue((0...5).contains(a.harmony))
            XCTAssertTrue((0...5).contains(a.section))
            let chord = withUnsafeBytes(of: a.chord) { Array($0.bindMemory(to: Int32.self)) }
            let melody = withUnsafeBytes(of: a.melody) { Array($0.bindMemory(to: Int32.self)) }
            let bass = withUnsafeBytes(of: a.bass) { Array($0.bindMemory(to: Int32.self)) }
            let levels = withUnsafeBytes(of: a.levels) { Array($0.bindMemory(to: Float.self)) }
            // A Dorian over a low A that never moves.
            XCTAssertEqual(chord.sorted(), chord); XCTAssertEqual(chord[0], 57)
            XCTAssertTrue(chord.allSatisfy { [57, 59, 60, 62, 64, 66, 67, 71, 72, 74].contains($0) })
            XCTAssertTrue(melody.allSatisfy { (0...4).contains($0) })
            // The landmarks the score actually sounds never use the low A.
            for index in [0, 1, 3, 4, 5, 7, 8, 9, 11, 12] { XCTAssertGreaterThan(melody[index], 0) }
            // The offbeat bass holds A2; only the last offbeat of bars four and eight moves.
            XCTAssertTrue(bass.allSatisfy { [38, 40, 43, 45].contains($0) })
            XCTAssertEqual(bass.filter { $0 == 45 }.count, 6)
            XCTAssertTrue(levels.allSatisfy { (0.75...1.25).contains($0) })
            if phrase < 4 { XCTAssertEqual(a.harmony, 0) }
            if phrase % 4 != 0 {
                XCTAssertEqual(chord, previous, "Harmony holds for 32 bars")
            } else if !previous.isEmpty {
                XCTAssertGreaterThanOrEqual(Set(previous).intersection(chord).count, 3)
            }
            previous = chord
        }
        XCTAssertGreaterThan(fingerprints.count, 24)
    }
    func testFrozenEvolutionAndBoundaryValidation() {
        var a = OndePhrasePlan(), b = OndePhrasePlan()
        XCTAssertEqual(onde_orbit_plan(14, 7, 0, 0, &a), 1)
        XCTAssertEqual(onde_orbit_plan(14, 7, UInt64.max - 1, 0, &b), 1)
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertEqual(onde_orbit_plan(14, 7, UInt64.max, 0.4, &b), 1)
        for style: Int32 in [0, 1, 7, 8, 12, 13, 15] { XCTAssertEqual(onde_orbit_plan(style, 1, 0, 0.4, &a), 0) }
        XCTAssertEqual(onde_orbit_plan(14, 1, 0, .nan, &a), 0)
        XCTAssertEqual(onde_orbit_plan(14, 1, 0, -1, &a), 0)
        XCTAssertEqual(onde_orbit_plan(14, 1, 0, 2, &a), 0)
        XCTAssertEqual(onde_orbit_plan(14, 1, 0, 0.4, nil), 0)
        // The other grammars refuse this score.
        XCTAssertEqual(onde_gravity_plan(14, 1, 0, 0.4, &a), 0)
        XCTAssertEqual(onde_phrase_plan(14, 1, 0, 0.4, &a), 0)
        XCTAssertEqual(onde_relaxation_plan(14, 1, 0, 0.4, &a), 0)
    }
    func testRendersBoundedAudioOnAFixedGridAtSeveralSampleRates() throws {
        for rate in [8000.0, 22050.0, 44100.0, 48000.0] {
            let p = try create(profile.configuration, rate: rate); defer { onde_dsp_destroy(p) }
            var l = [Float](repeating: 0, count: 1024), r = l
            var peak: Float = 0, jump: Float = 0, previous: Float = 0
            var energy = 0.0
            let blocks = Int(rate * 12 / 1024)
            for _ in 0..<blocks {
                onde_dsp_render(p, &l, &r, 1024)
                for i in l.indices {
                    XCTAssertTrue(l[i].isFinite && r[i].isFinite)
                    peak = max(peak, abs(l[i]), abs(r[i]))
                    jump = max(jump, abs(l[i] - previous)); previous = l[i]
                    energy += Double(l[i] * l[i] + r[i] * r[i])
                }
            }
            XCTAssertGreaterThan(peak, 0.10, "\(rate)"); XCTAssertLessThan(peak, 0.60, "\(rate)")
            XCTAssertLessThan(jump, 0.20, "\(rate)")
            XCTAssertGreaterThan((energy / Double(blocks * 1024 * 2)).squareRoot(), 0.03, "\(rate)")
            XCTAssertEqual(onde_dsp_composition(p), 14)
            XCTAssertEqual(onde_dsp_grain_events(p), 0)
            XCTAssertGreaterThan(onde_dsp_signature_events(p), 80)
            XCTAssertLessThanOrEqual(onde_dsp_max_beat_gap(p) - onde_dsp_min_beat_gap(p), 1)
            XCTAssertEqual(Double(onde_dsp_min_beat_gap(p)), rate / 2, accuracy: 1)
        }
    }
    func testSampleClockIsIndependentOfCallbackSize() throws {
        XCTAssertEqual(try audio(profile.configuration, seconds: 12, block: 127),
                       try audio(profile.configuration, seconds: 12, block: 1024))
    }
    func testEveryBeatCarriesTheSameLowEnd() throws {
        // One oscillator is both kick and sub and restarts on the beat, so the low
        // band repeats exactly. The offbeat bass and the notes are silenced here
        // because their composed pickups legitimately differ between beats.
        var c = profile.configuration; c.drive = 0; c.density = 0
        var x = try audio(c, seconds: 46).map { Double($0) }
        let coefficient = 1 - exp(-2 * Double.pi * 100 / 8000)
        for _ in 0..<4 {
            var state = 0.0
            for i in x.indices { state += coefficient * (x[i] - state); x[i] = state }
        }
        var levels = [Double]()
        for beat in 48..<88 {
            var sum = 0.0
            for i in (beat * 4000)..<((beat + 1) * 4000) { sum += x[i] * x[i] }
            levels.append((sum / 4000).squareRoot())
        }
        let lowest = try XCTUnwrap(levels.min()), highest = try XCTUnwrap(levels.max())
        XCTAssertGreaterThan(lowest, 0.02)
        XCTAssertLessThan(highest / lowest, 1.03)
    }
    func testLiveTempoChangeKeepsTheLowEndOnTheSequencerGrid() throws {
        // Kick and sub restart from the sequencer, the clock that also places the
        // bass line and the notes. After a live tempo change every beat must still
        // begin in the quiet gap between two sustains, not somewhere inside one.
        var c = profile.configuration; c.drive = 0; c.density = 0
        let p = try create(c); defer { onde_dsp_destroy(p) }
        var l = [Float](repeating: 0, count: 1000), r = l
        for _ in 0..<80 { onde_dsp_render(p, &l, &r, 1000) }
        onde_dsp_set(p, Int32(ONDE_TEMPO), 80)
        for _ in 0..<96 { onde_dsp_render(p, &l, &r, 1000) }
        var remaining = Int(onde_dsp_frames_to_bar(p))
        while remaining > 0 {
            let n = min(remaining, 1000)
            onde_dsp_render(p, &l, &r, UInt32(n)); remaining -= n
        }
        XCTAssertEqual(onde_dsp_bpm(p), 80, accuracy: 0.001)
        // At 80 BPM and 8 kHz one beat is exactly 6,000 frames.
        let coefficient = 1 - exp(-2 * Double.pi * 100 / 8000)
        var state = [Double](repeating: 0, count: 4)
        var edge = 0.0, body = 0.0
        for _ in 0..<16 {
            var first = 0.0, energy = 0.0
            for block in 0..<6 {
                onde_dsp_render(p, &l, &r, 1000)
                for i in 0..<1000 {
                    var y = Double(l[i])
                    for k in 0..<4 { state[k] += coefficient * (y - state[k]); y = state[k] }
                    if block == 0 && i < 8 { first += abs(y) }
                    energy += y * y
                }
            }
            edge += first / 8; body += (energy / 6000).squareRoot()
        }
        XCTAssertGreaterThan(body, 0.2)
        XCTAssertLessThan(edge / body, 0.3)
    }
    func testFastPulseCanBeRemovedWithoutChangingClockOrScore() throws {
        var clocks: [UInt64] = [], scores: [UInt64] = [], recordings: [[Float]] = []
        for texture in [0.0, profile.configuration.texture] {
            var c = profile.configuration; c.texture = texture
            let p = try create(c); defer { onde_dsp_destroy(p) }
            var l = [Float](repeating: 0, count: 1000), r = l, all = [Float]()
            for _ in 0..<160 { onde_dsp_render(p, &l, &r, 1000); all.append(contentsOf: l) }
            clocks.append(onde_dsp_beats(p)); scores.append(onde_dsp_signature_events(p)); recordings.append(all)
        }
        XCTAssertGreaterThan(profile.configuration.texture, 0)
        XCTAssertEqual(clocks[0], clocks[1]); XCTAssertEqual(scores[0], scores[1])
        XCTAssertNotEqual(recordings[0], recordings[1])
        // The tremolo enters after bar four (64,000 frames here); until then both are identical.
        XCTAssertEqual(Array(recordings[0].prefix(60_000)), Array(recordings[1].prefix(60_000)))
    }
    func testZeroDensityKeepsBassAndChordsWithoutNotes() throws {
        var c = profile.configuration; c.density = 0
        let p = try create(c); defer { onde_dsp_destroy(p) }
        var l = [Float](repeating: 0, count: 1000), r = l
        var energy = 0.0
        for _ in 0..<400 {
            onde_dsp_render(p, &l, &r, 1000)
            for x in l { energy += Double(x) * Double(x) }
        }
        XCTAssertEqual(onde_dsp_note_events(p), 0)
        XCTAssertGreaterThan((energy / 400_000).squareRoot(), 0.03)
    }
    private func core(_ id: String, rate: Double = 22050) throws -> OpaquePointer {
        let p = try XCTUnwrap(SoundProfile.find(id))
        let core = try XCTUnwrap(onde_dsp_create(rate, 0, p.configuration.seed))
        for (i, v) in p.configuration.values.enumerated() { onde_dsp_set(core, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1); return core
    }
    private func advance(_ mixer: OpaquePointer, seconds: Double, rate: Double = 22050) -> (Float, Float) {
        var left = [Float](repeating: 0, count: 511), right = left
        var remaining = Int(seconds * rate); var peak: Float = 0, jump: Float = 0, previous: Float = 0
        while remaining > 0 {
            let n = min(remaining, left.count)
            onde_scene_mixer_render(mixer, &left, &right, UInt32(n))
            for i in 0..<n {
                XCTAssertTrue(left[i].isFinite && right[i].isFinite)
                peak = max(peak, abs(left[i]), abs(right[i]))
                jump = max(jump, abs(left[i] - previous)); previous = left[i]
            }
            onde_scene_mixer_collect(mixer); remaining -= n
        }
        return (peak, jump)
    }
    func testSceneHandoverToAndFromOrbitIsBounded() throws {
        let mixer = try XCTUnwrap(onde_scene_mixer_create(22050)); defer { onde_scene_mixer_destroy(mixer) }
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("sillage"), 4), 1)
        onde_scene_mixer_gain(mixer, 1)
        _ = advance(mixer, seconds: 6)
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("orbite"), 4), 1)
        let arrival = advance(mixer, seconds: 10)
        XCTAssertGreaterThan(arrival.0, 0.015); XCTAssertLessThanOrEqual(arrival.0, 0.951)
        XCTAssertLessThan(arrival.1, 0.25)
        XCTAssertEqual(onde_scene_mixer_state(mixer), 0)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(mixer)), 14)
        XCTAssertEqual(onde_scene_mixer_submit(mixer, try core("meridien"), 4), 1)
        let departure = advance(mixer, seconds: 10)
        XCTAssertGreaterThan(departure.0, 0.015); XCTAssertLessThanOrEqual(departure.0, 0.951)
        XCTAssertLessThan(departure.1, 0.25)
        XCTAssertEqual(onde_scene_mixer_state(mixer), 0)
        XCTAssertEqual(onde_dsp_composition(onde_scene_mixer_visible(mixer)), 7)
    }
}
