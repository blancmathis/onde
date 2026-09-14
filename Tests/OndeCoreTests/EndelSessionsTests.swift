import XCTest
@testable import OndeCore
final class EndelSessionsTests: XCTestCase {
    func testCatalogContainsOnlyFullLengthSessions() {
        XCTAssertEqual(EndelSession.all.count, 8)
        XCTAssertTrue(EndelSession.all.allSatisfy { $0.minutes >= 60 })
        XCTAssertEqual(Set(EndelSession.all.map(\.id)).count, 8)
        XCTAssertEqual(Set(EndelSession.all.map(\.videoID)).count, 8)
    }
    func testReferencesStayOnOfficialProvider() {
        for session in EndelSession.all {
            XCTAssertEqual(URL(string:session.url)?.host,"www.youtube.com")
            XCTAssertEqual(session.videoID.count,11)
            XCTAssertEqual(session.descriptor["offline"] as? Bool,false)
            XCTAssertEqual(session.descriptor["demo"] as? Bool,false)
        }
    }
    func testUnknownIDDoesNotBecomeAnArbitraryURL() {
        XCTAssertNil(EndelSession.find("https://example.com"))
        XCTAssertEqual(EndelSession.find("relax")?.mode, .relax)
    }
}
