#if ONDE_DESIGN_CAPTURE
import Foundation
import OndeCore

/// Actual UpdateManager state transitions with local URLProtocol responses.
/// No network, credentials, downloads or alternate production update endpoint.
@MainActor enum UpdateMetadataCapture {
    static func run() async throws -> [String] {
        var checks: [String] = []
        let configuration = UpdateMetadataPolicy.configuration()
        configuration.protocolClasses = [MetadataResponseProtocol.self]
        let manager = UpdateManager(metadataConfiguration: configuration)
        func require(_ ok: Bool, _ name: String) throws {
            guard ok else { throw NSError(domain: "OndeMetadataCheck", code: 1,
                                          userInfo: [NSLocalizedDescriptionKey: name]) }
            checks.append(name); print("PASS \(name)"); fflush(stdout)
        }
        try require(!manager.automatic, "Isolated updater never schedules automatic network checks")
        for scenario in ["offline", "timeout", "missing", "limited", "malformed", "valid"] {
            MetadataResponseProtocol.select(scenario)
            manager.check()
            manager.check() // A second click while checking must not start another task.
            let end = ProcessInfo.processInfo.systemUptime + 4
            while manager.checking, ProcessInfo.processInfo.systemUptime < end {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            try require(!manager.checking && manager.lastChecked != nil, "Metadata \(scenario): check finishes and records its result")
            try require(MetadataResponseProtocol.count == 1, "Metadata \(scenario): duplicate clicks share one request")
            if scenario == "valid" {
                try require(manager.error == nil && manager.available && manager.candidate != nil,
                            "A successful retry recovers after offline, HTTP and malformed-response errors")
            } else {
                try require(manager.error != nil && !manager.available && manager.candidate == nil,
                            "Metadata \(scenario): failure does not invent an installable update")
            }
            try require(!manager.downloading && manager.downloadedPath == nil, "Metadata \(scenario): checking never downloads or installs")
        }
        return checks
    }
}

private final class MetadataResponseProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var scenario = "offline"
    private static var requests = 0
    static var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    static func select(_ value: String) { lock.lock(); scenario = value; requests = 0; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.requests += 1; let scenario = Self.scenario; Self.lock.unlock()
        guard request.url == UpdatePolicy.endpoint else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        if scenario == "offline" || scenario == "timeout" {
            client?.urlProtocol(self, didFailWithError: URLError(scenario == "offline" ? .notConnectedToInternet : .timedOut))
            return
        }
        let code = scenario == "missing" ? 404 : scenario == "limited" ? 429 : 200
        let tag = "build-20990101000000-01234567"
        let body: Data
        if scenario == "valid" {
            let object: [String: Any] = ["tag_name": tag, "name": "Synthetic update fixture", "draft": false,
                "prerelease": false, "target_commitish": "01234567" + String(repeating: "a", count: 32),
                "html_url": "https://github.com/blancmathis/onde/releases",
                "assets": [["name": UpdatePolicy.archiveName, "size": 1_234_567,
                            "browser_download_url": "https://github.com/blancmathis/onde/releases/download/\(tag)/\(UpdatePolicy.archiveName)",
                            "digest": "sha256:" + String(repeating: "a", count: 64)]]]
            body = try! JSONSerialization.data(withJSONObject: object)
        } else { body = Data("not valid release JSON".utf8) }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
#endif
