import Foundation

/// A presentation-only transaction. Editing never changes the stored schedule.
public struct EspaceChimeDraft: Equatable {
    public var text: String
    public private(set) var savedMarkers: [Double]
    public private(set) var hasConflict = false
    public var isDirty: Bool { text != Self.format(savedMarkers) }

    public init(markers: [Double]) {
        savedMarkers = markers
        text = Self.format(markers)
    }
    public static func format(_ markers: [Double]) -> String {
        markers.map { String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), $0 / 60) }.joined(separator: ", ")
    }
    /// External changes refresh a clean draft, but never replace a local edit.
    public mutating func receive(_ markers: [Double]) {
        guard markers != savedMarkers else { return }
        let wasClean = !isDirty
        savedMarkers = markers
        if wasClean { text = Self.format(markers); hasConflict = false }
        else { hasConflict = isDirty }
    }
    public mutating func reload() {
        text = Self.format(savedMarkers)
        hasConflict = false
    }
    public mutating func didApply(_ markers: [Double]) { self = Self(markers: markers) }

    public func parsedSeconds() throws -> [Double] {
        guard !hasConflict else { throw ValidationError.conflict }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count <= 32 else { throw ValidationError.invalidTimes }
        let minutes = parts.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard minutes.count == parts.count,
              minutes.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1440 }) else { throw ValidationError.invalidTimes }
        return Array(Set(minutes.map { $0 * 60 })).sorted()
    }
    public enum ValidationError: LocalizedError {
        case conflict, invalidTimes
        public var errorDescription: String? {
            switch self {
            case .conflict: return "Chime times changed elsewhere. Reload before applying an edit."
            case .invalidTimes: return "Use up to 32 positive times, no greater than 1440 minutes."
            }
        }
    }
}
