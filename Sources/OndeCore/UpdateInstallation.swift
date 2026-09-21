// User-approved, unprivileged updates. No launch agent, shell interpolation or security overrides.
#if os(macOS)
import Foundation
import AppKit
import CryptoKit
import Security
import Darwin

public struct UpdateInstallPlan: Codable {
    public let token: String
    public let target: String
    public let parentPID: Int32
    public let oldBuild: UInt64
    public let build: UInt64
    public let commit: String
    public let created: Date
    public let device: UInt64
    public let inode: UInt64
}

public enum UpdateInstallation {
    public static let helperName = "onde-updater"
    private static let fm = FileManager.default
    private static func failure(_ message: String) -> Error { OndeError("update_install", message) }

    public static func installedBuild(at app: URL) throws -> UInt64 {
        let info = try metadata(app)
        guard let text = info["OndeBuild"] as? String, let build = UInt64(text), build > 0 else {
            throw failure("The installed app has no valid build identity. Install the official Onde.app first.")
        }
        return build
    }

    private static func metadata(_ app: URL) throws -> [String: Any] {
        let url = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: url)
        guard data.count < 100_000,
              let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == "app.onde.mac",
              info["CFBundleExecutable"] as? String == "Onde",
              info["OndeRepository"] as? String == AppBuild.repository else {
            throw failure("This bundle is not an official Onde application.")
        }
        return info
    }

    public static func validateTarget(_ app: URL) throws {
        let target = app.standardizedFileURL
        let parent = target.deletingLastPathComponent()
        let allowed = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
            .map { $0.resolvingSymlinksInPath().standardizedFileURL.path }
        guard target.pathExtension == "app", target.resolvingSymlinksInPath().path == target.path,
              allowed.contains(parent.path), fm.isWritableFile(atPath: parent.path),
              fm.isWritableFile(atPath: target.path) else {
            throw failure("Move Onde.app to a writable Applications folder, open that copy, then retry. The app cannot update from a disk image, Downloads or a read-only folder.")
        }
        _ = try metadata(target)
        try validateTree(target)
    }

    private static func validateTree(_ root: URL) throws {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey]
        var scanError: Error?
        guard let iterator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, error in scanError = error; return false }) else {
            throw failure("The application bundle could not be inspected.")
        }
        for case let item as URL in iterator {
            let values = try item.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else {
                throw failure("The update contains an unsupported link or special file.")
            }
            let attrs = try fm.attributesOfItem(atPath: item.path)
            let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
            guard mode & 0o6000 == 0 else { throw failure("Privileged files are not permitted in an update.") }
            if values.isRegularFile == true, (attrs[.referenceCount] as? NSNumber)?.intValue ?? 1 > 1 {
                throw failure("Hard-linked update files are not supported.")
            }
        }
        if let scanError { throw scanError }
    }

    @discardableResult private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw failure("Update validation failed (\(URL(fileURLWithPath: executable).lastPathComponent)). \(String(decoding: data.prefix(1500), as: UTF8.self))")
        }
        return data
    }

    private static func team(_ app: URL) throws -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else {
            throw failure("The app's code signature could not be read.")
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess else {
            throw failure("The app's signing identity could not be inspected.")
        }
        return (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private static func validateBundle(_ app: URL, build: UInt64, commit: String? = nil) throws {
        guard app.resolvingSymlinksInPath().path == app.standardizedFileURL.path else { throw failure("An update bundle cannot be a symbolic link.") }
        let info = try metadata(app)
        guard try installedBuild(at: app) == build, commit == nil || info["OndeCommit"] as? String == commit else {
            throw failure("The app inside the archive does not match the published build and commit.")
        }
        if let minimum = info["LSMinimumSystemVersion"] as? String {
            let parts = minimum.split(separator: ".").compactMap { Int($0) }
            guard !parts.isEmpty, parts.count <= 3,
                  ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: parts[0], minorVersion: parts.count > 1 ? parts[1] : 0, patchVersion: parts.count > 2 ? parts[2] : 0)) else {
                throw failure("This update requires a newer version of macOS.")
            }
        }
        try validateTree(app)
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        try run("/usr/bin/lipo", [app.appendingPathComponent("Contents/MacOS/Onde").path, "-verify_arch", architecture])
    }

    public static func verifyArchive(_ url: URL, bytes: Int64, sha256: String) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == bytes, (1...400_000_000).contains(bytes),
              sha256.count == 64, sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw failure("The downloaded archive is missing, changed, or has the wrong size. Download it again.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == sha256 else {
            throw failure("SHA-256 verification failed. The installed app has not been changed.")
        }
    }

    public static func validateZIP(_ data: Data) throws { try UpdateArchiveValidation.validate(data) }

    public static func prepare(archive: URL, update: VerifiedUpdate, target: URL, parentPID: Int32) throws -> URL {
        try validateTarget(target)
        let oldBuild = try installedBuild(at: target)
        guard update.build > oldBuild else { throw failure("This update is not newer than the installed app.") }
        try validateBundle(target, build: oldBuild)
        let token = UUID().uuidString
        let directory = target.deletingLastPathComponent().appendingPathComponent(".Onde-Update-\(token)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var prepared = false
        defer { if !prepared { try? fm.removeItem(at: directory) } }
        let privateArchive = directory.appendingPathComponent("archive.zip")
        try fm.copyItem(at: archive, to: privateArchive)
        try verifyArchive(privateArchive, bytes: update.bytes, sha256: update.sha256)
        try validateZIP(Data(contentsOf: privateArchive, options: .mappedIfSafe))
        let payload = directory.appendingPathComponent("Payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try run("/usr/bin/ditto", ["-x", "-k", privateArchive.path, payload.path])
        let incoming = payload.appendingPathComponent("Onde.app")
        try validateBundle(incoming, build: update.build, commit: update.commit)
        if let currentTeam = try team(target), try team(incoming) != currentTeam {
            throw failure("The update changes the app's signing identity. The installed app was left untouched.")
        }
        let sourceHelper = target.appendingPathComponent("Contents/MacOS/\(helperName)")
        guard fm.isExecutableFile(atPath: sourceHelper.path) else { throw failure("This older app requires one manual installation before in-app installation becomes available.") }
        let helper = directory.appendingPathComponent(helperName)
        try fm.copyItem(at: sourceHelper, to: helper)
        try run("/usr/bin/codesign", ["--verify", "--strict", helper.path])
        let attrs = try fm.attributesOfItem(atPath: target.path)
        let plan = UpdateInstallPlan(token: token, target: target.path, parentPID: parentPID, oldBuild: oldBuild,
            build: update.build, commit: update.commit, created: Date(),
            device: (attrs[.systemNumber] as? NSNumber)?.uint64Value ?? 0,
            inode: (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0)
        try JSONEncoder().encode(plan).write(to: directory.appendingPathComponent("plan.json"), options: .atomic)
        try fm.removeItem(at: privateArchive)
        prepared = true
        return directory
    }

    public static func loadPlan(_ directory: URL) throws -> UpdateInstallPlan {
        let attrs = try fm.attributesOfItem(atPath: directory.path)
        guard attrs[.type] as? FileAttributeType == .typeDirectory,
              (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == geteuid(),
              ((attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0) & 0o077 == 0,
              directory.standardizedFileURL.path == directory.resolvingSymlinksInPath().path else {
            throw failure("The update transaction directory is not private.")
        }
        let data = try Data(contentsOf: directory.appendingPathComponent("plan.json"))
        guard data.count < 16_000 else { throw failure("The update transaction is invalid.") }
        let plan = try JSONDecoder().decode(UpdateInstallPlan.self, from: data)
        let target = URL(fileURLWithPath: plan.target)
        guard UUID(uuidString: plan.token) != nil, directory.lastPathComponent == ".Onde-Update-\(plan.token)",
              directory.deletingLastPathComponent().path == target.deletingLastPathComponent().path,
              plan.parentPID > 1, plan.build > plan.oldBuild, plan.commit.count == 40,
              plan.commit.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw failure("The update transaction identity is invalid.") }
        try validateTarget(target)
        return plan
    }

    public static func writeState(_ state: String, in directory: URL) throws {
        try Data(state.utf8).write(to: directory.appendingPathComponent("state.txt"), options: .atomic)
    }
    public static func state(in directory: URL) -> String? { try? String(contentsOf: directory.appendingPathComponent("state.txt"), encoding: .utf8) }

    public static func acknowledgeLaunch(arguments: [String], bundle: Bundle = .main) {
        guard let index = arguments.firstIndex(of: "--onde-update-transaction"), arguments.indices.contains(index + 1) else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1])
        guard let plan = try? loadPlan(directory), bundle.bundleURL.standardizedFileURL.path == plan.target,
              (try? installedBuild(at: bundle.bundleURL)) == plan.build,
              bundle.infoDictionary?["OndeCommit"] as? String == plan.commit else { return }
        try? Data(plan.token.utf8).write(to: directory.appendingPathComponent("ack.txt"), options: .atomic)
    }

    /// Atomic directory exchange keeps the previous application available for rollback.
    /// No delete-then-copy window, elevated privilege or persistent background process.
    public static func exchange(_ first: URL, _ second: URL) throws {
        guard renamex_np(first.path, second.path, UInt32(RENAME_SWAP)) == 0 else {
            throw failure("macOS could not replace the app safely (\(String(cString: strerror(errno)))). The previous app is preserved.")
        }
    }

    public static func runHelper(directory: URL) throws {
        let plan = try loadPlan(directory)
        guard abs(plan.created.timeIntervalSinceNow) < 300 else { throw failure("This update request expired. Retry from Onde.") }
        let target = URL(fileURLWithPath: plan.target)
        let incoming = directory.appendingPathComponent("Payload/Onde.app")
        guard let parent = NSRunningApplication(processIdentifier: plan.parentPID),
              parent.bundleURL?.standardizedFileURL.path == target.path else { throw failure("The requesting Onde process is no longer running.") }
        try validateBundle(incoming, build: plan.build, commit: plan.commit)
        // Kernel exit notification, not AppKit's run-loop-cached isTerminated flag.
        let parentExited = DispatchSemaphore(value: 0)
        let exitSource = DispatchSource.makeProcessSource(identifier: plan.parentPID, eventMask: .exit, queue: .global(qos: .utility))
        exitSource.setEventHandler { parentExited.signal() }
        exitSource.activate()
        defer { exitSource.cancel() }
        try writeState("ready", in: directory)
        guard parentExited.wait(timeout: .now() + 60) == .success else {
            throw failure("Onde did not quit. The update was cancelled and your app was not changed.")
        }
        guard try String(contentsOf: directory.appendingPathComponent("authorize.txt"), encoding: .utf8) == plan.token else {
            throw failure("The installation was not authorized.")
        }
        let attrs = try fm.attributesOfItem(atPath: target.path)
        guard (attrs[.systemNumber] as? NSNumber)?.uint64Value == plan.device,
              (attrs[.systemFileNumber] as? NSNumber)?.uint64Value == plan.inode,
              try installedBuild(at: target) == plan.oldBuild else { throw failure("The installed app changed while preparing this update. It was not overwritten.") }
        try validateBundle(target, build: plan.oldBuild)
        try validateBundle(incoming, build: plan.build, commit: plan.commit)
        if let currentTeam = try team(target), try team(incoming) != currentTeam { throw failure("The signing identity changed.") }
        try writeState("installing", in: directory)
        try exchange(target, incoming)
        var launched: NSRunningApplication?
        do {
            launched = try launch(target, transaction: directory)
            let launchDeadline = Date().addingTimeInterval(30)
            while Date() < launchDeadline {
                if (try? String(contentsOf: directory.appendingPathComponent("ack.txt"), encoding: .utf8)) == plan.token {
                    try writeState("success", in: directory)
                    return
                }
                if launched?.isTerminated == true { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
            throw failure("The new app did not confirm that it opened.")
        } catch {
            // Never move or force-kill a new app that is still running. Keep its backup.
            if (launched.map { !$0.isTerminated } ?? false) || NSRunningApplication.runningApplications(withBundleIdentifier: "app.onde.mac").contains(where: { !$0.isTerminated && $0.bundleURL?.standardizedFileURL.path == target.path }) {
                throw failure("The new app opened without confirming completion. Its previous version is preserved at \(incoming.path). Quit and reopen Onde, then review Updates.")
            }
            try exchange(target, incoming)
            try writeState("error: The new version could not open. The previous version has been restored. \(error.localizedDescription)", in: directory)
            _ = try? launch(target, transaction: nil)
            return
        }
    }

    private static func launch(_ target: URL, transaction: URL?) throws -> NSRunningApplication {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        if let transaction { config.arguments = ["--onde-update-transaction", transaction.path] }
        // Preserve only the explicit isolated-test profile, not arbitrary launch variables.
        if let home = ProcessInfo.processInfo.environment["ONDE_HOME"] { config.environment = ["ONDE_HOME": home] }
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSRunningApplication?, problem: Error?
        NSWorkspace.shared.openApplication(at: target, configuration: config) { app, error in
            result = app; problem = error; semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 30) == .success else { throw failure("macOS did not respond to the request to reopen Onde.") }
        if let problem { throw problem }
        guard let result else { throw failure("macOS could not reopen Onde.") }
        return result
    }
}
#endif
