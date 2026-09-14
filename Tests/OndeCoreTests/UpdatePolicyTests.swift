import XCTest
@testable import OndeCore

final class UpdatePolicyTests: XCTestCase {
    func fixture() -> PublicRelease {
        PublicRelease(tag_name: "build-20260914190000-01234567", name: "Onde 1.5.0", draft: false,
                      prerelease: false, target_commitish: "01234567" + String(repeating: "a", count: 32),
                      html_url: "https://github.com/blancmathis/onde/releases",
                      assets: [ReleaseAsset(name: UpdatePolicy.archiveName, size: 1_234_567,
                        browser_download_url: "https://github.com/blancmathis/onde/releases/download/build-20260914190000-01234567/Onde-macOS-universal.zip",
                        digest: "sha256:" + String(repeating: "a", count: 64))])
    }
    func testValidPublishedBuildAndUpgradeOrdering() throws {
        let release = try UpdatePolicy.parse(fixture())
        XCTAssertTrue(UpdatePolicy.isNewer(release, than: 20260914180000))
        XCTAssertFalse(UpdatePolicy.isNewer(release, than: release.build))
        XCTAssertFalse(UpdatePolicy.isNewer(release, than: 20260915180000))
    }
    func testRejectDraftOrPrerelease() {
        var r = fixture(); r.draft = true; XCTAssertThrowsError(try UpdatePolicy.parse(r))
        r.draft = false; r.prerelease = true; XCTAssertThrowsError(try UpdatePolicy.parse(r))
    }
    func testRejectForeignHostPathCredentialsOrHTTP() {
        for url in ["http://github.com/blancmathis/onde/releases/download/x/Onde-macOS-universal.zip",
                    "https://github.com.evil.example/blancmathis/onde/releases/download/x/Onde-macOS-universal.zip",
                    "https://github.com/other/project/releases/download/x/Onde-macOS-universal.zip",
                    "https://user@github.com/blancmathis/onde/releases/download/build-20260914190000-01234567/Onde-macOS-universal.zip"] {
            var r = fixture(); r.assets[0].browser_download_url = url
            XCTAssertThrowsError(try UpdatePolicy.parse(r))
        }
    }
    func testRejectMissingOrInvalidDigest() {
        for digest: String? in [nil, "", "sha256:bad", "sha256:" + String(repeating: "z", count: 64)] {
            var r = fixture(); r.assets[0].digest = digest; XCTAssertThrowsError(try UpdatePolicy.parse(r))
        }
    }
    func testRejectUnexpectedTagCommitAndOversizedAsset() {
        var r = fixture(); r.tag_name = "main"; XCTAssertThrowsError(try UpdatePolicy.parse(r))
        r = fixture(); r.target_commitish = "main"; XCTAssertThrowsError(try UpdatePolicy.parse(r))
        r = fixture(); r.assets[0].size = 400_000_001; XCTAssertThrowsError(try UpdatePolicy.parse(r))
    }
}
