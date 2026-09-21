import Foundation

public enum UpdateArchiveValidation {
    /// Inspect central AND local ZIP headers before extraction. Reject traversal, links,
    /// encrypted/ZIP64 archives, duplicates, overlapping members and expansion bombs.
    public static func validate(_ data: Data) throws {
        func reject() -> Error { OndeError("update_archive", "The update archive has an unsafe or unsupported structure.") }
        func u16(_ p: Int) throws -> Int {
            guard p >= 0, p + 2 <= data.count else { throw reject() }
            return Int(data[p]) | Int(data[p + 1]) << 8
        }
        func u32(_ p: Int) throws -> Int { try u16(p) | (u16(p + 2) << 16) }
        guard data.count >= 22, data.count <= 400_000_000 else { throw reject() }
        var end: Int?
        for p in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
            if try u32(p) == 0x06054b50, p + 22 + (try u16(p + 20)) == data.count { end = p; break }
        }
        guard let end, try u16(end + 4) == 0, try u16(end + 6) == 0 else { throw reject() }
        let count = try u16(end + 10), centralSize = try u32(end + 12), central = try u32(end + 16)
        guard count > 0, count < 50_000, try u16(end + 8) == count,
              centralSize <= 16_000_000, central + centralSize == end else { throw reject() }
        var cursor = central, total = 0, names = Set<String>(), extents: [(Int, Int)] = []
        for _ in 0..<count {
            guard try u32(cursor) == 0x02014b50 else { throw reject() }
            let flags = try u16(cursor + 8), method = try u16(cursor + 10)
            let compressed = try u32(cursor + 20), expanded = try u32(cursor + 24)
            let length = try u16(cursor + 28), extra = try u16(cursor + 30), comment = try u16(cursor + 32)
            let mode = try u32(cursor + 38) >> 16, local = try u32(cursor + 42)
            guard flags & 1 == 0, [0, 8].contains(method), expanded <= 400_000_000,
                  [0, 0o100000, 0o040000].contains(mode & 0o170000), mode & 0o6000 == 0,
                  cursor + 46 + length + extra + comment <= end, length > 0 else { throw reject() }
            let nameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + length))
            guard let name = String(data: nameData, encoding: .utf8), name.hasPrefix("Onde.app/"),
                  !name.contains("\\"), !name.contains(":"), !name.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
                  !name.split(separator: "/", omittingEmptySubsequences: false).dropLast(name.hasSuffix("/") ? 1 : 0).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                  names.insert(name.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw reject() }
            guard local >= 0, local + 30 < central, try u32(local) == 0x04034b50,
                  try u16(local + 6) == flags, try u16(local + 8) == method, try u16(local + 26) == length else { throw reject() }
            let start = local + 30 + length + (try u16(local + 28))
            guard start <= central, start + compressed <= central,
                  data.subdata(in: (local + 30)..<(local + 30 + length)) == nameData else { throw reject() }
            extents.append((local, start + compressed))
            total += expanded
            guard total <= 1_600_000_000 else { throw reject() }
            cursor += 46 + length + extra + comment
        }
        guard cursor == end else { throw reject() }
        let sorted = extents.sorted { $0.0 < $1.0 }
        for i in 1..<sorted.count { guard sorted[i].0 >= sorted[i - 1].1 else { throw reject() } }
    }

}
