import SwiftUI
import AppKit
import OndeCore

/// This clock belongs exclusively to the artwork. It never advances SessionClock.
@MainActor final class EspaceMotionDriver: ObservableObject {
    @Published private(set) var time: Double = 0
    private var clock = EspaceClock()
    private var timer: Timer?
    private(set) var rate = 0
    private var generation: UInt64 = 0
    init() {
        #if ONDE_DESIGN_CAPTURE
        EspaceMotionAudit.register(self)
        #endif
    }
    func configure(fps: Int) {
        let fps = min(60, max(0, fps))
        guard fps != rate || (fps > 0 && timer == nil) else { return }
        generation &+= 1
        let ticket = generation
        timer?.invalidate(); timer = nil; rate = fps; clock.suspend()
        guard fps > 0 else { return }
        clock.tick(now: ProcessInfo.processInfo.systemUptime, running: true)
        let timer = Timer(timeInterval: 1 / Double(fps), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                // A queued tick from a cancelled timer cannot move a paused image.
                guard let self, self.rate > 0, self.generation == ticket else { return }
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

struct EspaceWindowVisibility: Equatable {
    var visible = false
    var active = false
}

/// Measure this surface's actual window, not NSApp.windows.first or MenuBarExtra's scene.
/// The nonzero background probe also survives window reattachment and relayout.
struct EspaceArtworkWindowProbe: NSViewRepresentable {
    let changed: (EspaceWindowVisibility) -> Void
    func makeNSView(context: Context) -> Probe {
        let view = Probe(); view.changed = changed
        view.identifier = NSUserInterfaceItemIdentifier("onde-artwork-window-probe")
        return view
    }
    func updateNSView(_ view: Probe, context: Context) { view.changed = changed; view.requestRefresh() }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.detach() }
    final class Probe: NSView {
        var changed: (EspaceWindowVisibility) -> Void = { _ in }
        private var observers: [NSObjectProtocol] = []
        private var previous: EspaceWindowVisibility?
        private var refreshPending = false
        private var attached = false
        #if ONDE_DESIGN_CAPTURE
        private var lastDiagnostic = ""
        #endif
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); attach() }
        override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); requestRefresh() }
        override func layout() { super.layout(); requestRefresh() }
        private func attach() {
            detach(); attached = window != nil; previous = nil
            guard let window else { requestRefresh(); return }
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didResignKeyNotification, NSWindow.didBecomeMainNotification,
                         NSWindow.didResignMainNotification, NSWindow.didExposeNotification,
                         NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
                observe(name, object: window)
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                         NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
                observe(name, object: nil)
            }
            requestRefresh()
        }
        private func observe(_ name: Notification.Name, object: Any?) {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.requestRefresh() }
            })
        }
        func requestRefresh() {
            guard !refreshPending else { return }
            refreshPending = true
            // Evaluate at delivery time, so stale pre-attachment/occlusion events cannot win.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshPending = false
                let shown = self.attached && self.window?.isVisible == true && self.window?.isMiniaturized == false &&
                    self.window?.occlusionState.contains(.visible) == true && !NSApp.isHidden &&
                    !self.isHiddenOrHasHiddenAncestor && !self.visibleRect.isEmpty
                #if ONDE_DESIGN_CAPTURE
                let diagnostic = "PROBE title=\(self.window?.title ?? "nil") attached=\(self.attached) frame=\(self.frame) visibleRect=\(self.visibleRect) windowVisible=\(self.window?.isVisible == true) mini=\(self.window?.isMiniaturized == true) exposed=\(self.window?.occlusionState.contains(.visible) == true) appHidden=\(NSApp.isHidden) viewHidden=\(self.isHiddenOrHasHiddenAncestor) active=\(NSApp.isActive)"
                if diagnostic != self.lastDiagnostic { print(diagnostic); self.lastDiagnostic = diagnostic }
                #endif
                let value = EspaceWindowVisibility(visible: shown, active: NSApp.isActive)
                guard value != self.previous else { return }
                self.previous = value
                self.changed(value)
            }
        }
        func detach() {
            attached = false
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
        }
        deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    }
}

