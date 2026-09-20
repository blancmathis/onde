import Foundation

/// Presentation-only data. No audio, account, timer or persistence writes.
public enum ListeningDesign {
    public static let featured = ["ambre", "sillage", "canopee", "filigrane", "meridien", "confluence", "sanctuaire"]
    public static func detail(_ id: String) -> String {
        switch id {
        case "ambre": return "Warm electric keys & piano"
        case "sillage": return "Driving bass & dark electronic motifs"
        case "canopee": return "Wood tones, harp & low strings"
        case "filigrane": return "Soft acoustic piano"
        case "meridien": return "Deep bass & minimal house"
        case "confluence": return "Strings, horns & a steady pulse"
        case "sanctuaire": return "Wordless voices & deep bass"
        case "lagoon": return "Deep ambient, without a beat"
        case "stillwater": return "Spacious acoustic piano"
        case "hearth": return "Warm strings, horns & woodwinds"
        case "reverie": return "Wordless choir & distant harp"
        case "driftwood": return "Rounded wood tones & harp"
        case "velours": return "Warm keys, soft and spacious"
        case "rive": return "Broad pads & a gentle pulse"
        case "immersion": return "Continuous ambient, without a beat"
        default: return "Continuously generated on your Mac"
        }
    }
    public static func matches(query: String, title: String, id: String, description: String) -> Bool {
        let words = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace })
        let text = (title + " " + id + " " + description).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return words.allSatisfy { text.contains($0) }
    }
    /// Stable ordering; the saved default is pinned without hiding other pieces.
    public static func rank(id: String, defaultID: String) -> Int {
        if id == defaultID { return -1 }
        return featured.firstIndex(of: id) ?? 100
    }
    public static func seed(_ id: String) -> Double {
        let hash = id.utf8.reduce(UInt32(2166136261)) { ($0 ^ UInt32($1)) &* 16777619 }
        return Double(hash % 1000) / 1000
    }
}

public struct EspacePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// One broad satin surface, not a bank of competing animated thumbnails.
/// Normalized points are shared with the design preview. No random per-frame work.
public enum EspaceGeometry {
    public static func point(u: Double, v: Double, time: Double, seed: Double) -> EspacePoint {
        let u = u.isFinite ? min(1, max(0, u)) : 0
        let v = v.isFinite ? min(1, max(0, v)) : 0
        let time = time.isFinite ? time.truncatingRemainder(dividingBy: 80) : 0
        let seed = seed.isFinite ? min(1, max(0, seed)) : 0
        let p = time * .pi * 2 / 80
        let a = u * .pi * 2
        let q = v - 0.5
        let envelope = 0.055 + 0.29 * pow(abs(2 * u - 1), 1.5)
        let bend = sin(a * 0.86 - 0.42 + seed * 0.6 + 0.24 * sin(p))
        let flutter = 0.016 * sin(a * 1.5 + q * 3 + p) * sin(u * .pi)
        let x = 0.08 + u * 0.84 + 0.032 * sin(q * .pi) * sin(a + p)
        let y = 0.48 + 0.145 * bend + q * envelope + flutter
        return .init(x: x, y: y)
    }
    public static func band(index: Int, count: Int, samples: Int, time: Double, seed: Double) -> [EspacePoint] {
        let count = min(96, max(1, count)); let samples = min(160, max(8, samples))
        let index = min(count - 1, max(0, index))
        let lo = Double(index) / Double(count); let hi = Double(index + 1) / Double(count)
        let top = (0...samples).map { point(u: Double($0) / Double(samples), v: lo, time: time, seed: seed) }
        let bottom = (0...samples).reversed().map { point(u: Double($0) / Double(samples), v: hi, time: time, seed: seed) }
        return top + bottom
    }
}

public struct EspaceClock: Sendable {
    public private(set) var elapsed: Double = 0
    private var last: Double?
    public init() {}
    public mutating func tick(now: Double, running: Bool) {
        guard now.isFinite else { return }
        defer { last = now }
        guard running, let last else { return }
        elapsed += min(0.1, max(0, now - last))
    }
    public mutating func suspend() { last = nil }
}

public enum EspaceMotionPolicy {
    /// Request budget, not a promise about measured frame rate or battery life.
    public static func fps(visible: Bool, active: Bool, enabled: Bool, reduced: Bool, lowPower: Bool, hot: Bool) -> Int {
        guard visible, enabled, !reduced, !hot else { return 0 }
        // A visible window does not become a still image when another app takes focus.
        return lowPower || !active ? 12 : 24
    }
}
