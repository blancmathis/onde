import AppKit

/// Small-size optical adaptation of Tools/Icon.swift: concentric organic waves
/// plus their orbit point. One cached vector template, no animated state or title.
enum OndeStatusIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let transform = NSAffineTransform()
            transform.translateX(by: rect.minX, yBy: rect.minY)
            transform.scaleX(by: rect.width / 18, yBy: rect.height / 18)
            transform.concat()
            NSColor.black.setStroke()
            for radius in [3.1, 5.3, 7.5] {
                let path = NSBezierPath()
                for step in 0...96 {
                    let theta = Double(step) / 96 * .pi * 2
                    let organic = 1 + 0.045 * sin(theta * 3)
                    let point = NSPoint(x: 8.6 + cos(theta) * radius * organic,
                                        y: 8.7 + sin(theta) * radius * 0.80 * organic)
                    if step == 0 { path.move(to: point) } else { path.line(to: point) }
                }
                path.close(); path.lineWidth = 1.15; path.lineJoinStyle = .round
                path.stroke()
            }
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 13.3, y: 13.8, width: 2.4, height: 2.4)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Onde"
        return image
    }()
}
