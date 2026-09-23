import Foundation
import AppKit
import CryptoKit
import OndeCore

/// Downloads remain opt-in. Only the separately confirmed installer can replace the app.
final class UpdateManager: ObservableObject {
    @Published private(set) var checking = false
    @Published private(set) var downloading = false
    @Published private(set) var verifying = false
    @Published private(set) var available = false
    @Published private(set) var candidate: VerifiedUpdate?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var error: String?
    @Published private(set) var downloadedPath: String?
    @Published private(set) var downloadProgress: Double?
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var expectedDownloadBytes: Int64 = 0
    @Published var automatic: Bool {
        didSet { if !isolated { UserDefaults.standard.set(automatic, forKey: "OndeAutomaticUpdates") } }
    }

    private let isolated: Bool
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private let session: URLSession
    private let metadataSession: URLSession
    private var downloadTask: URLSessionDownloadTask?
    private var progressTimer: Timer?
    private var downloadSerial: UInt64 = 0
    private var downloadedBuild: UInt64?

    init(metadataConfiguration: URLSessionConfiguration = UpdateMetadataPolicy.configuration()) {
        metadataSession = URLSession(configuration: metadataConfiguration)
        isolated = ProcessInfo.processInfo.environment["ONDE_HOME"] != nil
        automatic = !isolated && (UserDefaults.standard.object(forKey: "OndeAutomaticUpdates") as? Bool ?? true)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = UpdateTransferPolicy.requestTimeout
        config.timeoutIntervalForResource = UpdateTransferPolicy.resourceTimeout
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: config)
        guard !isolated else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.checkIfNeeded() }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.checkIfNeeded() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.checkIfNeeded() }
    }

    deinit {
        timer?.invalidate()
        progressTimer?.invalidate()
        downloadTask?.cancel()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        session.invalidateAndCancel()
        metadataSession.invalidateAndCancel()
    }

    private func checkIfNeeded() {
        guard automatic, lastChecked.map({ Date().timeIntervalSince($0) > 240 }) ?? true else { return }
        check()
    }

    func check() {
        guard !checking, !downloading, !UpdateInstallationController.shared.busy else { return }
        checking = true
        error = nil
        var request = URLRequest(url: UpdatePolicy.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Onde/\(AppBuild.version)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await self.metadataSession.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw OndeError("invalid_response", "Invalid response from GitHub.") }
                if http.statusCode == 404 {
                    await MainActor.run {
                        self.candidate = nil
                        self.available = false
                        self.clearReadyDownload()
                        self.error = "No downloadable release has been published yet."
                        self.checking = false
                        self.lastChecked = Date()
                    }
                    return
                }
                guard http.statusCode == 200 else { throw OndeError("update_http", "GitHub returned HTTP \(http.statusCode). Try again later.") }
                guard data.count <= 2_000_000 else { throw OndeError("oversized_response", "The update response is too large.") }
                let release = try JSONDecoder().decode(PublicRelease.self, from: data)
                let verified = try UpdatePolicy.parse(release)
                await MainActor.run {
                    if let downloadedBuild = self.downloadedBuild, downloadedBuild != verified.build { self.clearReadyDownload() }
                    self.candidate = verified
                    self.available = UpdatePolicy.isNewer(verified, than: AppBuild.number)
                    if self.available { self.restoreReadyDownload(for: verified) }
                    else { self.clearReadyDownload() }
                    self.lastChecked = Date()
                    self.checking = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.error = UpdateMetadataPolicy.message(for: error)
                    self.checking = false
                    self.lastChecked = Date()
                }
            }
        }
    }

    // Reuse a completed download only for the exact release returned by GitHub.
    // The installer rehashes a private copy before extraction or execution.
    private func restoreReadyDownload(for update: VerifiedUpdate) {
        guard downloadedPath == nil, !isolated,
              UserDefaults.standard.string(forKey: "OndeReadyUpdateBuild") == String(update.build),
              UserDefaults.standard.string(forKey: "OndeReadyUpdateSHA256") == update.sha256,
              let path = UserDefaults.standard.string(forKey: "OndeReadyUpdatePath"),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.deletingLastPathComponent().path == downloads.standardizedFileURL.path,
              url.lastPathComponent.hasPrefix("Onde-\(update.tag)"), url.pathExtension == "zip",
              url.resolvingSymlinksInPath().path == url.path, FileManager.default.fileExists(atPath: url.path) else {
            clearReadyDownload(); return
        }
        downloadedPath = url.path
        downloadedBuild = update.build
    }

    private func clearReadyDownload() {
        downloadedPath = nil
        downloadedBuild = nil
        if !isolated {
            for key in ["OndeReadyUpdatePath", "OndeReadyUpdateBuild", "OndeReadyUpdateSHA256"] { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    func download() {
        guard !checking, !downloading, !UpdateInstallationController.shared.busy,
              let update = candidate, UpdatePolicy.isNewer(update, than: AppBuild.number) else { return }
        // A finished download is an installation candidate, not a reason to download again.
        if let path = downloadedPath, downloadedBuild == update.build, FileManager.default.fileExists(atPath: path) { return }
        downloadSerial &+= 1
        let serial = downloadSerial
        progressTimer?.invalidate()
        downloadTask?.cancel()
        clearReadyDownload()
        downloading = true
        verifying = false
        downloadProgress = 0
        downloadedBytes = 0
        expectedDownloadBytes = update.bytes
        error = nil

        var request = URLRequest(url: update.url)
        request.setValue("Onde/\(AppBuild.version)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = session.downloadTask(with: request) { [weak self] location, response, taskError in
            guard let self else { return }
            if let taskError { self.finishFailure(taskError, serial: serial); return }
            guard let location, let http = response as? HTTPURLResponse,
                  http.statusCode == 200, response?.url?.scheme == "https" else {
                self.finishFailure(OndeError("download_failed", "The download from GitHub failed."), serial: serial)
                return
            }
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("Onde-update-\(UUID().uuidString).zip")
            do { try FileManager.default.moveItem(at: location, to: staging) }
            catch { self.finishFailure(error, serial: serial); return }
            DispatchQueue.main.async {
                guard self.downloadSerial == serial else { try? FileManager.default.removeItem(at: staging); return }
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                self.downloadTask = nil
                self.downloadedBytes = update.bytes
                self.downloadProgress = 1
                self.verifying = true
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self else { try? FileManager.default.removeItem(at: staging); return }
                    do {
                        let completed = try self.verifyAndStore(staging, update: update)
                        DispatchQueue.main.async {
                            guard self.downloadSerial == serial else { try? FileManager.default.removeItem(at: completed); return }
                            self.downloadedPath = completed.path
                            self.downloadedBuild = update.build
                            if !self.isolated {
                                UserDefaults.standard.set(completed.path, forKey: "OndeReadyUpdatePath")
                                UserDefaults.standard.set(String(update.build), forKey: "OndeReadyUpdateBuild")
                                UserDefaults.standard.set(update.sha256, forKey: "OndeReadyUpdateSHA256")
                            }
                            self.downloading = false
                            self.verifying = false
                            self.downloadProgress = nil
                            self.downloadedBytes = 0
                            self.expectedDownloadBytes = 0
                            self.error = nil
                        }
                    } catch { self.finishFailure(error, serial: serial) }
                }
            }
        }
        downloadTask = task
        startProgressMonitor(task, expected: update.bytes, serial: serial)
        task.resume()
    }

    func downloadAgain() {
        guard !checking, !downloading, !UpdateInstallationController.shared.busy else { return }
        clearReadyDownload()
        download()
    }

    func cancelDownload() {
        guard downloading, !verifying else { return }
        downloadSerial &+= 1
        downloadTask?.cancel()
        downloadTask = nil
        progressTimer?.invalidate()
        progressTimer = nil
        downloading = false
        verifying = false
        downloadProgress = nil
        downloadedBytes = 0
        expectedDownloadBytes = 0
        error = nil
    }

    private func startProgressMonitor(_ task: URLSessionDownloadTask, expected: Int64, serial: UInt64) {
        let timer = Timer(timeInterval: UpdateTransferPolicy.progressInterval, repeats: true) { [weak self, weak task] timer in
            guard let self, let task, self.downloadSerial == serial, self.downloading, !self.verifying else { timer.invalidate(); return }
            let received = max(0, task.countOfBytesReceived)
            self.downloadedBytes = received
            self.downloadProgress = UpdateTransferPolicy.progress(received: received, expected: expected)
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func verifyAndStore(_ temporary: URL, update: VerifiedUpdate) throws -> URL {
        defer { try? FileManager.default.removeItem(at: temporary) }
        try UpdateInstallation.verifyArchive(temporary, bytes: update.bytes, sha256: update.sha256)
        let directory: URL
        if isolated { directory = OndePaths.support.appendingPathComponent("Downloads", isDirectory: true) }
        else {
            guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { throw OndeError("download_folder", "The Downloads folder is unavailable.") }
            directory = downloads
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent("Onde-\(update.tag).zip")
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("Onde-\(update.tag)-\(index).zip")
            index += 1
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private func finishFailure(_ failure: Error, serial: UInt64) {
        DispatchQueue.main.async {
            guard self.downloadSerial == serial else { return }
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            self.downloadTask = nil
            self.downloading = false
            self.verifying = false
            self.downloadProgress = nil
            self.downloadedBytes = 0
            self.expectedDownloadBytes = 0
            self.error = UpdateTransferPolicy.message(for: failure)
        }
    }

    func reveal() {
        if let path = downloadedPath { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
    }
    func openDownloadInBrowser() { if let update = candidate { NSWorkspace.shared.open(update.url) } }

    func snapshot() -> [String: Any] {
        ["repository": AppBuild.repository, "current_version": AppBuild.version, "current_build": AppBuild.number,
         "current_commit": AppBuild.commit, "checking": checking, "downloading": downloading,
         "verifying": verifying, "download_progress": downloadProgress as Any? ?? NSNull(),
         "downloaded_bytes": downloadedBytes, "expected_download_bytes": expectedDownloadBytes,
         "update_available": available, "automatic": automatic, "check_interval_seconds": 300,
         "latest_tag": candidate?.tag as Any? ?? NSNull(), "latest_title": candidate?.title as Any? ?? NSNull(),
         "download_url": candidate?.url.absoluteString as Any? ?? NSNull(),
         "expected_sha256": candidate?.sha256 as Any? ?? NSNull(),
         "downloaded_path": downloadedPath as Any? ?? NSNull(),
         "last_checked": lastChecked.map { ISO8601DateFormatter().string(from: $0) } as Any? ?? NSNull(),
         "error": error as Any? ?? NSNull(), "automatic_installation": false,
         "installing": UpdateInstallationController.shared.busy,
         "installation_error": UpdateInstallationController.shared.error as Any? ?? NSNull(),
         "installation_requires_confirmation": true]
    }
}
