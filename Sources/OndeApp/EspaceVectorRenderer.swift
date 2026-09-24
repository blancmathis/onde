import AppKit
import SwiftUI
import OndeCore

/// One geometry and palette for a cover, the live player and the software fallback.
/// Four batched strokes replace 64 gradient/glow passes per frame.
enum EspaceVectorRenderer {
    struct Group { let path: CGPath; let width: CGFloat; let opacity: CGFloat }
    static func groups(_ motif: OndeMotif, time: Double, quality: OndeMotionQuality) -> [Group] {
        // Build the four batched paths directly. The previous implementation
        // allocated 32 stroke arrays and ~3,600 point values every frame, only
        // to immediately copy them into CGPaths.
        let paths = (0..<4).map { _ in CGMutablePath() }
        let t = time.isFinite ? time : 0
        let phase = t.truncatingRemainder(dividingBy: motif.period) / motif.period * .pi * 2
        let lines = quality.lines, samples = quality.samples
        let intensity = 0.85
        for i in 0..<lines {
            let f = Double(i) / Double(lines - 1)
            let opacity = 0.30 + 0.56 * sin((0.10 + f * 0.86) * .pi)
            let wide = i % 7 == 0
            let bucket = (wide ? 2 : 0) + (opacity > 0.66 ? 1 : 0)
            let path = paths[bucket]
            for j in 0...samples {
                let p = OndeMotionGeometry.point(motif,
                    u: Double(j) / Double(samples),
                    f: f,
                    sideSign: i % 2 == 0 ? 1 : -1,
                    phase: phase,
                    intensity: intensity)
                let point = CGPoint(x: p.x, y: p.y)
                if j == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            if motif.isClosed { path.closeSubpath() }
        }
        return paths.enumerated().map { i, p in
            Group(path: p, width: i < 2 ? 0.88 : 1.35, opacity: i % 2 == 0 ? 0.48 : 0.80)
        }
    }
    static func bounds(_ size: CGSize, motif: OndeMotif, thumbnail: Bool = false) -> CGRect {
        let aspect = MusicArtworkIdentity.aspect(motif)
        let width = min(size.width * 0.96, size.height * (thumbnail ? 0.94 : 1.08) / aspect)
        let height = width * aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2 - (thumbnail ? 0 : 8), width: width, height: height)
    }
    static func color(_ motif: OndeMotif) -> NSColor {
        let hex = MusicArtworkIdentity.color(motif)
        return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                       green: CGFloat((hex >> 8) & 255) / 255,
                       blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    static func paint(_ context: CGContext, size: CGSize, motif: OndeMotif, time: Double,
                      quality: OndeMotionQuality, thumbnail: Bool = false,
                      includeGlow: Bool = false, alpha: CGFloat = 1) {
        let box = bounds(size, motif: motif, thumbnail: thumbnail)
        var transform = CGAffineTransform(a: box.width, b: 0, c: 0, d: box.height, tx: box.minX, ty: box.minY)
        let tint = color(motif)
        if includeGlow, let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [tint.withAlphaComponent(0.045 * alpha).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray,
            locations: [0, 1]) {
            let center = CGPoint(x: size.width / 2, y: size.height / 2 - 8)
            context.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                endCenter: center, endRadius: max(box.width, box.height) * 0.52,
                options: [.drawsAfterEndLocation])
        }
        let colors = [0.30, 0.85, 1.0, 0.80, 0.30].map { tint.withAlphaComponent($0).cgColor }
        guard let ink = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
                                   locations: [0, 0.27, 0.5, 0.73, 1]) else { return }
        let phase = (time.isFinite ? time : 0) / motif.period * .pi * 2
        let slide = 0.08 * sin(phase)
        let start = CGPoint(x: box.minX + box.width * slide, y: box.minY)
        let end = CGPoint(x: box.maxX + box.width * slide, y: box.maxY)
        for group in groups(motif, time: time, quality: quality) {
            guard let path = group.path.copy(using: &transform) else { continue }
            context.saveGState()
            context.setAlpha(group.opacity * alpha)
            context.setLineWidth(thumbnail ? group.width * 0.65 : group.width)
            context.setLineJoin(.round); context.setLineCap(.round)
            context.addPath(path); context.replacePathWithStrokedPath(); context.clip()
            context.drawLinearGradient(ink, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        }
    }
}

/// Covers are immutable, bounded to < 2 MB and never re-render on stopwatch ticks.
@MainActor enum EspacePosterCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>(); cache.countLimit = 32; cache.totalCostLimit = 2_000_000; return cache
    }()
    static func image(_ motif: OndeMotif) -> NSImage {
        let key = motif.rawValue as NSString
        if let image = cache.object(forKey: key) { return image }
        let width = 92, height = 104
        // Use a pixel-space context explicitly: NSGraphicsContext(bitmap:) can
        // already apply the representation's point-to-pixel transform. Applying
        // Retina scale a second time clips the motif at the top and right edges.
        let c = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.clear(CGRect(x: 0, y: 0, width: width, height: height))
        c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 2, y: -2)
        EspaceVectorRenderer.paint(c, size: CGSize(width: 46, height: 52), motif: motif, time: 0, quality: .thumbnail, thumbnail: true)
        let image = NSImage(cgImage: c.makeImage()!, size: NSSize(width: 46, height: 52))
        cache.setObject(image, forKey: key, cost: width * height * 4)
        return image
    }
}
