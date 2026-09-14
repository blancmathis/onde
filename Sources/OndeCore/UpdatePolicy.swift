import Foundation

public enum AppBuild {
    public static let version = "1.5.0"
    public static let repository = "blancmathis/onde"
    public static var number: UInt64 { UInt64(Bundle.main.object(forInfoDictionaryKey: "OndeBuild") as? String ?? "0") ?? 0 }
    public static var commit: String { Bundle.main.object(forInfoDictionaryKey: "OndeCommit") as? String ?? "local" }
}
public struct ReleaseAsset: Codable {
    public var name: String
    public var size: Int64
    public var browser_download_url: String
    public var digest: String?
}
public struct PublicRelease: Codable {
    public var tag_name: String
    public var name: String?
    public var draft: Bool
    public var prerelease: Bool
    public var target_commitish: String
    public var html_url: String
    public var assets: [ReleaseAsset]
}
public struct VerifiedUpdate: Equatable {
    public let title: String
    public let tag: String
    public let build: UInt64
    public let commit: String
    public let url: URL
    public let bytes: Int64
    public let sha256: String
}
public enum UpdatePolicy {
    public static let archiveName = "Onde-macOS-universal.zip"
    public static let endpoint = URL(string: "https://api.github.com/repos/\(AppBuild.repository)/releases/latest")!
    public static func parse(_ release: PublicRelease) throws -> VerifiedUpdate {
        guard !release.draft, !release.prerelease else { throw OndeError("unpublished_release", "La version n’est pas une publication stable.") }
        let pieces = release.tag_name.split(separator: "-")
        guard pieces.count == 3, pieces[0] == "build", pieces[1].count == 14,
              pieces[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = UInt64(pieces[1]), pieces[2].count == 8,
              pieces[2].allSatisfy({ "0123456789abcdef".contains($0) }),
              release.target_commitish.count == 40,
              release.target_commitish.allSatisfy({ "0123456789abcdef".contains($0) }),
              release.target_commitish.hasPrefix(pieces[2]) else {
            throw OndeError("invalid_release", "L’identifiant de publication ou son commit est invalide.")
        }
        guard let asset = release.assets.first(where: { $0.name == archiveName }),
              (1...400_000_000).contains(asset.size),
              let parts = URLComponents(string: asset.browser_download_url),
              parts.scheme == "https", parts.host == "github.com", parts.port == nil,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.percentEncodedPath == "/\(AppBuild.repository)/releases/download/\(release.tag_name)/\(archiveName)",
              let url = parts.url else {
            throw OndeError("invalid_asset", "Archive absente ou adresse de téléchargement non autorisée.")
        }
        let digest = asset.digest ?? ""
        guard digest.hasPrefix("sha256:"), digest.count == 71,
              digest.dropFirst(7).allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw OndeError("missing_digest", "L’empreinte SHA-256 de l’archive n’est pas encore disponible.")
        }
        return VerifiedUpdate(title: release.name ?? release.tag_name, tag: release.tag_name,
                              build: number, commit: release.target_commitish, url: url,
                              bytes: asset.size, sha256: String(digest.dropFirst(7)))
    }
    public static func isNewer(_ release: VerifiedUpdate, than build: UInt64) -> Bool { release.build > build }
}
