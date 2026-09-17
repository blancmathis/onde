import XCTest
@testable import OndeCore
final class EnglishCopyTests: XCTestCase {
    func testModesAndFeaturedTitlesAreEnglish() {
        XCTAssertEqual(SessionMode.allCases.map(\.title), ["Focus", "Relax", "Meditation"])
        XCTAssertEqual(FocusCompositions.profiles.map(\.title), ["Amber", "Canopy", "Meridian", "Slipstream", "Filigree", "Confluence", "Sanctuary"])
    }
    func testProfileIDsRemainBackwardsCompatible() {
        XCTAssertEqual(FocusCompositions.ids, ["ambre", "canopee", "meridien", "sillage", "filigrane", "confluence", "sanctuaire"])
        XCTAssertEqual(SoundProfile.find("elan")?.title, "Momentum")
        XCTAssertEqual(SoundProfile.find("reacteur")?.title, "Reactor")
        XCTAssertEqual(Sound.builtins.first(where: { $0.id == "aube" })?.filename, "aube.m4a")
    }
    func testImportTitleAndProvenanceAreNeverRenamed() {
        let s = Sound(id: "user", title: "My original title", subtitle: "Import personnel · 05:00", symbol: "music.note", kind: "Personnel", filename: "test.wav", author: "Artist", source: "test.wav", imported: true)
        XCTAssertEqual(s.title, "My original title")
        XCTAssertEqual(s.displaySubtitle, "Personal import · 05:00")
        XCTAssertEqual(s.subtitle, "Import personnel · 05:00")
        XCTAssertEqual(s.source, "test.wav")
    }
}
