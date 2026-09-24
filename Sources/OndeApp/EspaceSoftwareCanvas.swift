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
    var metrics: EspaceDrawMetrics? = nil
    var body: some View {
        EspaceCGCanvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let motif = motifOverride ?? OndeMotif.forMusic(id, meditation: mode == .meditation)
            EspaceVectorRenderer.paint(context, size: size, motif: motif, time: time, quality: economical ? .economy : .balanced)
            metrics?.record(motif: motif, time: time, size: size)
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
