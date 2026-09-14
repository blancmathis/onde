import XCTest
import OndeDSP
@testable import OndeCore
final class FocusCompositionTests: XCTestCase {
    func testFourAuthoredIdentitiesNotFourSeeds() throws {
        XCTAssertEqual(FocusCompositions.profiles.map(\.id), ["sillage", "filigrane", "confluence", "sanctuaire"])
        XCTAssertEqual(Set(FocusCompositions.profiles.map { $0.configuration.composition }).count, 4)
        for p in FocusCompositions.profiles { _ = try p.configuration.validated(); XCTAssertEqual(p.mode, .focus) }
    }
    func testLegacySettingsStayOnOriginalScore() throws {
        var o = jsonObject(GenerativeSettings()) as! [String: Any]
        for k in ["composition", "vocals", "piano"] { o.removeValue(forKey: k) }
        let c = try JSONDecoder().decode(GenerativeSettings.self, from: jsonData(o))
        XCTAssertEqual(c.composition, 0); XCTAssertEqual(c.vocals, 0); XCTAssertEqual(c.piano, 0)
        XCTAssertEqual(GenerativeSettings.dspIndex(22), Int32(ONDE_COMPOSITION))
        XCTAssertEqual(GenerativeSettings.dspIndex(23), Int32(ONDE_VOCALS))
        XCTAssertEqual(GenerativeSettings.dspIndex(24), Int32(ONDE_PIANO))
    }
    func testScoreMustBeAValidInteger() throws {
        var c = GenerativeSettings()
        for x in [-1.0, 0.5, 4.1, Double.nan, Double.infinity] { XCTAssertThrowsError(try c.set("composition", x)) }
        try c.set("composition", 4); XCTAssertEqual(c.composition, 4)
        for k in ["vocals", "piano"] { XCTAssertThrowsError(try c.set(k, 1.01)); try c.set(k, 0.5) }
    }
    func testEachScoreRendersItsIntendedSource() throws {
        guard OrchestraBank.directory() != nil else { throw XCTSkip("Acoustic bank required") }
        for p in FocusCompositions.profiles {
            let core = try XCTUnwrap(onde_dsp_create(44100, 0, p.configuration.seed)); defer { onde_dsp_destroy(core) }
            _ = try OrchestraBank.load(into: core, required: true)
            for (i, v) in p.configuration.values.enumerated() { onde_dsp_set(core, GenerativeSettings.dspIndex(i), Float(v)) }
            onde_dsp_set(core, Int32(ONDE_GAIN), 1)
            var l = [Float](repeating: 0, count: 1024), r = l, peak: Float = 0
            var energy: Double = 0
            for _ in 0..<440 {
                onde_dsp_render(core, &l, &r, 1024)
                for i in l.indices { XCTAssertTrue(l[i].isFinite && r[i].isFinite); peak = max(peak, abs(l[i]), abs(r[i])); energy += Double(l[i]*l[i]+r[i]*r[i]) }
            }
            XCTAssertEqual(onde_dsp_composition(core), Int32(p.configuration.composition))
            XCTAssertGreaterThan(onde_dsp_signature_events(core), 20)
            XCTAssertEqual(onde_dsp_grain_events(core), 0)
            XCTAssertGreaterThan(peak, 0.015); XCTAssertLessThan(peak, 0.951)
            XCTAssertGreaterThan(sqrt(energy/Double(440*1024*2)), 0.004)
            if p.id == "filigrane" { XCTAssertNotEqual(onde_dsp_orchestra_families(core)&2048, 0) }
            if p.id == "sanctuaire" { XCTAssertGreaterThan(onde_dsp_choir_voices(core), 5) }
            let period=44100*60/p.configuration.tempo
            XCTAssertEqual(Double(onde_dsp_max_beat_gap(core)), ceil(period), accuracy: 1)
            XCTAssertEqual(Double(onde_dsp_min_beat_gap(core)), floor(period), accuracy: 1)
        }
    }
    func testVoiceMuteDoesNotChangeClockOrScore() throws {
        var config = try XCTUnwrap(SoundProfile.find("sanctuaire")).configuration
        var clocks: [UInt64] = [], scores: [UInt64] = [], recordings: [[Float]] = []
        for gain in [0.0, 1.0] {
            config.vocals=gain
            let core=try XCTUnwrap(onde_dsp_create(22050,0,config.seed)); defer { onde_dsp_destroy(core) }
            for (i,v) in config.values.enumerated(){onde_dsp_set(core,GenerativeSettings.dspIndex(i),Float(v))}
            onde_dsp_set(core,Int32(ONDE_GAIN),1)
            var l=[Float](repeating:0,count:1024),r=l
            for _ in 0..<130 {onde_dsp_render(core,&l,&r,1024)}
            clocks.append(onde_dsp_beats(core));scores.append(onde_dsp_signature_events(core));recordings.append(l)
        }
        XCTAssertEqual(clocks[0],clocks[1]);XCTAssertEqual(scores[0],scores[1]);XCTAssertNotEqual(recordings[0],recordings[1])
    }
}
