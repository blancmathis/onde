import Foundation

/// Source activity, not the presence of an open application, gates session time.
/// Gain is deliberately absent: Mute changes loudness, while Pause stops transport.
public struct PlaybackClockPolicy {
    public enum Decision: String { case idle, count, wait, noSources, unavailable }
    public static let preparationGrace: Double = 30
    public static let outputGrace: Double = 2
    private var waitingSince: Double?
    public init() {}
    public mutating func reset() { waitingSince = nil }
    public mutating func evaluate(requested: Bool, mode: SessionMode,
                                  hasSelection: Bool, hasRunningAudio: Bool,
                                  preparing: Bool, failed: Bool, at now: Double) -> Decision {
        guard requested else { reset(); return .idle }
        // No-layer meditation is an explicit practice, not broken audio.
        guard hasSelection else { reset(); return mode == .meditation ? .count : .noSources }
        // A crossfade may prepare a new scene while the old one still plays.
        if hasRunningAudio { reset(); return .count }
        if failed || !now.isFinite { reset(); return .unavailable }
        if waitingSince == nil || now < waitingSince! { waitingSince = now }
        let limit = preparing ? Self.preparationGrace : Self.outputGrace
        if now - waitingSince! >= limit { reset(); return .unavailable }
        return .wait
    }
}
