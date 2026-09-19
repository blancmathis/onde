import XCTest
@testable import OndeCore

final class EspaceIdentityTests: XCTestCase {
    func testStaticCoverFamiliesAreStableAndDistinct() {
        let ids = ["sillage", "ambre", "meridien", "filigrane", "canopee", "stillwater"]
        XCTAssertEqual(Set(ids.map(ListeningDesign.coverFamily)), Set(0..<6))
        for id in ["", "personal", "abc", "immersion", "héarth"] {
            XCTAssertTrue((0..<6).contains(ListeningDesign.coverFamily(id)))
            XCTAssertEqual(ListeningDesign.coverFamily(id), ListeningDesign.coverFamily(id))
        }
    }
}
