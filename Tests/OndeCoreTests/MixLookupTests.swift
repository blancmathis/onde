import Foundation
import XCTest
@testable import OndeCore

final class MixLookupTests: XCTestCase {
    private let firstID = "A1234567-1234-1234-1234-123456789ABC"
    private let secondID = "B1234567-1234-1234-1234-123456789ABC"

    private func mix(_ name: String, id: String) -> Mix {
        var value = Mix(name: name, mode: .focus, layers: [:])
        value.id = id
        return value
    }
    private func rejects(_ reference: String, in mixes: [Mix], code: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try MixLookup.index(for: reference, in: mixes), file: file, line: line) {
            XCTAssertEqual(($0 as? OndeError)?.code, code, file: file, line: line)
        }
    }
    func testIDWinsOverAnEarlierNameThatLooksLikeTheID() throws {
        let mixes = [mix(firstID, id: secondID), mix("Chosen", id: firstID)]
        XCTAssertEqual(try MixLookup.index(for: firstID, in: mixes), 1)
    }
    func testUUIDLookupIsCaseInsensitive() throws {
        XCTAssertEqual(try MixLookup.index(for: firstID.lowercased(), in: [mix("Chosen", id: firstID)]), 0)
    }
    func testStaleUUIDNeverFallsBackToAnotherMixName() {
        rejects(firstID, in: [mix(firstID, id: secondID)], code: "not_found")
    }
    func testAmbiguousDisplayNameIsRejected() {
        rejects("Same name", in: [mix("Same name", id: firstID), mix("Same name", id: secondID)], code: "ambiguous_mix")
    }
    func testUUIDStillChoosesOneOfSeveralIdenticalNames() throws {
        var mixes = [mix("Same name", id: firstID), mix("Same name", id: secondID)]
        let index = try MixLookup.index(for: firstID, in: mixes)
        mixes.remove(at: index)
        XCTAssertEqual(mixes.map(\.id), [secondID])
    }
    func testUniqueLegacyNameRemainsSupported() throws {
        XCTAssertEqual(try MixLookup.index(for: "Evening mix", in: [mix("Evening mix", id: firstID)]), 0)
    }
    func testUnicodeAndQuotedNamesRemainLiteral() throws {
        let name = "Étude 'du soir'"
        XCTAssertEqual(try MixLookup.index(for: name, in: [mix(name, id: firstID)]), 0)
        rejects("Etude 'du soir'", in: [mix(name, id: firstID)], code: "not_found")
    }
    func testDuplicateStoredIDsAreRejectedWithoutMutation() {
        let mixes = [mix("One", id: firstID), mix("Two", id: firstID.lowercased())]
        rejects(firstID, in: mixes, code: "ambiguous_mix")
        XCTAssertEqual(mixes.count, 2)
    }
    func testLegacyNonUUIDIDKeepsPriority() throws {
        let mixes = [mix("legacy-id", id: secondID), mix("Chosen", id: "legacy-id")]
        XCTAssertEqual(try MixLookup.index(for: "legacy-id", in: mixes), 1)
    }
    func testUnknownAndEmptyReferencesFail() {
        rejects("Missing", in: [mix("Known", id: firstID)], code: "not_found")
        rejects("", in: [], code: "not_found")
        rejects(firstID, in: [], code: "not_found")
    }
}
