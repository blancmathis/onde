import Foundation

/// Resolve one saved mix, never a set of similarly named items.
/// UUID references are IDs only, including stale native confirmations.
public enum MixLookup {
    public static func index(for reference: String, in mixes: [Mix]) throws -> Int {
        guard !reference.isEmpty else { throw OndeError("not_found", "Mix not found.") }
        let uuid = UUID(uuidString: reference)
        let identifiers = mixes.indices.filter { index in
            if let uuid { return UUID(uuidString: mixes[index].id) == uuid }
            return mixes[index].id == reference
        }
        guard identifiers.count <= 1 else {
            throw OndeError("ambiguous_mix", "Several saved mixes share this ID. Nothing was changed.")
        }
        if let index = identifiers.first { return index }
        guard uuid == nil else { throw OndeError("not_found", "This saved mix no longer exists.") }
        let names = mixes.indices.filter { mixes[$0].name == reference }
        guard names.count <= 1 else {
            throw OndeError("ambiguous_mix", "Several saved mixes have this name. Use the ID shown by onde mixes.")
        }
        guard let index = names.first else { throw OndeError("not_found", "Mix not found.") }
        return index
    }
}
