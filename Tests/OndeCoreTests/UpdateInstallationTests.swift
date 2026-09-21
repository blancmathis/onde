#if os(macOS)
import XCTest
import CryptoKit
@testable import OndeCore

final class UpdateInstallationTests: XCTestCase {
    private func zip(_ names: [String], mode: UInt32 = 0o100644, flags: UInt16 = 0, size: UInt32 = 0, localName: String? = nil) -> Data {
        func n16(_ n: UInt16) -> Data { Data([UInt8(n & 255), UInt8(n >> 8)]) }
        func n32(_ n: UInt32) -> Data { Data([UInt8(n & 255), UInt8((n >> 8) & 255), UInt8((n >> 16) & 255), UInt8(n >> 24)]) }
        var payload = Data(), central = Data()
        for name in names {
            let bytes = Data(name.utf8), local = Data((localName ?? name).utf8), offset = UInt32(payload.count)
            payload += n32(0x04034b50) + n16(20) + n16(flags) + n16(0) + n16(0) + n16(0)
            payload += n32(0) + n32(0) + n32(size) + n16(UInt16(local.count)) + n16(0) + local
            central += n32(0x02014b50) + n16(0x0314) + n16(20) + n16(flags) + n16(0) + n16(0) + n16(0)
            central += n32(0) + n32(0) + n32(size) + n16(UInt16(bytes.count)) + n16(0) + n16(0)
            central += n16(0) + n16(0) + n32(mode << 16) + n32(offset) + bytes
        }
        let start = payload.count
        payload += central
        payload += n32(0x06054b50) + n16(0) + n16(0) + n16(UInt16(names.count)) + n16(UInt16(names.count))
        payload += n32(UInt32(central.count)) + n32(UInt32(start)) + n16(0)
        return payload
    }

    func testAcceptsBoundedApplicationArchive() throws {
        try UpdateInstallation.validateZIP(zip(["Onde.app/Contents/Info.plist", "Onde.app/Contents/MacOS/Onde"]))
    }
    func testRejectsTraversalAndOtherBundles() {
        for name in ["../Onde.app/file", "/Onde.app/file", "Other.app/file", "Onde.app/../../evil", "Onde.app/./file", "Onde.app//file", "Onde.app/a\\b", "Onde.app/a:b", "Onde.app/a\nfile"] {
            XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip([name])), name)
        }
    }
    func testRejectsLinksPrivilegedFilesEncryptionAndDuplicateNames() {
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/link"], mode: 0o120777)))
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/file"], mode: 0o104755)))
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/file"], flags: 1)))
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/file", "Onde.app/file"])))
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/file", "Onde.app/FILE"])))
    }
    func testRejectsDisagreementBetweenLocalAndCentralHeaders() {
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/ok"], localName: "Onde.app/no")))
    }
    func testRejectsExpansionBombsAndTruncation() {
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip(["Onde.app/file"], size: 400_000_001)))
        XCTAssertThrowsError(try UpdateInstallation.validateZIP(zip((0..<5).map { "Onde.app/\($0)" }, size: 400_000_000)))
        let valid = zip(["Onde.app/file"])
        for length in [0, 1, 21, 30, valid.count - 1] {
            XCTAssertThrowsError(try UpdateInstallation.validateZIP(Data(valid.prefix(length))))
        }
    }
    func testRehashesAndRejectsChangedArchives() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("onde-hash-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("update.zip"), data = Data("original".utf8)
        try data.write(to: file)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try UpdateInstallation.verifyArchive(file, bytes: Int64(data.count), sha256: hash)
        XCTAssertThrowsError(try UpdateInstallation.verifyArchive(file, bytes: 1, sha256: hash))
        try Data("modified".utf8).write(to: file)
        XCTAssertThrowsError(try UpdateInstallation.verifyArchive(file, bytes: Int64(data.count), sha256: hash))
        let link = root.appendingPathComponent("link.zip")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try UpdateInstallation.verifyArchive(link, bytes: 8, sha256: hash))
    }
    func testAtomicReplacementCanBeRolledBackWithoutDataLoss() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("onde-swap-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("Installed.app"), new = root.appendingPathComponent("New.app")
        for app in [old, new] { try FileManager.default.createDirectory(at: app, withIntermediateDirectories: false) }
        try Data("old".utf8).write(to: old.appendingPathComponent("identity"))
        try Data("new".utf8).write(to: new.appendingPathComponent("identity"))
        try UpdateInstallation.exchange(old, new)
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("identity")), "new")
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("identity")), "old")
        try UpdateInstallation.exchange(old, new)
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("identity")), "old")
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("identity")), "new")
    }
    func testFailedExchangeDoesNotRemoveInstalledApplication() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("onde-unchanged-\(UUID().uuidString)")
        try Data("preserved".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try UpdateInstallation.exchange(file, file.appendingPathExtension("missing")))
        XCTAssertEqual(try String(contentsOf: file), "preserved")
    }
    func testRejectsInstallingOverArbitraryLocations() {
        XCTAssertThrowsError(try UpdateInstallation.validateTarget(URL(fileURLWithPath: "/tmp/Onde.app"))))
        XCTAssertThrowsError(try UpdateInstallation.validateTarget(URL(fileURLWithPath: "/Volumes/Test/Onde.app"))))
    }
}
#endif
