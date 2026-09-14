import XCTest
@testable import OndeCore

final class AppBuildTests: XCTestCase {
    func testPublishedVersionComesFromBundleMetadata() {
        XCTAssertEqual(AppBuild.versionLabel(metadata: ["CFBundleShortVersionString": "1.6.0"]), "1.6.0")
        XCTAssertEqual(AppBuild.versionLabel(metadata: ["CFBundleShortVersionString": "3.4.2"]), "3.4.2")
    }
    func testUnpackagedBuildDoesNotPretendToBeAnOldRelease() {
        XCTAssertEqual(AppBuild.versionLabel(metadata: [:]), "development")
        XCTAssertEqual(AppBuild.versionLabel(metadata: ["CFBundleShortVersionString": ""]), "development")
    }
}
