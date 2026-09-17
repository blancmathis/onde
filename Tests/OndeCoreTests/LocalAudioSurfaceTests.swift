import XCTest
@testable import OndeCore

final class LocalAudioSurfaceTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func testAppHasNoEmbeddedWebPlayer() throws {
        let paths = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Sources/OndeApp"), includingPropertiesForKeys: nil)
        for path in paths where path.pathExtension == "swift" {
            let source = try String(contentsOf: path, encoding: .utf8)
            XCTAssertFalse(source.contains("import WebKit"), path.lastPathComponent)
            XCTAssertFalse(source.contains("WKWebView"), path.lastPathComponent)
            XCTAssertFalse(source.contains("iframe_api"), path.lastPathComponent)
        }
    }
    func testGeneratorReportsNeutralLocalProvenance() throws {
        let source = try String(contentsOf: root.appendingPathComponent("Sources/OndeCore/GenerativeRenderer.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("\"audio_origin\": \"local_generation\""))
    }
    func testAllMusicalIdentitiesRemainAvailable() throws {
        XCTAssertEqual(SoundProfile.all.count, 20)
        XCTAssertEqual(Set(FocusCompositions.ids), Set(["ambre", "canopee", "meridien", "sillage", "filigrane", "confluence", "sanctuaire"]))
        for profile in SoundProfile.all { _ = try profile.configuration.validated() }
    }
}
