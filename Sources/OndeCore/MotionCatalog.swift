import Foundation

/// Original Onde visual identities. No sound processing, telemetry or biometrics.
public enum OndeMotif: String, CaseIterable, Codable, Identifiable, Sendable {
    case laminar, prism, bloom, tide, canopy, amber, filigree, confluence, sanctuary, stillwater, hearth, reverie
    case driftwood, atlas, ostinato, aurora, chamber, momentum, reactor, traction, anchor, abyss, current, velvet, shore
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .driftwood: return "Driftwood"
        case .atlas: return "Atlas"
        case .ostinato: return "Ostinato"
        case .aurora: return "Aurora"
        case .chamber: return "Chamber"
        case .momentum: return "Momentum"
        case .reactor: return "Reactor"
        case .traction: return "Traction"
        case .anchor: return "Anchor"
        case .abyss: return "Abyss"
        case .current: return "Current"
        case .velvet: return "Velvet"
        case .shore: return "Shore"
        case .laminar: return "Laminar"
        case .prism: return "Prism"
        case .bloom: return "Bloom"
        case .tide: return "Tide"
        case .canopy: return "Canopy"
        case .amber: return "Amber"
        case .filigree: return "Filigree"
        case .confluence: return "Confluence"
        case .sanctuary: return "Sanctuary"
        case .stillwater: return "Stillwater"
        case .hearth: return "Hearth"
        case .reverie: return "Reverie"
        }
    }
    public var period: Double {
        switch self {
        case .driftwood, .chamber, .velvet, .shore: return 24
        case .atlas, .anchor, .abyss: return 26
        case .ostinato, .momentum, .reactor, .traction: return 18
        case .aurora, .current: return 22
        case .laminar: return 16
        case .prism: return 18
        case .bloom: return 24
        case .tide: return 20
        case .canopy: return 18
        case .amber: return 20
        case .filigree: return 16
        case .confluence: return 16
        case .sanctuary: return 26
        case .stillwater: return 22
        case .hearth: return 20
        case .reverie: return 22
        }
    }
    public var isClosed: Bool { [.prism, .bloom, .canopy, .amber, .stillwater, .hearth, .driftwood, .atlas, .chamber, .reactor, .anchor, .abyss].contains(self) }
    public var caption: String {
        switch self {
        case .driftwood: return "Quiet grain, slowly drifting."
        case .atlas: return "An ensemble of connected horizons."
        case .ostinato: return "A pattern with a steady purpose."
        case .aurora: return "Light moving through the air."
        case .chamber: return "An intimate space, gently opening."
        case .momentum: return "A forward motion, without urgency."
        case .reactor: return "Energy held in concentric contours."
        case .traction: return "Lines finding their direction."
        case .anchor: return "A steady place in moving water."
        case .abyss: return "Depth without distraction."
        case .current: return "A continuous exchange."
        case .velvet: return "Soft folds, without an edge."
        case .shore: return "A place where the current settles."
        case .laminar: return "A quiet current, moving with purpose."
        case .prism: return "Order, without rigidity."
        case .bloom: return "Space to be still."
        case .tide: return "Let the day settle."
        case .canopy: return "Shelter in the small details."
        case .amber: return "Warmth, held in motion."
        case .filigree: return "A thread of clarity."
        case .confluence: return "Separate currents, one direction."
        case .sanctuary: return "Room for a quieter mind."
        case .stillwater: return "Nothing to hurry."
        case .hearth: return "A softer place to land."
        case .reverie: return "Follow nothing. Just listen."
        }
    }
    public static func forMusic(_ id: String, meditation: Bool = false) -> Self {
        MusicArtworkIdentity.catalog[id] ?? .laminar
    }
}

public enum OndeMotionQuality: String, CaseIterable, Sendable {
    case still, thumbnail, economy, balanced
    public var fps: Double { switch self { case .still: return 0; case .thumbnail: return 0; case .economy: return 12; case .balanced: return 24 } }
    public var lines: Int { self == .thumbnail ? 12 : self == .economy ? 20 : 32 }
    public var samples: Int { self == .thumbnail ? 48 : self == .economy ? 80 : 112 }
}


/// Unknown or obsolete preferences safely follow the current music.
public enum EspaceArtworkSelection {
    public static func motif(choice: String, musicID: String, mode: SessionMode) -> OndeMotif {
        OndeMotif(rawValue: choice) ?? OndeMotif.forMusic(musicID, meditation: mode == .meditation)
    }
}
