import AppKit
import SwiftUI
import Metal
import OndeCore

/// Older Intel virtual GPUs advertise Metal 2 but crash inside Apple's Canvas
/// shader loader. Keep the same vectors and clock using Core Graphics there.
/// No global renderer setting, user preference, animation or audio is disabled.
enum EspaceRenderingSupport {
    static let needsSoftwareCanvas: Bool = {
        guard let device = MTLCreateSystemDefaultDevice() else { return true }
        #if arch(x86_64)
        if #available(macOS 26, *) { return false }
        return device.name.lowercased().contains("paravirtual")
        #else
        return false
        #endif
    }()
}

private struct EspaceCGCanvas: NSViewRepresentable {
    var draw: (CGContext, CGSize) -> Void
    func makeNSView(context: Context) -> PaintView {
        let view = PaintView(); view.paint = draw
        view.setAccessibilityElement(false)
        return view
    }
    func updateNSView(_ view: PaintView, context: Context) { view.paint = draw; view.needsDisplay = true }
    final class PaintView: NSView {
        var paint: (CGContext, CGSize) -> Void = { _, _ in }
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            context.clip(to: bounds)
            context.setShouldAntialias(true)
            paint(context, bounds.size)
            context.restoreGState()
        }
    }
}

struct EspaceSoftwareSurface: View {
    let id: String
    let mode: SessionMode
    let time: Double
    let economical: Bool
    let motifOverride: OndeMotif?
    var body: some View {
        EspaceCGCanvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let motif = motifOverride ?? OndeMotif.forMusic(id, meditation: mode == .meditation)
            let width = motif.isClosed || motif == .reverie || motif == .sanctuary
                ? min(size.width * 0.92, size.height * 1.08) : size.width * 0.96
            let height = motif.isClosed || motif == .reverie || motif == .sanctuary ? width : min(size.height * 0.96, width * 0.61)
            let ox = (size.width - width) / 2, oy = (size.height - height) / 2 - 8
            let t = time.isFinite ? time : 0
            let phase = t.truncatingRemainder(dividingBy: motif.period) / motif.period * .pi * 2
            let tint = NSColor(EspaceTheme.accent(mode)).usingColorSpace(.sRGB) ?? .white
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            let haloColors = [tint.withAlphaComponent(0.045).cgColor, tint.withAlphaComponent(0).cgColor]
            if let halo = CGGradient(colorsSpace: space, colors: haloColors as CFArray, locations: [0, 1]) {
                let center = CGPoint(x: size.width / 2, y: size.height / 2 - 8)
                context.drawRadialGradient(halo, startCenter: center, startRadius: 0,
                                           endCenter: center, endRadius: max(width, height) * 0.52, options: [])
            }
            let alpha: [CGFloat] = [0.16, 0.50, 0.96, 1, 0.48, 0.16]
            let colors = alpha.map { tint.withAlphaComponent($0).cgColor }
            guard let ink = CGGradient(colorsSpace: space, colors: colors as CFArray,
                                       locations: [0, 0.25, 0.48, 0.56, 0.76, 1]) else { return }
            let slide = 0.15 * sin(phase), tilt = 0.12 * cos(phase)
            let start = CGPoint(x: ox + width * (-0.08 + slide), y: oy + height * (0.12 + tilt))
            let end = CGPoint(x: ox + width * (1.08 + slide), y: oy + height * (0.88 - tilt))
            for stroke in OndeMotionGeometry.strokes(motif, time: t, quality: economical ? .economy : .balanced, intensity: 0.85) {
                let path = CGMutablePath()
                for (index, point) in stroke.points.enumerated() {
                    let p = CGPoint(x: ox + point.x * width, y: oy + point.y * height)
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                if stroke.closed { path.closeSubpath() }
                func paint(width: CGFloat, opacity: CGFloat) {
                    context.saveGState()
                    context.setAlpha(opacity)
                    context.setLineWidth(width); context.setLineCap(.round); context.setLineJoin(.round)
                    context.addPath(path); context.replacePathWithStrokedPath(); context.clip()
                    context.drawLinearGradient(ink, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                    context.restoreGState()
                }
                paint(width: stroke.width * 1.12, opacity: stroke.opacity)
                if !economical { paint(width: 2.8, opacity: stroke.opacity * 0.10) }
            }
        }.clipped().accessibilityHidden(true)
    }
}

struct EspaceSoftwareCover: View {
    let family: Int
    let tint: Color
    var body: some View {
        EspaceCGCanvas { context, size in
            let color = NSColor(tint).usingColorSpace(.sRGB) ?? .white
            for line in 0..<8 {
                let f = Double(line) / 7
                let path = CGMutablePath()
                for j in 0...48 {
                    let u = Double(j) / 48, t = u * .pi * 2
                    let x: Double; let y: Double
                    switch family {
                    case 1:
                        x = 0.5 + (0.08 + f * 0.4) * cos(t); y = 0.5 + (0.11 + f * 0.36) * sin(t)
                    case 2:
                        x = 0.09 + u * 0.82; y = 0.24 + f * 0.56 + 0.15 * abs(sin(u * .pi * 2 + f * 0.25)) - u * 0.2
                    case 3:
                        x = 0.13 + f * 0.74 + 0.045 * sin(u * .pi * 2 + f); y = 0.1 + u * 0.8
                    case 4:
                        x = 0.08 + u * 0.84; y = 0.5 + (f - 0.5) * 0.82 * sin(u * .pi) - (u - 0.5) * 0.45
                    case 5:
                        x = 0.5 + (0.12 + f * 0.48) * cos(t); y = 0.5 + (0.04 + f * 0.24) * sin(t)
                    default:
                        x = u; y = 0.24 + f * 0.49 + sin(u * .pi * 2 - f * 0.25) * 0.095
                    }
                    let point = CGPoint(x: x * size.width, y: y * size.height)
                    if j == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.setStrokeColor(color.withAlphaComponent(0.32 + f * 0.35).cgColor)
                context.setLineWidth(0.65); context.addPath(path); context.strokePath()
            }
        }.accessibilityHidden(true)
    }
}
