#if os(macOS)
import XCTest
import AppKit
import CryptoKit
@testable import OndeCore

/// Exercises the production SwiftUI application's acknowledgement and normal shutdown,
/// using a private, muted profile and a uniquely named copy. No installation bypass.
final class UpdatePackagedTests: XCTestCase {
    func testPackagedAppRelaunchesAndPreservesLibrary() throws {
        guard let package = ProcessInfo.processInfo.environment["ONDE_PACKAGED_APPLICATION"] else {
            throw XCTSkip("Runs after packaging in macOS validation and release jobs.")
        }
        let fm = FileManager.default
        let token = UUID().uuidString
        let root = URL(fileURLWithPath: "/private/tmp/ou-\(token.prefix(8))", isDirectory: true)
        let home = root.appendingPathComponent("p", isDirectory: true)
        let applications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").resolvingSymlinksInPath()
        try fm.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try fm.createDirectory(at: home, withIntermediateDirectories: false)
        try fm.createDirectory(at: applications, withIntermediateDirectories: true)
        let target = applications.appendingPathComponent("Onde Packaged Update Test \(token).app")
        var transaction: URL?
        let environment = ProcessInfo.processInfo.environment.merging(["ONDE_HOME": home.path]) { _, new in new }
        func command(_ path: String, _ args: [String]) throws -> Data {
            let process = Process(), pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = FileHandle.standardError
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw OndeError("package_test", "Command failed: \(path) \(args)") }
            return data
        }
        func wait(_ label: String, timeout: TimeInterval = 45, until test: () -> Bool) throws {
            let deadline = Date().addingTimeInterval(timeout)
            while !test(), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
            guard test() else { throw OndeError("package_test", label) }
        }
        defer {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: "app.onde.mac") where app.bundleURL?.standardizedFileURL.path == target.path { _ = app.terminate() }
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
            if let transaction { try? fm.removeItem(at: transaction) }
            try? fm.removeItem(at: target)
            try? fm.removeItem(at: root)
        }
        let packageURL = URL(fileURLWithPath: package).standardizedFileURL
        let newBuild = try UpdateInstallation.installedBuild(at: packageURL)
        XCTAssertGreaterThan(newBuild, 1)
        try fm.copyItem(at: packageURL, to: target)
        let infoURL = target.appendingPathComponent("Contents/Info.plist")
        var info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as? [String: Any])
        let commit = try XCTUnwrap(info["OndeCommit"] as? String)
        info["OndeBuild"] = String(newBuild - 1)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        _ = try command("/usr/bin/codesign", ["--force", "--sign", "-", target.path])
        var state = StoredState()
        state.preferences.masterVolume = 0
        state.preferences.preventSleep = false
        state.preferences.chimesEnabled = false
        state.preferences.startFadeSeconds = 3
        state.mixes = [Mix(name: "Preserved personal soundscape", mode: .relax, layers: [:])]
        state.history = [SessionRecord(date: Date(timeIntervalSince1970: 1_700_000_000), mode: .focus, seconds: 123)]
        let stateURL = home.appendingPathComponent("state.json")
        try JSONEncoder().encode(state).write(to: stateURL)
        let imports = home.appendingPathComponent("Imports")
        try fm.createDirectory(at: imports, withIntermediateDirectories: false)
        let importData = Data("Do not change this private import.".utf8)
        try importData.write(to: imports.appendingPathComponent("preserved.txt"))
        let initial = Process()
        initial.executableURL = target.appendingPathComponent("Contents/MacOS/Onde")
        initial.environment = environment
        initial.standardOutput = FileHandle.nullDevice
        initial.standardError = FileHandle.nullDevice
        try initial.run()
        try wait("The packaged app did not become ready") { fm.fileExists(atPath: home.appendingPathComponent("control.sock").path) }
        let cli = target.appendingPathComponent("Contents/MacOS/ondectl").path
        _ = try command(cli, ["status"])
        let archive = root.appendingPathComponent("update.zip")
        _ = try command("/usr/bin/ditto", ["-c", "-k", "--keepParent", "--norsrc", packageURL.path, archive.path])
        let bytes = try Data(contentsOf: archive)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let update = VerifiedUpdate(title: "Actual packaged application", tag: "build-\(newBuild)-\(commit.prefix(8))", build: newBuild,
            commit: commit, url: URL(string: "https://github.com/blancmathis/onde")!, bytes: Int64(bytes.count), sha256: hash)
        let directory = try UpdateInstallation.prepare(archive: archive, update: update, target: target, parentPID: initial.processIdentifier)
        transaction = directory
        let child = Process()
        child.executableURL = directory.appendingPathComponent(UpdateInstallation.helperName)
        child.arguments = ["--transaction", directory.path]
        child.environment = environment
        try child.run()
        try wait("The packaged installer did not become ready") { UpdateInstallation.state(in: directory) == "ready" || !child.isRunning }
        XCTAssertEqual(UpdateInstallation.state(in: directory), "ready")
        let plan = try UpdateInstallation.loadPlan(directory)
        try Data(plan.token.utf8).write(to: directory.appendingPathComponent("authorize.txt"), options: .atomic)
        // The same public command runs AppModel.shutdown; no forced process termination.
        _ = try command(cli, ["quit"])
        try wait("The original app did not quit") { !initial.isRunning }
        try wait("The packaged update did not finish", timeout: 70) { !child.isRunning }
        XCTAssertEqual(UpdateInstallation.state(in: directory), "success")
        XCTAssertEqual(try UpdateInstallation.installedBuild(at: target), newBuild)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("ack.txt")), plan.token)
        try wait("The relaunched production app did not open its private profile") { fm.fileExists(atPath: home.appendingPathComponent("control.sock").path) }
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: command(cli, ["update", "status"])) as? [String: Any])
        let result = try XCTUnwrap(response["result"] as? [String: Any])
        XCTAssertEqual((result["current_build"] as? NSNumber)?.uint64Value, newBuild)
        XCTAssertEqual(result["current_commit"] as? String, commit)
        let preserved = try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: stateURL))
        XCTAssertEqual(preserved.preferences.masterVolume, 0)
        XCTAssertEqual(preserved.preferences.startFadeSeconds, 3)
        XCTAssertFalse(preserved.preferences.chimesEnabled)
        XCTAssertEqual(preserved.mixes.map(\.name), state.mixes.map(\.name))
        XCTAssertEqual(preserved.history.map(\.seconds), [123])
        XCTAssertEqual(try Data(contentsOf: imports.appendingPathComponent("preserved.txt")), importData)
        _ = try command(cli, ["quit"])
        _ = try command("/usr/bin/codesign", ["--verify", "--deep", "--strict", target.path])
    }
}
#endif
