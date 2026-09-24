import Foundation

/// The sole music-to-artwork registry, shared by covers, live artwork and diagnostics.
/// An identity does not change when the same music is used for meditation.
public enum MusicArtworkIdentity {
    public static let catalog: [String: OndeMotif] = [
        "sillage": .laminar, "ambre": .amber, "meridien": .prism,
        "canopee": .canopy, "filigrane": .filigree, "confluence": .confluence,
        "sanctuaire": .sanctuary, "lagoon": .tide, "stillwater": .stillwater,
        "hearth": .hearth, "reverie": .reverie, "immersion": .bloom,
        "driftwood": .driftwood, "atlas": .atlas, "ostinato": .ostinato,
        "aurore": .aurora, "chambre": .chamber, "elan": .momentum,
        "reacteur": .reactor, "traction": .traction, "ancrage": .anchor,
        "abysses": .abyss, "courant": .current, "velours": .velvet, "rive": .shore
    ]
    public static func color(_ motif: OndeMotif) -> UInt32 {
        switch motif {
        case .laminar, .anchor: return 0x9CC8C0
        case .amber, .hearth: return 0xE0C6A0
        case .prism, .traction: return 0xA7B7D7
        case .filigree, .chamber: return 0xC7BDDE
        case .canopy, .driftwood: return 0xB7CA9A
        case .tide, .shore: return 0x9FC3CE
        case .confluence, .atlas: return 0xAACBB5
        case .sanctuary, .reverie: return 0xD3CBE9
        case .bloom, .velvet: return 0xD8BBC7
        case .stillwater, .abyss: return 0xACC1D8
        case .aurora, .current: return 0xC2D8B8
        case .ostinato, .momentum: return 0xCFBB94
        case .reactor: return 0xCCA798
        }
    }
    public static func aspect(_ motif: OndeMotif) -> Double {
        motif.isClosed || motif == .reverie || motif == .sanctuary ? 1 : 0.61
    }
}
