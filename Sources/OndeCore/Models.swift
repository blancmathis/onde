import Foundation

public enum SessionMode: String, Codable, CaseIterable, Identifiable {
    case focus, relax, meditation
    public var id: String { rawValue }
    public var title: String { switch self { case .focus: return "Focus"; case .relax: return "Relax"; case .meditation: return "Méditation" } }
    public var symbol: String { switch self { case .focus: return "scope"; case .relax: return "water.waves"; case .meditation: return "sparkle" } }
}

/// All timing is injected: deterministic tests never have to wait 30 minutes.
/// Markers are absolute elapsed seconds, never a repeating interval.
public struct SessionClock {
    public private(set) var accumulated: Double = 0
    public private(set) var startedAt: Double?
    public private(set) var fired: Set<Double> = []
    public init() {}
    public var running: Bool { startedAt != nil }
    public func elapsed(at now: Double) -> Double { accumulated + (startedAt.map { max(0, now - $0) } ?? 0) }
    public mutating func start(at now: Double) { accumulated = 0; fired = []; startedAt = now }
    public mutating func pause(at now: Double) { accumulated = elapsed(at: now); startedAt = nil }
    public mutating func resume(at now: Double) { if !running { startedAt = now } }
    public mutating func reset(at now: Double) { accumulated = 0; fired = []; if running { startedAt = now } }
    public mutating func stop() { accumulated = 0; startedAt = nil; fired = [] }
    public mutating func skipPastMarkers(_ markers: [Double], at now: Double) { fired.formUnion(markers.filter { $0 <= elapsed(at: now) }) }
    /// Consume all crossed markers, but never emit a catch-up barrage after a stall/sleep.
    public mutating func tick(at now: Double, markers: [Double], tolerance: Double = 2) -> Double? {
        guard running else { return nil }
        let t = elapsed(at: now)
        let due = markers.filter { $0 <= t && !fired.contains($0) }.sorted()
        fired.formUnion(due)
        guard let newest = due.last, t - newest <= tolerance else { return nil }
        return newest
    }
}

public struct Sound: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var symbol: String
    public var kind: String
    public var filename: String
    public var author: String
    public var license: String
    public var source: String
    public var imported: Bool = false
    public init(id: String, title: String, subtitle: String, symbol: String, kind: String, filename: String, author: String = "Onde · synthèse originale", license: String = "CC0-1.0", source: String = "Généré localement par Tools/Synthesize.swift", imported: Bool = false) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.kind = kind; self.filename = filename; self.author = author; self.license = license; self.source = source; self.imported = imported
    }
    public static let builtins: [Sound] = [
        Sound(id: "aube", title: "Aube", subtitle: "Nappes chaudes · aériennes", symbol: "sun.horizon", kind: "Musique", filename: "aube.m4a"),
        Sound(id: "piano", title: "Piano de lune", subtitle: "Notes espacées · veloutées", symbol: "pianokeys", kind: "Musique", filename: "piano.m4a"),
        Sound(id: "orbit", title: "Orbite", subtitle: "Pulsations lentes · cristallines", symbol: "circle.hexagongrid", kind: "Musique", filename: "orbit.m4a"),
        Sound(id: "rain", title: "Pluie douce", subtitle: "Texture de pluie · synthétisée", symbol: "cloud.rain", kind: "Texture", filename: "rain.m4a"),
        Sound(id: "ocean", title: "Marée", subtitle: "Vagues lentes · synthétisées", symbol: "water.waves", kind: "Texture", filename: "ocean.m4a"),
        Sound(id: "brown", title: "Velours brun", subtitle: "Bruit brun · grave et stable", symbol: "waveform.path", kind: "Bruit", filename: "brown.m4a"),
        Sound(id: "pink", title: "Air rose", subtitle: "Bruit rose · souffle diffus", symbol: "wind", kind: "Bruit", filename: "pink.m4a"),
        Sound(id: "almost", title: "Almost in F", subtitle: "Kevin MacLeod · 32 min", symbol: "music.note", kind: "Composition", filename: "almost.mp3", author: "Kevin MacLeod (incompetech.com)", license: "CC BY 4.0", source: "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100394"),
        Sound(id: "dreams", title: "Dreams Become Real", subtitle: "Kevin MacLeod · piano", symbol: "music.note", kind: "Composition", filename: "dreams.mp3", author: "Kevin MacLeod (incompetech.com)", license: "CC BY 4.0", source: "https://incompetech.com/music/royalty-free/")
    ]
}
public struct Layer: Codable, Equatable {
    public var enabled: Bool
    public var volume: Double
    public init(_ enabled: Bool = false, _ volume: Double = 0.5) { self.enabled = enabled; self.volume = volume }
}
public struct Preferences: Codable {
    public var masterVolume: Double = 0.55
    public var chimeVolume: Double = 0.25
    public var fadeSeconds: Double = 2.0
    public var markers: [Double] = [600, 1200, 1800]
    public var chimesEnabled = true
    public var preventSleep = true
    public var reducedMotion = false
    public init() {}
}
public struct Mix: Codable, Identifiable {
    public var generatorSettings: GenerativeSettings?
    public var id: String
    public var name: String
    public var mode: SessionMode
    public var layers: [String: Layer]
    public init(name: String, mode: SessionMode, layers: [String: Layer], generatorSettings: GenerativeSettings? = nil) { self.id = UUID().uuidString; self.name = name; self.mode = mode; self.layers = layers; self.generatorSettings = generatorSettings }
}
public struct SessionRecord: Codable, Identifiable {
    public var id = UUID().uuidString
    public var date: Date
    public var mode: SessionMode
    public var seconds: Double
    public init(date: Date, mode: SessionMode, seconds: Double) { self.date = date; self.mode = mode; self.seconds = seconds }
}
public struct StoredState: Codable {
    public var transitionSeconds: Double?
    public var generatorSettings: [String: GenerativeSettings]?
    public var version = 1
    public var preferences = Preferences()
    public var mode: SessionMode = .focus
    public var layers: [String: Layer] = ["aube": Layer(true, 0.55), "brown": Layer(true, 0.18)]
    public var modeMixes: [String: [String: Layer]] = [:]
    public var imported: [Sound] = []
    public var mixes: [Mix] = []
    public var history: [SessionRecord] = []
    public init() {}
}
public enum OndePaths {
    public static var support: URL {
        // Override is intended for isolated integration tests, never silently use /tmp.
        if let p = ProcessInfo.processInfo.environment["ONDE_HOME"], p.hasPrefix("/") { return URL(fileURLWithPath: p, isDirectory: true) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Onde", isDirectory: true)
    }
    public static var socket: String { support.appendingPathComponent("control.sock").path }
    public static var state: URL { support.appendingPathComponent("state.json") }
    public static var imports: URL { support.appendingPathComponent("Imports", isDirectory: true) }
    public static func prepare() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: support.path)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
}
public func clockText(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%02d:%02d", s / 60, s % 60)
}
public func validMarkers(_ values: [Double]) throws -> [Double] {
    guard values.count <= 32, values.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 86400 }) else { throw OndeError("invalid_markers", "Use at most 32 positive timestamps, up to 86400 seconds.") }
    return Array(Set(values)).sorted()
}
public struct OndeError: Error, LocalizedError {
    public var code: String; public var message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
}
public func jsonData(_ value: Any, pretty: Bool = false) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: pretty ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes])
}
public func jsonObject<T: Encodable>(_ value: T) -> Any { (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(value))) ?? NSNull() }