struct EspaceArtwork: View {
    let id: String
    let mode: SessionMode
    let enabled: Bool
    var choice = "automatic"
    @Environment(\.espaceReduceMotion) private var appReduced
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @StateObject private var driver = EspaceMotionDriver()
    @State private var visibility = EspaceWindowVisibility()
    @State private var appeared = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    @State private var retainedEconomy = false
    private var reduced: Bool { appReduced || systemReduced }
    private var motif: OndeMotif { EspaceArtworkSelection.motif(choice: choice, musicID: id, mode: mode) }
    private var fps: Int {
        EspaceMotionPolicy.fps(visible: appeared && visibility.visible, active: visibility.active,
                              enabled: enabled, reduced: reduced, lowPower: lowPower, hot: hot)
    }
    var body: some View {
        ZStack {
            EspaceSurface(id: id, mode: mode, time: driver.time, economical: retainedEconomy, motifOverride: motif)
                .id(motif).transition(.opacity)
        }
        .animation(reduced || !enabled ? nil : .easeInOut(duration: 0.45), value: motif)
        .background {
            GeometryReader { geometry in
                EspaceArtworkWindowProbe { visibility = $0 }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear { appeared = true; synchronize() }
        .onChange(of: fps) { _, _ in synchronize() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue }
        .onDisappear { appeared = false; driver.stop() }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
    private func synchronize() {
        #if ONDE_DESIGN_CAPTURE
        print("ARTWORK id=\(id) appeared=\(appeared) visibility=\(visibility) enabled=\(enabled) reduced=\(reduced) hot=\(hot) lowPower=\(lowPower) fps=\(fps)")
        #endif
        // Do not change line density while the visual is paused.
        if fps > 0 { retainedEconomy = fps <= 12 }
        driver.configure(fps: fps)
    }
}

/// Courants II is rendered directly into the Espace listening pane, without videos.
/// Width is used for open currents; closed motifs retain their intended proportions.
struct EspaceSurface: View {
    let id: String
    let mode: SessionMode
    var time: Double = 0
    var economical = false
    var motifOverride: OndeMotif?
    var body: some View {
        Group {
            if EspaceRenderingSupport.needsSoftwareCanvas {
                EspaceSoftwareSurface(id: id, mode: mode, time: time, economical: economical, motifOverride: motifOverride)
            } else {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let motif = motifOverride ?? OndeMotif.forMusic(id, meditation: mode == .meditation)
            let quality: OndeMotionQuality = economical ? .economy : .balanced
            let width = motif.isClosed || motif == .reverie || motif == .sanctuary
                ? min(size.width * 0.92, size.height * 1.08) : size.width * 0.96
            let height = motif.isClosed || motif == .reverie || motif == .sanctuary ? width : min(size.height * 0.96, width * 0.61)
            let ox = (size.width - width) / 2, oy = (size.height - height) / 2 - 8
            let t = time.isFinite ? time : 0
            let phase = t.truncatingRemainder(dividingBy: motif.period) / motif.period * .pi * 2
            let tint = EspaceTheme.accent(mode)
            let slide = 0.15 * sin(phase), tilt = 0.12 * cos(phase)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(stops: [
                .init(color: tint.opacity(0.045), location: 0), .init(color: .clear, location: 1)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2 - 8), startRadius: 0, endRadius: max(width, height) * 0.52))
            let ink = GraphicsContext.Shading.linearGradient(Gradient(stops: [
                .init(color: tint.opacity(0.16), location: 0), .init(color: tint.opacity(0.50), location: 0.25),
                .init(color: tint.opacity(0.96), location: 0.48), .init(color: tint, location: 0.56),
                .init(color: tint.opacity(0.48), location: 0.76), .init(color: tint.opacity(0.16), location: 1)]),
                startPoint: CGPoint(x: ox + width * (-0.08 + slide), y: oy + height * (0.12 + tilt)),
                endPoint: CGPoint(x: ox + width * (1.08 + slide), y: oy + height * (0.88 - tilt)))
            for stroke in OndeMotionGeometry.strokes(motif, time: t, quality: quality, intensity: 0.85) {
                var path = Path()
                for (i, p) in stroke.points.enumerated() {
                    let point = CGPoint(x: ox + p.x * width, y: oy + p.y * height)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                if stroke.closed { path.closeSubpath() }
                var layer = context
                layer.opacity = stroke.opacity
                layer.stroke(path, with: ink, style: StrokeStyle(lineWidth: stroke.width * 1.12, lineCap: .round, lineJoin: .round))
                if !economical {
                    layer.opacity = stroke.opacity * 0.10
                    layer.stroke(path, with: ink, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                }
            }
        }.clipped().accessibilityHidden(true)
            }
        }
    }
}

#if ONDE_DESIGN_CAPTURE
/// Read-only instrumentation, excluded from production. No synthetic time injection.
@MainActor enum EspaceMotionAudit {
    private final class WeakDriver {
        weak var value: EspaceMotionDriver?
        init(_ value: EspaceMotionDriver) { self.value = value }
    }
    private static var drivers: [WeakDriver] = []
    static func register(_ driver: EspaceMotionDriver) {
        drivers.removeAll { $0.value == nil }; drivers.append(WeakDriver(driver))
    }
    static var live: [EspaceMotionDriver] { drivers.compactMap(\.value) }
    static var running: [EspaceMotionDriver] { live.filter { $0.rate > 0 } }
}
#endif
