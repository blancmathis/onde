import SwiftUI
import OndeCore

enum Theme {
    static let background = Color(hex: 0x202623)
    static let sidebar = Color(hex: 0x171D1A)
    static let panel = Color(hex: 0x2A322D)
    static let raised = Color(hex: 0x343D36)
    static let ink = Color(hex: 0xF4F2E9)
    static let muted = Color(hex: 0xAEB9AE)
    static let line = Color.white.opacity(0.085)
    static let accent = Color(hex: 0xD0E7BA)
    static func accent(_ mode: SessionMode) -> Color { switch mode { case .focus: return Color(hex: 0xD0E7BA); case .relax: return Color(hex: 0xEBCBB1); case .meditation: return Color(hex: 0xD0CBEA) } }
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.muted
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(color) }
}
struct PillButton: View {
    var title: String
    var symbol: String
    var primary = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 10)
                .foregroundStyle(primary ? Theme.sidebar : Theme.ink)
                .background(primary ? Theme.accent : Theme.raised, in: Capsule())
        }.buttonStyle(.plain)
    }
}
struct Panel<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.padding(24).background(Theme.panel, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1)) }
}
struct SoundArtwork: View {
    var sound: Sound
    var height: CGFloat = 115
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { ctx, size in
                for line in 0..<18 {
                    var path = Path()
                    for step in 0...100 {
                        let x = CGFloat(step) / 100 * size.width
                        let progress = x / size.width
                        let y = size.height * (0.18 + Double(line) * 0.042) + sin(progress * .pi * 2.1 + Double(line) * 0.15) * size.height * 0.16
                        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(path, with: .color(.white.opacity(line % 3 == 0 ? 0.22 : 0.10)), lineWidth: 0.8)
                }
                let circle = CGRect(x: size.width * 0.66, y: -size.height * 0.18, width: size.height * 0.9, height: size.height * 0.9)
                ctx.fill(Path(ellipseIn: circle), with: .color(.white.opacity(0.055)))
            }
            Image(systemName: sound.symbol).font(.system(size: 23, weight: .ultraLight)).foregroundStyle(.white.opacity(0.87))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(18)
        }.frame(height: height).clipped().accessibilityHidden(true)
    }
    var colors: [Color] {
        switch sound.id {
        case "piano", "dreams": return [Color(hex: 0x5D525F), Color(hex: 0x343640)]
        case "rain", "pink": return [Color(hex: 0x4B6864), Color(hex: 0x2B4140)]
        case "ocean": return [Color(hex: 0x4A6977), Color(hex: 0x303D44)]
        case "orbit": return [Color(hex: 0x725B4D), Color(hex: 0x473B36)]
        case "brown", "almost": return [Color(hex: 0x716B53), Color(hex: 0x494936)]
        default: return [Color(hex: 0x6B7860), Color(hex: 0x3F5144)]
        }
    }
}
struct OrbitalArt: View {
    var mode: SessionMode
    var animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !animated || reduceMotion)) { timeline in
            let t = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.53, y: size.height * 0.55)
                let radius = min(size.width, size.height) * 0.35
                let tint = Theme.accent(mode)
                for i in (0..<42).reversed() {
                    let fraction = Double(i) / 42
                    let r = radius * (0.25 + fraction * 0.8)
                    let drift = sin(t * 0.06 + fraction * 3.3) * radius * 0.09
                    var p = Path()
                    for j in 0...180 {
                        let theta = Double(j) / 180 * .pi * 2
                        let organic = 1 + 0.06 * sin(theta * 3 + fraction * 2.4 + t * 0.035)
                        let x = center.x + cos(theta) * r * organic + drift
                        let y = center.y + sin(theta) * r * 0.81 * organic + cos(fraction * 3) * radius * 0.05
                        if j == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    p.closeSubpath()
                    context.stroke(p, with: .color(tint.opacity(0.12 + fraction * 0.38)), lineWidth: i % 5 == 0 ? 1.1 : 0.65)
                }
                let dot = CGRect(x: center.x + radius * 0.67, y: center.y - radius * 0.58, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(tint))
            }
        }.accessibilityHidden(true)
    }
}
