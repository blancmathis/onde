import XCTest
import OndeDSP
@testable import OndeCore

final class RelaxationTests: XCTestCase {
    func testFiveIndependentRelaxationScoresAndSharedCatalog() throws {
        XCTAssertEqual(RelaxCompositions.ids, ["lagoon", "stillwater", "hearth", "reverie", "driftwood"])
        XCTAssertEqual(RelaxCompositions.profiles.map { Int($0.configuration.composition) }, [8,9,10,11,12])
        XCTAssertEqual(MusicCatalog.profiles(for: .relax).map(\.id), MusicCatalog.profiles(for: .meditation).map(\.id))
        XCTAssertEqual(MusicCatalog.profiles(for: .relax).count, 8)
        for p in RelaxCompositions.profiles {
            XCTAssertEqual(p.mode, .relax); _ = try p.configuration.validated()
            XCTAssertTrue(MusicCatalog.allows(p.id, in: .meditation))
            XCTAssertFalse(MusicCatalog.allows(p.id, in: .focus))
            XCTAssertEqual(p.configuration.punch, 0); XCTAssertEqual(p.configuration.drive, 0)
            XCTAssertEqual(p.configuration.percussion, 0); XCTAssertEqual(p.configuration.texture, 0)
        }
    }
    func testAddingMusicDoesNotReplaceDefaultsOrStoredPreferences() throws {
        var prefs = ListeningPreferences()
        try prefs.setDefault("ambre", for: .focus); try prefs.setDefault("rive", for: .relax)
        try prefs.setDefault("immersion", for: .meditation)
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let before=try encoder.encode(prefs)
        _=RelaxCompositions.profiles
        XCTAssertEqual(try encoder.encode(prefs),before)
        try prefs.setDefault("hearth", for: .meditation)
        XCTAssertEqual(prefs.defaultID(for:.relax),"rive")
    }
    func testPlannerIsDeterministicBoundedAndDevelopsLongPhrases() {
        for style:Int32 in 8...12 {
            var fingerprints=Set<UInt64>()
            for phrase:UInt64 in 0..<120 {
                var a=OndePhrasePlan(),b=OndePhrasePlan()
                XCTAssertEqual(onde_relaxation_plan(style,11100+UInt64(style),phrase,0.4,&a),1)
                XCTAssertEqual(onde_relaxation_plan(style,11100+UInt64(style),phrase,0.4,&b),1)
                XCTAssertEqual(a.fingerprint,b.fingerprint);fingerprints.insert(a.fingerprint)
                XCTAssertEqual(a.chapter,phrase/12);XCTAssertEqual(a.phrase,phrase)
                XCTAssertTrue((0...3).contains(a.variant));XCTAssertTrue((0...5).contains(a.harmony))
                let chord=withUnsafeBytes(of:a.chord){Array($0.bindMemory(to:Int32.self))}
                let melody=withUnsafeBytes(of:a.melody){Array($0.bindMemory(to:Int32.self))}
                XCTAssertEqual(chord.sorted(),chord);XCTAssertEqual(chord[0],53)
                XCTAssertTrue(chord.allSatisfy{(48...76).contains($0)})
                XCTAssertTrue(melody.allSatisfy{(0...4).contains($0)})
                XCTAssertNotEqual(Array(melody.prefix(8)),Array(melody.suffix(8)))
            }
            XCTAssertGreaterThan(fingerprints.count,24)
        }
    }
    func testFrozenEvolutionAndBoundaryValidation() {
        var a=OndePhrasePlan(),b=OndePhrasePlan()
        for style:Int32 in 8...12 {
            XCTAssertEqual(onde_relaxation_plan(style,7,0,0,&a),1)
            XCTAssertEqual(onde_relaxation_plan(style,7,UInt64.max-1,0,&b),1)
            XCTAssertEqual(a.fingerprint,b.fingerprint)
            XCTAssertEqual(onde_relaxation_plan(style,7,UInt64.max,0.4,&b),1)
        }
        XCTAssertEqual(onde_relaxation_plan(7,1,0,0.4,&a),0)
        XCTAssertEqual(onde_relaxation_plan(13,1,0,0.4,&a),0)
        XCTAssertEqual(onde_relaxation_plan(8,1,0,.nan,&a),0)
        XCTAssertEqual(onde_relaxation_plan(8,1,0,-1,&a),0)
        XCTAssertEqual(onde_relaxation_plan(8,1,0,2,&a),0)
        XCTAssertEqual(onde_relaxation_plan(8,1,0,0.4,nil),0)
    }
    func testHarmonyStaysForSixteenBarsAndKeepsCommonTones() {
        for style: Int32 in 8...12 {
            var previous = Set<Int32>()
            for phrase: UInt64 in 0..<240 {
                var p = OndePhrasePlan(), paired = OndePhrasePlan()
                XCTAssertEqual(onde_relaxation_plan(style, 11100 + UInt64(style), phrase, 0.4, &p), 1)
                XCTAssertEqual(onde_relaxation_plan(style, 11100 + UInt64(style), phrase ^ 1, 0.4, &paired), 1)
                let chord = withUnsafeBytes(of: p.chord) { Array($0.bindMemory(to: Int32.self)) }
                let matching = withUnsafeBytes(of: paired.chord) { Array($0.bindMemory(to: Int32.self)) }
                XCTAssertEqual(chord, matching)
                if !previous.isEmpty { XCTAssertGreaterThanOrEqual(previous.intersection(chord).count, 2) }
                previous = Set(chord)
            }
        }
    }
    func testZeroDetailsStillProvidesContinuousMusicWithoutTransientEvents() throws {
        for profile in RelaxCompositions.profiles {
            var c = profile.configuration; c.density = 0; c.piano = 0; c.harp = 0
            let p = try create(c); defer { onde_dsp_destroy(p) }
            var left = [Float](repeating: 0, count: 512), right = left
            var energy: Double = 0
            for _ in 0..<125 {
                onde_dsp_render(p, &left, &right, 512)
                energy += left.reduce(0.0) { $0 + Double($1) * Double($1) }
            }
            XCTAssertGreaterThan(energy, 0.01, profile.id)
            XCTAssertEqual(onde_dsp_note_events(p), 0, profile.id)
        }
    }
    private func create(_ config:GenerativeSettings,rate:Double=8000,bank:Bool=false) throws -> OpaquePointer {
        let p=try XCTUnwrap(onde_dsp_create(rate,1,config.seed))
        do {if bank {try OrchestraBank.load(into:p,required:true)}} catch {onde_dsp_destroy(p);throw error}
        for(i,v) in config.values.enumerated(){onde_dsp_set(p,GenerativeSettings.dspIndex(i),Float(v))}
        onde_dsp_set(p,Int32(ONDE_GAIN),1);return p
    }
    private func audio(_ id:String,block:Int,vocals:Double?=nil) throws -> [Float] {
        var c=try XCTUnwrap(SoundProfile.find(id)).configuration
        if let vocals{c.vocals=vocals}
        let p=try create(c);defer{onde_dsp_destroy(p)}
        var output=[Float](),l=[Float](repeating:0,count:block),r=l
        var remaining=8000*12
        while remaining>0{let n=min(remaining,block);onde_dsp_render(p,&l,&r,UInt32(n));output.append(contentsOf:l.prefix(n));remaining-=n}
        return output
    }
    func testSampleClockIsIndependentOfCallbackSizeForAllFive() throws {
        for id in RelaxCompositions.ids{XCTAssertEqual(try audio(id,block:127),try audio(id,block:1024),id)}
    }
    func testWordlessVoicesCanBeRemovedWithoutRemovingMusic() throws {
        let on=try audio("reverie",block:512),off=try audio("reverie",block:512,vocals:0)
        XCTAssertNotEqual(on,off)
        XCTAssertGreaterThan(off.map{abs($0)}.max() ?? 0,0.002)
    }
    func testEachScoreRendersRealSourcesAndKeepsTheGrid() throws {
        for profile in RelaxCompositions.profiles {
            let p=try create(profile.configuration,bank:profile.configuration.orchestra>0);defer{onde_dsp_destroy(p)}
            var l=[Float](repeating:0,count:1024),r=l
            var peak:Float=0,jump:Float=0,previous:Float=0
            for _ in 0..<235 {
                onde_dsp_render(p,&l,&r,1024)
                for x in l {XCTAssertTrue(x.isFinite);peak=max(peak,abs(x));jump=max(jump,abs(x-previous));previous=x}
            }
            XCTAssertGreaterThan(peak,0.004,profile.id);XCTAssertLessThan(peak,0.78,profile.id)
            XCTAssertLessThan(jump,0.30,profile.id)
            XCTAssertEqual(onde_dsp_composition(p),Int32(profile.configuration.composition))
            XCTAssertEqual(onde_dsp_grain_events(p),0)
            XCTAssertLessThanOrEqual(onde_dsp_max_beat_gap(p)-onde_dsp_min_beat_gap(p),1)
            if profile.configuration.orchestra>0 {XCTAssertEqual(onde_dsp_orchestra_samples(p),76);XCTAssertGreaterThan(onde_dsp_orchestra_events(p),0)}
            if profile.id=="reverie"{XCTAssertGreaterThan(onde_dsp_choir_voices(p),0)}
        }
    }
    func testRelaxationControlsRoundTripAndRejectFractionalScores() throws {
        for p in RelaxCompositions.profiles {XCTAssertEqual(try JSONDecoder().decode(GenerativeSettings.self,from:JSONEncoder().encode(p.configuration)),p.configuration)}
        var c=GenerativeSettings()
        for v in [8.5,12.1,13,-1,Double.infinity]{XCTAssertThrowsError(try c.set("composition",v))}
        try c.set("composition",12);XCTAssertEqual(c.composition,12)
    }
}
