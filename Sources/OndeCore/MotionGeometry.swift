// Recovered Courants II geometry. Original formulas retained; see Documentation/ANIMATION-RESTORE.md.
import Foundation
public struct OndeMotionPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}
public struct OndeMotionStroke: Sendable {
    public var points: [OndeMotionPoint]
    public let closed: Bool
    public let opacity: Double
    public let width: Double
}
public enum OndeMotionGeometry {
    public static func strokes(_ motif: OndeMotif, time: Double,
                               quality: OndeMotionQuality = .balanced,
                               intensity: Double = 1) -> [OndeMotionStroke] {
        let t = time.isFinite ? time : 0
        let p = t.truncatingRemainder(dividingBy: motif.period) / motif.period * .pi * 2
        let m = intensity.isFinite ? min(1.45, max(0, intensity)) : 1
        let n = quality.lines, count = quality.samples
        var result: [OndeMotionStroke] = []; result.reserveCapacity(n)
        for i in 0..<n {
            let f = Double(i) / Double(n - 1)
            var points: [OndeMotionPoint] = []; points.reserveCapacity(count + 1)
            for j in 0...count {
                points.append(point(motif, u: Double(j) / Double(count), f: f,
                                    sideSign: i % 2 == 0 ? 1 : -1, phase: p, intensity: m))
            }
            result.append(.init(points: points, closed: motif.isClosed,
                opacity: 0.30 + 0.56 * sin((0.10 + f * 0.86) * .pi),
                width: i % 7 == 0 ? 1.25 : 0.78))
        }
        return result
    }
    public static func point(_ motif: OndeMotif, u: Double, f: Double,
                             sideSign: Double, phase p: Double, intensity m: Double) -> OndeMotionPoint {
        let PI = Double.pi, TAU = Double.pi * 2
        let theta = u * TAU
        func sign(_ x: Double) -> Double { x == 0 ? 0 : (x < 0 ? -1 : 1) }
        switch motif {
        case .driftwood:
            let r = 0.09 + 0.31 * f
            let x = 0.5 + r * cos(theta) + 0.026 * m * sin(p + f * 2)
            let y = 0.5 + r * sin(theta) * (0.38 + 0.06 * m * cos(p)) + 0.085 * cos(theta + f) + 0.025 * m * sin(theta * 2 + p)
            return .init(x, y)
        case .atlas:
            let r = 0.10 + f * 0.28
            let x = 0.5 + r * cos(theta) * (0.82 + 0.10 * cos(p))
            let y = 0.5 + r * sin(theta) + 0.075 * sin(theta * 2 + f * 2 + m * sin(p))
            return .init(x, y)
        case .ostinato:
            let env = sin(u * PI)
            return .init(0.07 + u * 0.86, 0.5 + (f - 0.5) * 0.30 + env * 0.12 * sin(u * TAU * 2 + f * 1.3 + m * sin(p)))
        case .aurora:
            let x = 0.1 + u * 0.8 + 0.035 * m * sin(p + f) * sin(u * PI)
            let y = 0.30 + f * 0.35 + 0.19 * sin(u * PI) * cos(u * PI + f * 0.9 + m * sin(p))
            return .init(x, y)
        case .chamber:
            let r = 0.10 + f * 0.26
            let exponent = 0.44 + 0.05 * m * sin(p)
            let x = sign(cos(theta)) * pow(abs(cos(theta)), exponent) * r
            let y = sign(sin(theta)) * pow(abs(sin(theta)), exponent) * r * 0.76
            let rotation = 0.12 * m * sin(p + f)
            return .init(0.5 + x * cos(rotation) - y * sin(rotation), 0.5 + x * sin(rotation) + y * cos(rotation))
        case .momentum:
            let x = 0.08 + u * 0.84
            let y = 0.5 + (f - 0.5) * 0.46 * sin(u * PI) + 0.16 * sin(u * PI * 2 + 0.6 * m * sin(p)) * sin(u * PI)
            return .init(x, y)
        case .reactor:
            let r = 0.1 + f * 0.28
            let k = 1 + 0.13 * cos(theta * 3 + f * 0.6 + 0.7 * m * sin(p))
            return .init(0.5 + cos(theta) * r * k, 0.5 + sin(theta) * r * k)
        case .traction:
            let env = sin(u * PI)
            return .init(0.12 + u * 0.76, 0.78 - u * 0.56 + (f - 0.5) * 0.35 * env + 0.09 * m * sin(p + f * 1.5) * env)
        case .anchor:
            let r = 0.095 + f * 0.30
            let x = 0.5 + r * cos(theta) * (0.82 + 0.08 * m * sin(p))
            let y = 0.53 + r * sin(theta) * 0.72 - 0.06 * cos(theta * 2) + 0.025 * m * cos(p + f * 2)
            return .init(x, y)
        case .abyss:
            let r = 0.07 + f * 0.30
            let angle = theta + 0.3 * m * sin(p - f * 3)
            return .init(0.5 + cos(angle) * r + (1 - f) * 0.09 * sin(p + f * 2), 0.5 + sin(angle) * r * 0.88 + (1 - f) * 0.07 * cos(p - f * 2))
        case .current:
            let env = sin(u * PI)
            return .init(0.07 + u * 0.86, 0.5 + (f - 0.5) * 0.34 * env + 0.13 * env * sin(u * TAU + f * 4 + 0.8 * m * sin(p)))
        case .velvet:
            let env = sin(u * PI)
            return .init(0.08 + u * 0.84, 0.26 + f * 0.48 + env * 0.14 * sin(f * PI + 0.8 * m * sin(p)) + 0.055 * m * sin(u * TAU + p) * env)
        case .shore:
            let r = 0.10 + f * 0.32
            let a = PI + u * PI
            return .init(0.5 + cos(a) * r, 0.66 + sin(a) * r * (0.53 + 0.08 * m * sin(p)) + 0.04 * m * cos(p + u * PI) * sin(u * PI))
        case .laminar:
            let env = pow(sin(u * PI), 1.25)
            let band = (f - 0.5) * (0.36 + 0.10 * m * cos(p)) * (0.35 + 0.65 * pow(cos(u * PI), 2.0))
            let x = 0.08 + u * 0.84 + env * 0.025 * m * sin(p + f)
            let y = 0.5 + band + env * ((0.13 + 0.03 * m * sin(p)) * sin(u * TAU + f * 0.9 + 0.85 * m * sin(p)) + 0.07 * m * cos(p))
            return .init(x, y)
        case .prism:
            let r = 0.105 + f * 0.265
            let cs = cos(theta)
            let sn = sin(theta)
            let exponent = 0.73 + 0.12 * m * sin(p)
            let px = sign(cs) * pow(abs(cs), exponent) * r
            let py = sign(sn) * pow(abs(sn), exponent) * r
            let angle = -PI / 4.0 + f * 0.22 + 0.34 * m * sin(p - f * 0.55)
            let x = 0.5 + px * cos(angle) - py * sin(angle)
            let y = 0.5 + (px * sin(angle) + py * cos(angle)) * (0.82 + 0.06 * m * cos(p))
            return .init(x, y)
        case .bloom:
            let r = 0.10 + f * 0.275
            let shape = 1.0 + (0.075 + 0.032 * m * cos(p)) * sin(theta * 3.0 + f * 1.8 + 0.95 * m * sin(p))
            let x = 0.5 + cos(theta) * r * shape * (1.0 + 0.07 * m * sin(p))
            let y = 0.5 + sin(theta) * r * shape * (0.88 + 0.05 * m * cos(p)) + 0.022 * m * sin(p + f * 2.0)
            return .init(x, y)
        case .tide:
            let x = 0.06 + u * 0.88
            let y = 0.35 + f * 0.30 + (0.083 + 0.029 * m * cos(p)) * sin(u * TAU - f * 1.7 + 1.1 * m * sin(p)) + sin(u * PI) * 0.065 * m * cos(p)
            return .init(x, y)
        case .canopy:
            let r = 0.115 + f * 0.285
            let leaf = 0.66 + 0.34 * cos(theta)
            let px = cos(theta) * r
            let py = sin(theta) * r * leaf * (0.8 + 0.12 * m * cos(p + f))
            let rot = -0.48 + 0.32 * m * sin(p)
            let x = 0.51 + px * cos(rot) - py * sin(rot) + 0.02 * m * sin(p + f * 3.0)
            let y = 0.5 + px * sin(rot) + py * cos(rot) + 0.04 * m * cos(p) * (1.0 - f)
            return .init(x, y)
        case .amber:
            let r = 0.11 + f * 0.29
            let px = cos(theta) * r
            let py = sin(theta) * r * (0.48 + 0.10 * m * sin(p + f * 1.1))
            let rot = -0.24 + f * 0.28 + 0.22 * m * sin(p - f * 0.9)
            let x = 0.5 + px * cos(rot) - py * sin(rot) + (1.0 - f) * 0.07 * m * cos(p)
            let y = 0.5 + px * sin(rot) + py * cos(rot) + 0.045 * m * sin(theta * 2.0 - p) * (0.4 + 0.6 * f)
            return .init(x, y)
        case .filigree:
            let env = sin(u * PI)
            let x = 0.065 + u * 0.87
            let y = 0.5 + (f - 0.5) * 0.11 + env * (0.17 + 0.035 * m * cos(p)) * sin(u * TAU + f * 3.2 + 1.1 * m * sin(p)) + env * 0.035 * m * cos(p + f)
            return .init(x, y)
        case .confluence:
            let side = sideSign
            let env = sin(u * PI)
            let x = 0.06 + u * 0.88
            let y = 0.5 + side * (0.035 + f * 0.22) * env * cos(u * PI + 0.85 * m * sin(p + side * 0.3)) + 0.06 * m * cos(p) * env
            return .init(x, y)
        case .sanctuary:
            let ang = PI + u * PI
            let r = 0.12 + f * 0.285
            let x = 0.5 + cos(ang) * r * (1.0 + 0.075 * m * sin(p - f)) + 0.055 * m * sin(p) * (1.0 - f) * sin(u * PI)
            let y = 0.69 + sin(ang) * r * (1.07 + 0.11 * m * cos(p)) - 0.045 * (1.0 - f) + 0.032 * m * sin(p + f * 2.0) * sin(u * PI)
            return .init(x, y)
        case .stillwater:
            let r = 0.065 + f * 0.345
            let x = 0.5 + cos(theta) * r + 0.045 * m * sin(f * 4.0 - p) * (1.0 - 0.25 * f)
            let y = 0.5 + sin(theta) * r * (0.48 + 0.07 * m * sin(p + f * 2.0)) + 0.055 * m * cos(p - f * 4.0) * (1.0 - 0.25 * f)
            return .init(x, y)
        case .hearth:
            let r = 0.105 + f * 0.265
            let shape = 1.0 - 0.22 * sin(theta) + 0.09 * m * sin(theta * 3.0 - p + f)
            let x = 0.5 + cos(theta) * r * shape * (0.82 + 0.055 * m * cos(p)) + 0.02 * m * sin(p) * (1.0 - f)
            let y = 0.49 + sin(theta) * r * (1.06 + 0.05 * m * sin(p)) + cos(theta * 2.0 + f) * 0.035 * m * cos(p)
            return .init(x, y)
        case .reverie:
            let env = pow(sin(u * PI), 1.2)
            let y = 0.12 + u * 0.76
            let x = 0.30 + f * 0.40 + env * ((0.09 + 0.025 * m * cos(p)) * sin(u * TAU + f * 2.5 + 1.2 * m * sin(p)) + 0.045 * m * sin(p * 2.0))
            return .init(x, y)
        }
    }
}
