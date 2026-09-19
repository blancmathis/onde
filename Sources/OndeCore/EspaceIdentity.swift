import Foundation

extension ListeningDesign {
    /// Static visual families, independent from playback mode and audio parameters.
    public static func coverFamily(_ id: String) -> Int {
        switch id {
        case "sillage", "rive": return 0
        case "ambre", "hearth", "velours": return 1
        case "meridien", "confluence": return 2
        case "filigrane", "sanctuaire", "reverie": return 3
        case "canopee", "driftwood": return 4
        case "lagoon", "stillwater", "immersion": return 5
        default: return Int(seed(id) * 6)
        }
    }
}
