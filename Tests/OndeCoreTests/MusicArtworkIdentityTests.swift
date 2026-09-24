import XCTest
@testable import OndeCore

final class MusicArtworkIdentityTests: XCTestCase {
    func testEveryMusicHasAnExplicitUniqueIdentity() {
        let ids = Set(SoundProfile.all.map(\.id))
        XCTAssertEqual(ids.count, 25)
        XCTAssertEqual(Set(MusicArtworkIdentity.catalog.keys), ids)
        XCTAssertEqual(Set(MusicArtworkIdentity.catalog.values).count, ids.count)
    }
    func testCoverAndPlayerUseOneIdentityInAllThreeCatalogs() {
        for mode in SessionMode.allCases {
            for music in MusicCatalog.profiles(for: mode) {
                let cover = OndeMotif.forMusic(music.id)
                let live = EspaceArtworkSelection.motif(choice: "automatic", musicID: music.id, mode: mode)
                XCTAssertEqual(cover, live, "\(mode.rawValue):\(music.id)")
                XCTAssertEqual(live, MusicArtworkIdentity.catalog[music.id])
                XCTAssertNotEqual(MusicArtworkIdentity.color(live), 0)
                XCTAssertTrue((0.5...1).contains(MusicArtworkIdentity.aspect(live)))
            }
        }
    }
    func testRelaxAndMeditationDoNotChangeAMusicsDesign() {
        for music in MusicCatalog.profiles(for: .relax) {
            XCTAssertEqual(EspaceArtworkSelection.motif(choice: "automatic", musicID: music.id, mode: .relax),
                           EspaceArtworkSelection.motif(choice: "automatic", musicID: music.id, mode: .meditation))
        }
    }
    func testAllPostersHaveDifferentGeometry() {
        let fingerprints = SoundProfile.all.map { music in
            OndeMotionGeometry.strokes(OndeMotif.forMusic(music.id), time: 0, quality: .thumbnail)
                .flatMap(\.points).map { String(format: "%.4f:%.4f", $0.x, $0.y) }.joined(separator: ",")
        }
        XCTAssertEqual(Set(fingerprints).count, SoundProfile.all.count)
    }
}
