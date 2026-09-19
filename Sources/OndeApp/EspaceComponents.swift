import SwiftUI
import AppKit
import Combine
import OndeCore

/// Scoped palette. Legacy screens keep working; no external assets or fonts.
enum EspaceTheme {
    static let background = Color(hex: 0x111718)
    static let surface = Color(hex: 0x192122)
    static let raised = Color(hex: 0x232E2D)
    static let ink = Color(hex: 0xEFF1E9)
    static let secondary = Color(hex: 0xA3AFAD)
    static let line = Color(hex: 0x303B3B)
    static func accent(_ mode: SessionMode) -> Color {
        switch mode { case .focus: return Color(hex: 0xC6DFC2); case .relax: return Color(hex: 0xE7CBB1); case .meditation: return Color(hex: 0xD3CBE9) }
    }
    static func shade(_ mode: SessionMode, light: Double) -> Color {
        let a: [Double]; let b: [Double]
        switch mode {
        case .focus: a = [175, 212, 173]; b = [43, 83, 70]
        case .relax: a = [222, 188, 150]; b = [98, 73, 57]
        case .meditation: a = [190, 186, 220]; b = [66, 69, 106]
        }
        return Color(.sRGB, red: (b[0] + (a[0] - b[0]) * light) / 255,
                     green: (b[1] + (a[1] - b[1]) * light) / 255,
                     blue: (b[2] + (a[2] - b[2]) * light) / 255, opacity: 1)
    }
}

struct EspaceButtonStyle: ButtonStyle {
    var primary = false
    var tint = EspaceTheme.accent(.focus)
    func makeBody(configuration: Configuration) -> some View {
        EspaceButtonBody(configuration: configuration, primary: primary, tint: tint)
    }
    private struct EspaceButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let primary: Bool
        let tint: Color
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused
        @Environment(\.espaceReduceMotion) private var reduced
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hovered = false
        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: primary ? .semibold : .medium))
                .padding(.horizontal, primary ? 21 : 13).frame(minHeight: primary ? 46 : 38)
                .foregroundStyle(primary ? EspaceTheme.background : EspaceTheme.ink)
                .background(primary ? tint : hovered ? EspaceTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(focused ? tint : primary ? .clear : contrast == .increased ? EspaceTheme.secondary : EspaceTheme.line, lineWidth: focused ? 2 : 1))
                .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
                .scaleEffect(configuration.isPressed && !reduced ? 0.985 : 1)
                .animation(reduced ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

struct EspaceIconButton: View {
    let symbol: String
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 15, weight: .regular)).frame(width: 32, height: 38) }
            .buttonStyle(.borderless).foregroundStyle(EspaceTheme.secondary)
            .accessibilityLabel(title).help(title)
    }
}

/// The animation clock is scoped to the decorative surface.
@MainActor final class EspaceMotionDriver: ObservableObject {
    @Published private(set) var time: Double = 0
    private var clock = EspaceClock()
    private var timer: Timer?
    private var rate = 0
    func configure(fps: Int) {
        guard fps != rate || (fps > 0 && timer == nil) else { return }
        timer?.invalidate(); timer = nil; rate = fps; clock.suspend()
        guard fps > 0 else { return }
        let timer = Timer(timeInterval: 1 / Double(fps), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.rate > 0 else { return }
                self.clock.tick(now: ProcessInfo.processInfo.systemUptime, running: true)
                self.time = self.clock.elapsed
            }
        }
        timer.tolerance = 1 / Double(fps) * 0.15
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func stop() { configure(fps: 0) }
    deinit { timer?.invalidate() }
}

private struct EspaceWindowProbe: NSViewRepresentable {
    let changed: (Bool) -> Void
    func makeNSView(context: Context) -> Probe { let view = Probe(); view.changed = changed; return view }
    func updateNSView(_ view: Probe, context: Context) { view.changed = changed }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.detach() }
    final class Probe: NSView {
        var changed: (Bool) -> Void = { _ in }
        private var observer: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); detach()
            guard let window else { publish(false); return }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            refresh()
        }
        func refresh() { publish(window.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } ?? false) }
        private func publish(_ visible: Bool) { DispatchQueue.main.async { [weak self] in self?.changed(visible) } }
        func detach() { if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}

struct EspaceArtwork: View {
    let id: String
    let mode: SessionMode
    let enabled: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.espaceReduceMotion) private var reduced
    @StateObject private var driver = EspaceMotionDriver()
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    private var fps: Int { EspaceMotionPolicy.fps(visible: visible, active: scenePhase == .active, enabled: enabled, reduced: reduced, lowPower: lowPower, hot: hot) }
    var body: some View {
        EspaceSurface(id: id, mode: mode, time: driver.time, economical: lowPower)
            .id(id).transition(.opacity)
            .animation(reduced ? nil : .easeInOut(duration: 0.4), value: id)
            .background(EspaceWindowProbe { visible = $0 }.frame(width: 0, height: 0))
            .onAppear { driver.configure(fps: fps) }
            .onChange(of: fps) { _, rate in driver.configure(fps: rate) }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue }
            .onDisappear { driver.stop() }
            .accessibilityHidden(true).allowsHitTesting(false)
    }
}

/// Deterministic rendering shared by the live view and offline native captures.
struct EspaceSurface: View {
    let id: String
    let mode: SessionMode
    var time: Double = 0
    var economical = false
    var body: some View {
        Canvas { context, size in
            let count = economical ? 28 : 56
            let samples = economical ? 48 : 84
            let seed = ListeningDesign.seed(id)
            for i in 0..<count {
                let points = EspaceGeometry.band(index: i, count: count, samples: samples, time: time, seed: seed)
                var path = Path()
                for (j, p) in points.enumerated() {
                    let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
                    if j == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                let v = Double(i) / Double(count)
                let shade = EspaceTheme.shade(mode, light: 0.2 + 0.8 * pow(sin(v * .pi), 2))
                let gradient = Gradient(stops: [.init(color: shade.opacity(0.02), location: 0), .init(color: shade.opacity(0.90), location: 0.38), .init(color: shade.opacity(0.72), location: 0.68), .init(color: .clear, location: 1)])
                context.fill(path, with: .linearGradient(gradient, startPoint: CGPoint(x: size.width * 0.08, y: 0), endPoint: CGPoint(x: size.width * 0.93, y: 0)))
            }
        }
        .background(RadialGradient(colors: [EspaceTheme.accent(mode).opacity(0.045), .clear], center: .center, startRadius: 0, endRadius: 230))
        .accessibilityHidden(true)
    }
}

struct EspaceThumbnail: View {
    let id: String
    let mode: SessionMode
    var body: some View { EspaceCover(id: id) }
}
