import XCTest
@testable import OndeCore

final class ListeningTests: XCTestCase {
    func testMeditationAndRelaxShareExactCatalog() {
        XCTAssertEqual(MusicCatalog.profiles(for: .relax).map(\.id), RelaxCompositions.ids + ["velours", "rive", "immersion"])
        XCTAssertEqual(MusicCatalog.profiles(for: .meditation).map(\.id), MusicCatalog.profiles(for: .relax).map(\.id))
        XCTAssertEqual(MusicCatalog.profiles(for: .focus).count, 17)
        XCTAssertEqual(Set(MusicCatalog.profiles(for: .focus).map(\.id)).intersection(MusicCatalog.profiles(for: .relax).map(\.id)), [])
    }
    func testIndependentDefaults() throws {
        var p = ListeningPreferences()
        XCTAssertEqual(p.defaultID(for: .focus), "sillage")
        XCTAssertEqual(p.defaultID(for: .relax), "velours")
        XCTAssertEqual(p.defaultID(for: .meditation), "immersion")
        try p.setDefault("rive", for: .meditation)
        XCTAssertEqual(p.defaultID(for: .relax), "velours")
        XCTAssertEqual(p.defaultID(for: .meditation), "rive")
    }
    func testWrongCategoryAndUnknownDefaultsRejectedWithoutMutation() throws {
        var p = ListeningPreferences(); try p.setDefault("ambre", for: .focus)
        XCTAssertThrowsError(try p.setDefault("ambre", for: .relax))
        XCTAssertThrowsError(try p.setDefault("sillage", for: .meditation))
        XCTAssertThrowsError(try p.setDefault("unknown", for: .focus))
        XCTAssertEqual(p.defaults, ["focus":"ambre"])
    }
    func testCorruptOrObsoleteDefaultsHaveValidFallbacks() {
        var p = ListeningPreferences(); p.defaults = ["focus":"missing", "relax":"sillage", "meditation":"atlas"]
        for mode in SessionMode.allCases { XCTAssertTrue(MusicCatalog.allows(p.defaultID(for: mode), in: mode)) }
    }
    func testMigrationRetainsSuitableExistingMusicAndTuning() {
        var s = StoredState(); var c = SoundProfile.find("ambre")!.configuration; c.bass = 0.88
        s.generatorSettings = ["focus":c, "relax":SoundProfile.find("rive")!.configuration]
        s.layers = ["living":Layer(true,0.72), "pink":Layer(true,0.14)]
        let p = ListeningPreferences.migrating(s)
        XCTAssertEqual(p.defaultID(for: .focus), "ambre")
        XCTAssertEqual(p.defaultID(for: .relax), "rive")
        XCTAssertEqual(p.customizations["focus:ambre"]?.bass, 0.88)
        XCTAssertEqual(p.musicLevels["focus"], 0.72)
        XCTAssertEqual(p.backgrounds["focus"], .init(kind:.pink,volume:0.14))
        XCTAssertEqual(s.layers["pink"]?.enabled, true)
        XCTAssertNil(s.listening)
    }
    func testMigrationDoesNotEraseLegacyObjectsOrHistory() throws {
        var s = StoredState()
        s.mixes = [Mix(name:"My mix", mode:.focus, layers:["brown":Layer(true,0.3)])]
        s.history = [SessionRecord(date:Date(timeIntervalSince1970:10000),mode:.focus,seconds:500)]
        s.imported = [Sound(id:"local-file",title:"Keep me",subtitle:"",symbol:"music.note",kind:"Personal",filename:"original.wav",imported:true)]
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(s)
        _ = ListeningPreferences.migrating(s)
        XCTAssertEqual(try encoder.encode(s), before)
    }
    func testStoredStateWithoutNewFieldsDecodes() throws {
        var original = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(StoredState())) as? [String:Any])
        original.removeValue(forKey:"listening")
        let s = try JSONDecoder().decode(StoredState.self,from:JSONSerialization.data(withJSONObject:original))
        XCTAssertNil(s.listening)
        XCTAssertEqual(ListeningPreferences.migrating(s).defaultID(for:.meditation),"immersion")
    }
    func testPreferencesRoundTripAndBackgroundsRemainPerMode() throws {
        var p = ListeningPreferences()
        try p.setDefault("sanctuaire",for:.focus); try p.setDefault("velours",for:.meditation)
        p.backgrounds = ["focus":.init(kind:.white,volume:0.22),"relax":.init(kind:.off,volume:0.12)]
        let q = try JSONDecoder().decode(ListeningPreferences.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(q.defaultID(for:.focus),"sanctuaire")
        XCTAssertEqual(q.defaultID(for:.meditation),"velours")
        XCTAssertEqual(q.backgrounds,p.backgrounds)
    }
    func testBackgroundKindsAndTrueWhiteNoiseResource() {
        XCTAssertEqual(BackgroundKind.allCases.map(\.rawValue), ["off","white","pink","brown","rain","ocean"])
        XCTAssertNil(BackgroundKind.off.soundID)
        let white = Sound.builtins.first { $0.id == "white" }
        XCTAssertEqual(white?.filename,"white.wav")
        XCTAssertEqual(white?.license,"CC0-1.0")
        XCTAssertEqual(white?.kind,"Noise")
    }
    func testBackgroundInferenceIgnoresDisabledLayers() {
        XCTAssertEqual(BackgroundMix.infer(from:["white":Layer(false,1),"pink":Layer(true,0.2)]), .init(kind:.pink,volume:0.2))
        XCTAssertEqual(BackgroundMix.infer(from:["living":Layer(true,1)]).kind,.off)
        XCTAssertEqual(BackgroundMix(kind:.white,volume:.infinity).volume,0)
        XCTAssertEqual(BackgroundMix(kind:.white,volume:2).volume,1)
    }
    func testModeSpecificTuningKeysNeverCollide() {
        XCTAssertNotEqual(MusicCatalog.settingKey("rive",mode:.relax), MusicCatalog.settingKey("rive",mode:.meditation))
    }
    func testPrimaryUIHasNoSidebarOrLibraryDestination() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf:root.appendingPathComponent("Sources/OndeApp/ListeningView.swift"))
        XCTAssertFalse(source.contains("Sidebar()"))
        XCTAssertFalse(source.contains("LibraryView()"))
        XCTAssertFalse(source.contains("GenerativeView()"))
        XCTAssertTrue(source.contains("ListeningModeButton"))
        XCTAssertTrue(source.contains("ListeningMusicCard"))
        XCTAssertTrue(source.contains("Set \\(profile.title) as \\(model.mode.title) default"))
    }
}
