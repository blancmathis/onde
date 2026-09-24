import AppKit
import SwiftUI
import OndeCore

/// One geometry and palette for a cover, the live player and the software fallback.
/// Four batched strokes replace 64 gradient/glow passes per frame.
enum EspaceVectorRenderer {
    struct Group { let path: CGPath; let width: CGFloat; let opacity: CGFloat }
    static func groups(_ motif: OndeMotif, time: Double, quality: OndeMotionQuality) -> [Group] {
        let paths = (0..<4).map { _ in CGMutablePath() }
        for stroke in OndeMotionGeometry.strokes(motif, time: time, quality: quality, intensity: 0.85) {
            let bucket = (stroke.width > 1 ? 2 : 0) + (stroke.opacity > 0.66 ? 1 : 0)
            let path = paths[bucket]
            for (i, p) in stroke.points.enumerated() {
                let point = CGPoint(x: p.x, y: p.y)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            if stroke.closed { path.closeSubpath() }
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
                      quality: OndeMotionQuality, thumbnail: Bool = false) {
        let box = bounds(size, motif: motif, thumbnail: thumbnail)
        var transform = CGAffineTransform(a: box.width, b: 0, c: 0, d: box.height, tx: box.minX, ty: box.minY)
        let tint = color(motif)
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
            context.setAlpha(group.opacity)
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
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: 46, height: 52)
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current = graphics
        let c = graphics.cgContext
        c.clear(CGRect(x: 0, y: 0, width: width, height: height))
        c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 2, y: -2)
        EspaceVectorRenderer.paint(c, size: CGSize(width: 46, height: 52), motif: motif, time: 0, quality: .thumbnail, thumbnail: true)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: 46, height: 52)); image.addRepresentation(bitmap)
        cache.setObject(image, forKey: key, cost: width * height * 4)
        return image
    }
}
