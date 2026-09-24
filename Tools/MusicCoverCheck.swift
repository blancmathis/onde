import AppKit
import OndeCore

@main struct MusicCoverCheck {
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for (id, motif) in MusicArtworkIdentity.catalog.sorted(by: { $0.key < $1.key }) {
            let image = EspacePosterCache.image(motif)
            let repeated = EspacePosterCache.image(motif)
            precondition(image === repeated, "Poster cache must reuse its image")
            let p = NSBitmapImageRep(data: image.tiffRepresentation!)!
            precondition(p.pixelsWide == 92 && p.pixelsHigh == 104)
            var count = 0, edge = 0
            for y in 0..<p.pixelsHigh { for x in 0..<p.pixelsWide {
                if p.colorAt(x: x, y: y)!.alphaComponent > 0.04 {
                    count += 1
                    if x < 2 || y < 2 || x >= p.pixelsWide-2 || y >= p.pixelsHigh-2 { edge += 1 }
                }
            } }
            precondition(count > 100 && edge == 0, "Clipped or empty cover: \(id), visible=\(count), edge=\(edge)")
            try p.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("poster-\(id).png"))
            print("PASS \(id): 92x104, \(count) visible pixels, 0 clipped edge pixels; cached identity")
        }
    }
}
