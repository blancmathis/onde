import Foundation

/// References to complete recordings published by Endel, not downloaded media.
/// Durations below are the publisher's rounded titles; player duration is separate.
public struct EndelSession: Codable, Identifiable {
    public let id: String
    public let title: String
    public let videoID: String
    public let minutes: Int
    public let mode: SessionMode
    public var url: String { "https://www.youtube.com/watch?v=" + videoID }
    public static let all: [EndelSession] = [
        .init(id: "deep-focus", title: "Deep Focus", videoID: "rJ03VlaPKSg", minutes: 60, mode: .focus),
        .init(id: "smart-focus", title: "Smart Focus", videoID: "TfEIdFfWaIo", minutes: 60, mode: .focus),
        .init(id: "relax", title: "Relax", videoID: "ofhLea32ZOQ", minutes: 60, mode: .relax),
        .init(id: "power-focus", title: "Power Focus", videoID: "QOny_unR3qc", minutes: 60, mode: .focus),
        .init(id: "lofi-study", title: "Lofi Study", videoID: "hHf7G-jjVU4", minutes: 60, mode: .focus),
        .init(id: "deep-sleep", title: "Deep Sleep", videoID: "VaEz5gtVMxQ", minutes: 90, mode: .relax),
        .init(id: "winter-sleep", title: "Cozy Winter Sleep", videoID: "RtmuVcJyhp4", minutes: 480, mode: .relax),
        .init(id: "summer-sleep", title: "Warm Summer Nights", videoID: "e-OrPwWF8VI", minutes: 480, mode: .relax)
    ]
    public static func find(_ id: String) -> EndelSession? { all.first { $0.id == id } }
    public var descriptor: [String: Any] { ["id":id,"title":title,"url":url,"publisher":"Endel · @EndelSound","minutes_approx":minutes,"mode":mode.rawValue,"source":"official_youtube","offline":false,"demo":false] }
}
