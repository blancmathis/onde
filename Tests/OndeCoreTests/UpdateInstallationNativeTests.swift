#if os(macOS)
import XCTest
import AppKit
import CryptoKit
@testable import OndeCore

final class UpdateInstallationNativeTests: XCTestCase {
    private let fm = FileManager.default
    private var repository: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func command(_ path: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "NativeUpdateTest", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed: \(path) \(args)"]) }
    }
    private func wait(_ message: String, timeout: TimeInterval = 40, until condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        guard condition() else { throw NSError(domain: "NativeUpdateTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    private func runTransaction(crashing: Bool) throws {
        guard ProcessInfo.processInfo.environment["ONDE_RUN_INSTALLATION_INTEGRATION"] == "1" else {
            throw XCTSkip("Opt-in native process tests run in the isolated update-validation job.")
        }
        let helper = try XCTUnwrap(ProcessInfo.processInfo.environment["ONDE_UPDATE_HELPER_PATH"])
        XCTAssertTrue(fm.isExecutableFile(atPath: helper))
        let token = UUID().uuidString
        let work = fm.temporaryDirectory.appendingPathComponent("onde-update-test-\(token)").resolvingSymlinksInPath()
        let applications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").resolvingSymlinksInPath()
        try fm.createDirectory(at: applications, withIntermediateDirectories: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: false)
        let installed = applications.appendingPathComponent("Onde Update Fixture \(token).app")
        var transaction: URL?
        defer {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: "app.onde.mac") where app.bundleURL?.standardizedFileURL.path == installed.path { _ = app.terminate() }
            let end = Date().addingTimeInterval(3)
            while Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
            if let transaction { try? fm.removeItem(at: transaction) }
            try? fm.removeItem(at: installed)
            try? fm.removeItem(at: work)
        }
        let binary = work.appendingPathComponent("Fixture")
        try command("/usr/bin/xcrun", ["swiftc", repository.appendingPathComponent("Tools/UpdateFixture.swift").path, "-o", binary.path])
        let incoming = work.appendingPathComponent("Next/Onde.app")
        let commit = String(repeating: "a", count: 40)
        func bundle(_ app: URL, build: String, behavior: String) throws {
            try fm.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
            try fm.copyItem(at: binary, to: app.appendingPathComponent("Contents/MacOS/Onde"))
            try fm.copyItem(at: URL(fileURLWithPath: helper), to: app.appendingPathComponent("Contents/MacOS/onde-updater"))
            let info: [String: Any] = ["CFBundleIdentifier":"app.onde.mac", "CFBundleExecutable":"Onde", "CFBundleName":"Onde",
                "CFBundlePackageType":"APPL", "CFBundleShortVersionString":"1.11.4", "CFBundleVersion":"1.11.4",
                "OndeRepository":AppBuild.repository, "OndeBuild":build, "OndeCommit":commit,
                "LSMinimumSystemVersion":"14.0", "NSPrincipalClass":"NSApplication", "OndeFixtureBehavior":behavior]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
            try command("/usr/bin/codesign", ["--force", "--sign", "-", app.appendingPathComponent("Contents/MacOS/onde-updater").path])
            try command("/usr/bin/codesign", ["--force", "--sign", "-", app.appendingPathComponent("Contents/MacOS/Onde").path])
            try command("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        }
        try bundle(installed, build: "20260921000001", behavior: "normal")
        try bundle(incoming, build: "20260921000002", behavior: crashing ? "crash" : "normal")
        let personal = work.appendingPathComponent("personal-library.json")
        let preserved = Data("synthetic settings, imports, mixes and history".utf8)
        try preserved.write(to: personal)
        let archive = work.appendingPathComponent("update.zip")
        try command("/usr/bin/ditto", ["-c", "-k", "--keepParent", "--norsrc", incoming.path, archive.path])
        let bytes = try Data(contentsOf: archive)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let update = VerifiedUpdate(title: "Synthetic test update", tag: "build-20260921000002-aaaaaaaa", build: 20260921000002,
            commit: commit, url: URL(string:"https://github.com/blancmathis/onde/releases/download/build-20260921000002-aaaaaaaa/Onde-macOS-universal.zip")!, bytes: Int64(bytes.count), sha256: digest)
        let pidFile = work.appendingPathComponent("old.pid")
        try command("/usr/bin/open", ["-n", installed.path, "--args", "--pid-file", pidFile.path])
        try wait("The old synthetic app did not launch") { self.fm.fileExists(atPath: pidFile.path) }
        let pid = try XCTUnwrap(Int32(String(contentsOf: pidFile)))
        let old = try XCTUnwrap(NSRunningApplication(processIdentifier: pid))
        let directory = try UpdateInstallation.prepare(archive: archive, update: update, target: installed, parentPID: pid)
        transaction = directory
        let child = Process()
        child.executableURL = directory.appendingPathComponent(UpdateInstallation.helperName)
        child.arguments = ["--transaction", directory.path]
        try child.run()
        try wait("The installer did not become ready: \(UpdateInstallation.state(in: directory) ?? "no state")") {
            UpdateInstallation.state(in: directory) == "ready" || !child.isRunning
        }
        XCTAssertEqual(UpdateInstallation.state(in: directory), "ready")
        // Merely downloading/preparing and launching the helper cannot replace an open app.
        XCTAssertEqual(try UpdateInstallation.installedBuild(at: installed), 20260921000001)
        let plan = try UpdateInstallation.loadPlan(directory)
        try Data(plan.token.utf8).write(to: directory.appendingPathComponent("authorize.txt"), options: .atomic)
        XCTAssertTrue(old.terminate())
        try wait("The native update transaction did not finish") { !child.isRunning }
        let state = try XCTUnwrap(UpdateInstallation.state(in: directory))
        if crashing {
            XCTAssertTrue(state.hasPrefix("error:"), state)
            XCTAssertEqual(try UpdateInstallation.installedBuild(at: installed), 20260921000001)
        } else {
            XCTAssertEqual(state, "success")
            XCTAssertEqual(try UpdateInstallation.installedBuild(at: installed), 20260921000002)
            XCTAssertEqual(try UpdateInstallation.installedBuild(at: directory.appendingPathComponent("Payload/Onde.app")), 20260921000001)
        }
        XCTAssertEqual(try Data(contentsOf: personal), preserved)
        XCTAssertTrue(fm.fileExists(atPath: archive.path), "Keep the user's verified download")
        try command("/usr/bin/codesign", ["--verify", "--deep", "--strict", installed.path])
        try wait("Onde was not reopened at its original location", timeout: 10) {
            NSRunningApplication.runningApplications(withBundleIdentifier: "app.onde.mac").contains { !$0.isTerminated && $0.bundleURL?.standardizedFileURL.path == installed.path }
        }
    }
    func testNativeSuccessfulInstallAndRelaunch() throws { try runTransaction(crashing: false) }
    func testNativeFailedLaunchRestoresPreviousApp() throws { try runTransaction(crashing: true) }
    func testPackagedUpdateArchiveIsAccepted() throws {
        guard let path = ProcessInfo.processInfo.environment["ONDE_PACKAGED_UPDATE_ARCHIVE"] else { throw XCTSkip("Release-only package validation") }
        try UpdateInstallation.validateZIP(Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe))
    }
}
#endif
