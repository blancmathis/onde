import Foundation

/// Original Onde visual identities. No sound processing, telemetry or biometrics.
public enum OndeMotif: String, CaseIterable, Codable, Identifiable, Sendable {
    case laminar, prism, bloom, tide, canopy, amber, filigree, confluence, sanctuary, stillwater, hearth, reverie
    public var id: String { rawValue }
    public var title: String {
        switch self {
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
    public var isClosed: Bool { [.prism, .bloom, .canopy, .amber, .stillwater, .hearth].contains(self) }
    public var caption: String {
        switch self {
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
        if meditation && id == "immersion" { return .bloom }
        switch id {
        case "sillage", "ostinato": return .laminar
        case "meridien", "prisme": return .prism
        case "canopee", "driftwood": return .canopy
        case "ambre", "velours", "aurore": return .amber
        case "filigrane", "chambre": return .filigree
        case "confluence", "atlas": return .confluence
        case "sanctuaire": return .sanctuary
        case "lagoon", "rive": return .tide
        case "stillwater": return .stillwater
        case "hearth": return .hearth
        case "reverie": return .reverie
        case "immersion": return .bloom
        default: return .laminar
        }
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
