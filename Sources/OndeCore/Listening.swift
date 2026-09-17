import Foundation

/// Session intent and musical identity are separate. Meditation uses the exact
/// Relax catalog; it adds a stopwatch and chimes, not another library of tracks.
public enum MusicCatalog {
    public static func profiles(for mode: SessionMode) -> [SoundProfile] {
        SoundProfile.all.filter { mode == .focus ? $0.mode == .focus : $0.mode != .focus }
    }
    public static func allows(_ id: String, in mode: SessionMode) -> Bool {
        profiles(for: mode).contains { $0.id == id }
    }
    public static func fallback(for mode: SessionMode) -> String {
        switch mode { case .focus: return "sillage"; case .relax: return "velours"; case .meditation: return "immersion" }
    }
    public static func settingKey(_ id: String, mode: SessionMode) -> String { mode.rawValue + ":" + id }
}

public enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case off, white, pink, brown, rain, ocean
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .off: return "Off"
        case .white: return "White noise"
        case .pink: return "Pink noise"
        case .brown: return "Brown noise"
        case .rain: return "Rain"
        case .ocean: return "Ocean"
        }
    }
    public var soundID: String? { self == .off ? nil : rawValue }
    public static let soundIDs = Set(allCases.compactMap(\.soundID))
}
public struct BackgroundMix: Codable, Equatable {
    public var kind: BackgroundKind
    public var volume: Double
    public init(kind: BackgroundKind = .off, volume: Double = 0.15) {
        self.kind = kind; self.volume = volume.isFinite ? min(1, max(0, volume)) : 0
    }
    public static func infer(from layers: [String: Layer]) -> Self {
        let enabled = BackgroundKind.allCases.filter { kind in
            kind.soundID.map { layers[$0]?.enabled == true } ?? false
        }
        guard let kind = enabled.max(by: { (layers[$0.rawValue]?.volume ?? 0) < (layers[$1.rawValue]?.volume ?? 0) }) else { return .init() }
        return .init(kind: kind, volume: layers[kind.rawValue]?.volume ?? 0.15)
    }
}

/// Additive migration: no legacy mixes, imports, generator settings or listening
/// intervals are rewritten. Browsing/playing never silently changes a default.
public struct ListeningPreferences: Codable {
    public var defaults: [String: String] = [:]
    public var backgrounds: [String: BackgroundMix] = [:]
    public var musicLevels: [String: Double] = [:]
    public var customizations: [String: GenerativeSettings] = [:]
    public init() {}
    public func defaultID(for mode: SessionMode) -> String {
        if let id = defaults[mode.rawValue], MusicCatalog.allows(id, in: mode) { return id }
        return MusicCatalog.fallback(for: mode)
    }
    public mutating func setDefault(_ id: String, for mode: SessionMode) throws {
        guard SoundProfile.find(id) != nil else { throw OndeError("not_found", "Unknown music. Use onde music list.") }
        guard MusicCatalog.allows(id, in: mode) else { throw OndeError("wrong_catalog", "Choose Focus music for Focus, or Relax music for Relax and Meditation.") }
        defaults[mode.rawValue] = id
    }
    public static func migrating(_ state: StoredState) -> Self {
        var result = Self()
        for mode in SessionMode.allCases {
            let layers = mode == state.mode ? state.layers : state.modeMixes[mode.rawValue] ?? [:]
            result.backgrounds[mode.rawValue] = .infer(from: layers)
            result.musicLevels[mode.rawValue] = layers["living"]?.volume ?? 0.65
            if let c = state.generatorSettings?[mode.rawValue], let id = c.profileID, MusicCatalog.allows(id, in: mode) {
                result.defaults[mode.rawValue] = id
                result.customizations[MusicCatalog.settingKey(id, mode: mode)] = c
            } else { result.defaults[mode.rawValue] = MusicCatalog.fallback(for: mode) }
        }
        return result
    }
}
