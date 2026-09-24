#if ONDE_DESIGN_CAPTURE
import AppKit
import OndeCore

/// Regression checks run in the muted native design fixture, not the user profile.
@MainActor enum EspaceRendererChecks {
    static func geometry() throws -> Int {
        var checked = 0
        for motif in OndeMotif.allCases {
            for quality in [OndeMotionQuality.thumbnail, .economy, .balanced] {
                for time in [-0.5, 0, 0.37, motif.period / 2, motif.period] {
                    let reference = (0..<4).map { _ in CGMutablePath() }
                    for stroke in OndeMotionGeometry.strokes(motif, time: time, quality: quality, intensity: 0.85) {
                        let bucket = (stroke.width > 1 ? 2 : 0) + (stroke.opacity > 0.66 ? 1 : 0)
                        for (i, p) in stroke.points.enumerated() {
                            let point = CGPoint(x: p.x, y: p.y)
                            if i == 0 { reference[bucket].move(to: point) }
                            else { reference[bucket].addLine(to: point) }
                        }
                        if stroke.closed { reference[bucket].closeSubpath() }
                    }
                    let actual = EspaceVectorRenderer.groups(motif, time: time, quality: quality)
                    for i in 0..<4 {
                        guard elements(actual[i].path) == elements(reference[i]) else {
                            throw NSError(domain: "Renderer changed original contour: \(motif.rawValue)/\(quality)/\(time)", code: 1)
                        }
                    }
                    checked += 1
                }
            }
        }
        return checked
    }
    private static func elements(_ path: CGPath) -> [Double] {
        var result: [Double] = []
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            result.append(Double(element.type.rawValue))
            let count: Int
            switch element.type {
            case .moveToPoint, .addLineToPoint: count = 1
            case .addQuadCurveToPoint: count = 2
            case .addCurveToPoint: count = 3
            case .closeSubpath: count = 0
            @unknown default: count = 0
            }
            for i in 0..<count { result += [element.points[i].x, element.points[i].y] }
        }
        return result
    }
    static func bindingLifetime() async throws {
        let driver = EspaceMotionDriver(), oldOwner = UUID(), currentOwner = UUID()
        var oldFrames = 0, currentFrames = 0
        driver.bindFrame(owner: oldOwner) { oldFrames += 1 }
        driver.bindFrame(owner: currentOwner) { currentFrames += 1 }
        driver.unbindFrame(owner: oldOwner)
        driver.configure(fps: 24)
        try await Task.sleep(nanoseconds: 350_000_000)
        guard oldFrames == 0, currentFrames > 0 else {
            driver.stop(); throw NSError(domain: "Stale surface disconnected current frame receiver", code: 2)
        }
        driver.unbindFrame(owner: currentOwner)
        let frozen = currentFrames
        try await Task.sleep(nanoseconds: 160_000_000)
        driver.stop()
        guard currentFrames == frozen else { throw NSError(domain: "Detached surface still receives frames", code: 3) }
    }
}
#endif
