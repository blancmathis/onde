import XCTest
@testable import OndeCore

final class EspaceChimeDraftTests: XCTestCase {
    func testInitialDraftIsCleanAndUsesMinutes() {
        let draft = EspaceChimeDraft(markers: [600, 1200, 1800, 2400])
        XCTAssertEqual(draft.text, "10, 20, 30, 40")
        XCTAssertFalse(draft.isDirty)
        XCTAssertFalse(draft.hasConflict)
    }
    func testEditingDoesNotMutateSavedTimes() {
        var draft = EspaceChimeDraft(markers: [600, 1200, 1800, 2400])
        draft.text = "5, 15"
        XCTAssertTrue(draft.isDirty)
        XCTAssertEqual(draft.savedMarkers, [600, 1200, 1800, 2400])
    }
    func testCleanDraftFollowsExternalChange() {
        var draft = EspaceChimeDraft(markers: [600])
        draft.receive([300, 900])
        XCTAssertEqual(draft.text, "5, 15")
        XCTAssertFalse(draft.isDirty)
    }
    func testExternalChangePreservesDirtyDraftAndBlocksApply() {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = "5, 15"
        draft.receive([1200])
        XCTAssertEqual(draft.text, "5, 15")
        XCTAssertTrue(draft.hasConflict)
        XCTAssertThrowsError(try draft.parsedSeconds())
    }
    func testUnchangedSnapshotDoesNotConflict() {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = "5"
        draft.receive([600])
        XCTAssertFalse(draft.hasConflict)
    }
    func testMatchingExternalChangeClearsConflict() {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = "5, 15"
        draft.receive([300, 900])
        XCTAssertFalse(draft.hasConflict)
        XCTAssertFalse(draft.isDirty)
    }
    func testReloadUsesLatestSavedMarkers() {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = "5"
        draft.receive([1200, 2400])
        draft.reload()
        XCTAssertEqual(draft.text, "20, 40")
        XCTAssertFalse(draft.isDirty)
        XCTAssertFalse(draft.hasConflict)
    }
    func testEmptyDraftDisablesMarkersExplicitly() throws {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = " \n "
        XCTAssertTrue(draft.isDirty)
        XCTAssertEqual(try draft.parsedSeconds(), [])
    }
    func testParsingNormalizesFiniteSortedUniqueSeconds() throws {
        var draft = EspaceChimeDraft(markers: [])
        draft.text = " 30, 2.5, 10, 10 "
        XCTAssertEqual(try draft.parsedSeconds(), [150, 600, 1800])
    }
    func testInvalidInputIsNeverCoercedOrPartiallyApplied() {
        for value in ["0", "-1", "1441", "nan", "inf", "10,,20", "10,", ",10", "10,no,20", String(repeating: "1,", count: 32) + "1"] {
            var draft = EspaceChimeDraft(markers: [600])
            draft.text = value
            XCTAssertThrowsError(try draft.parsedSeconds(), value)
            XCTAssertEqual(draft.savedMarkers, [600])
        }
    }
    func testSuccessfulApplyNormalizesAndClearsDirtyState() throws {
        var draft = EspaceChimeDraft(markers: [600])
        draft.text = "30, 10, 10"
        draft.didApply(try draft.parsedSeconds())
        XCTAssertEqual(draft.text, "10, 30")
        XCTAssertFalse(draft.isDirty)
    }
    func testInclusiveMaximumAndThirtyTwoTimes() throws {
        var draft = EspaceChimeDraft(markers: [])
        draft.text = "1440"
        XCTAssertEqual(try draft.parsedSeconds(), [86400])
        draft.text = (1...32).map(String.init).joined(separator: ",")
        XCTAssertEqual(try draft.parsedSeconds().count, 32)
    }
}
