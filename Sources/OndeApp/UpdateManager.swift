import Foundation
import AppKit
import CryptoKit
import OndeCore

/// Downloads are opt-in, verified, and never executed or installed by this class.
final class UpdateManager: ObservableObject {
    @Published private(set) var checking = false
    @Published private(set) var downloading = false
    @Published private(set) var available = false
    @Published private(set) var candidate: VerifiedUpdate?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var error: String?
    @Published private(set) var downloadedPath: String?
    @Published var automatic: Bool {
        didSet { if !isolated { UserDefaults.standard.set(automatic, forKey: "OndeAutomaticUpdates") } }
    }
    private let isolated: Bool
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private let session: URLSession
    init() {
        isolated = ProcessInfo.processInfo.environment["ONDE_HOME"] != nil
        automatic = !isolated && (UserDefaults.standard.object(forKey: "OndeAutomaticUpdates") as? Bool ?? true)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 180
        config.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: config)
        guard !isolated else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.checkIfNeeded() }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.checkIfNeeded() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.checkIfNeeded() }
    }
    deinit {
        timer?.invalidate()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        session.invalidateAndCancel()
    }
    private func checkIfNeeded() {
        guard automatic, lastChecked.map({ Date().timeIntervalSince($0) > 240 }) ?? true else { return }
        check()
    }
    func check() {
        guard !checking, !downloading else { return }
        checking = true; error = nil
        var request = URLRequest(url: UpdatePolicy.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Onde/\(AppBuild.version)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await self.session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw OndeError("invalid_response", "Réponse GitHub invalide.") }
                if http.statusCode == 404 {
                    await MainActor.run { self.candidate = nil; self.available = false; self.error = "Aucune version téléchargeable publiée pour le moment."; self.checking = false; self.lastChecked = Date() }
                    return
                }
                guard http.statusCode == 200 else { throw OndeError("update_http", "GitHub a répondu \(http.statusCode). Réessayez plus tard.") }
                guard data.count <= 2_000_000 else { throw OndeError("oversized_response", "Réponse de mise à jour trop volumineuse.") }
                let release = try JSONDecoder().decode(PublicRelease.self, from: data)
                let verified = try UpdatePolicy.parse(release)
                await MainActor.run {
                    self.candidate = verified; self.available = UpdatePolicy.isNewer(verified, than: AppBuild.number)
                    self.lastChecked = Date(); self.checking = false; self.error = nil
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.checking = false; self.lastChecked = Date() }
            }
        }
    }
    func download() {
        guard !downloading, let update = candidate else { return }
        downloading = true; error = nil
        var request = URLRequest(url: update.url)
        request.setValue("Onde/\(AppBuild.version)", forHTTPHeaderField: "User-Agent")
        Task { [weak self] in
            guard let self else { return }
            do {
                let (temp, response) = try await self.session.download(for: request)
                defer { try? FileManager.default.removeItem(at: temp) }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let scheme = response.url?.scheme, scheme == "https" else { throw OndeError("download_failed", "Le téléchargement GitHub n’a pas abouti.") }
                let size = try temp.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard Int64(size) == update.bytes else { throw OndeError("size_mismatch", "La taille du téléchargement ne correspond pas à la publication.") }
                let handle = try FileHandle(forReadingFrom: temp)
                defer { try? handle.close() }
                var hash = SHA256()
                while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
                let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
                guard digest == update.sha256 else { throw OndeError("digest_mismatch", "Vérification SHA-256 échouée. L’archive n’a pas été conservée.") }
                let directory: URL
                if self.isolated { directory = OndePaths.support.appendingPathComponent("Downloads", isDirectory: true) }
                else { directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0] }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var destination = directory.appendingPathComponent("Onde-\(update.tag).zip")
                var index = 2
                while FileManager.default.fileExists(atPath: destination.path) {
                    destination = directory.appendingPathComponent("Onde-\(update.tag)-\(index).zip"); index += 1
                }
                try FileManager.default.moveItem(at: temp, to: destination)
                let completedPath = destination.path
                await MainActor.run { self.downloadedPath = completedPath; self.downloading = false; self.error = nil }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.downloading = false }
            }
        }
    }
    func reveal() { if let path = downloadedPath { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) } }
    func snapshot() -> [String: Any] {
        ["repository": AppBuild.repository, "current_version": AppBuild.version, "current_build": AppBuild.number,
         "current_commit": AppBuild.commit, "checking": checking, "downloading": downloading,
         "update_available": available, "automatic": automatic, "check_interval_seconds": 300,
         "latest_tag": candidate?.tag as Any? ?? NSNull(), "latest_title": candidate?.title as Any? ?? NSNull(),
         "download_url": candidate?.url.absoluteString as Any? ?? NSNull(),
         "expected_sha256": candidate?.sha256 as Any? ?? NSNull(),
         "downloaded_path": downloadedPath as Any? ?? NSNull(),
         "last_checked": lastChecked.map { ISO8601DateFormatter().string(from: $0) } as Any? ?? NSNull(),
         "error": error as Any? ?? NSNull(), "automatic_installation": false]
    }
}
