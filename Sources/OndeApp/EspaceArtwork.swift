import SwiftUI
import AppKit
import OndeCore

/// This clock belongs exclusively to the artwork. It never advances SessionClock.
@MainActor final class EspaceMotionDriver: ObservableObject {
    private(set) var time: Double = 0
    var onFrame: (() -> Void)?
    private var clock = EspaceClock()
    var musicID = "personal"
    var motif = "laminar"
    private var timer: Timer?
    private(set) var rate = 0
    private var generation: UInt64 = 0
    init() {
        EspaceMotionAudit.register(self)
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
            // This timer is installed only on the main RunLoop below. Avoid
            // allocating a Swift concurrency Task for every visual frame.
            MainActor.assumeIsolated {
                guard let self, self.rate > 0, self.generation == ticket else { return }
                self.clock.tick(now: ProcessInfo.processInfo.systemUptime, running: true)
                self.time = self.clock.elapsed
                self.onFrame?()
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
    func updateNSView(_ view: Probe, context: Context) { view.changed = changed }
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
        private var previousBounds = CGRect.null
        override func layout() {
            super.layout()
            if bounds != previousBounds { previousBounds = bounds; requestRefresh() }
        }
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
                // The probe only exists while the artwork is attached. Window-level
                // visibility is more stable than NSView.visibleRect during SwiftUI relayout.
                let shown = self.attached && self.window?.isVisible == true &&
                    self.window?.isMiniaturized == false &&
                    self.window?.occlusionState.contains(.visible) == true && !NSApp.isHidden
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
            EspaceLiveSurface(driver: driver, motif: motif, economical: retainedEconomy)
        }
        .background {
            GeometryReader { geometry in
                EspaceArtworkWindowProbe { visibility = $0 }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear { appeared = true; synchronize() }
        .onChange(of: fps) { _, _ in synchronize() }
        .onChange(of: id) { _, _ in synchronize() }
        .onChange(of: motif) { _, _ in synchronize() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue }
        .onDisappear { appeared = false; driver.stop() }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
    private func synchronize() {
        driver.musicID = id; driver.motif = motif.rawValue
        #if ONDE_DESIGN_CAPTURE
        print("ARTWORK id=\(id) appeared=\(appeared) visibility=\(visibility) enabled=\(enabled) reduced=\(reduced) hot=\(hot) lowPower=\(lowPower) fps=\(fps)")
        #endif
        // Do not change line density while the visual is paused.
        if fps > 0 { retainedEconomy = fps <= 12 }
        driver.configure(fps: fps)
    }
}

/// Animated production surface. The animation clock invalidates only this AppKit
/// view; SwiftUI's listening hierarchy no longer recomputes 12–24 times/second.
private struct EspaceLiveSurface: NSViewRepresentable {
    let driver: EspaceMotionDriver
    let motif: OndeMotif
    let economical: Bool

    func makeNSView(context: Context) -> PaintView {
        let view = PaintView()
        view.setAccessibilityElement(false)
        view.driver = driver
        view.setMotif(motif)
        view.economical = economical
        driver.onFrame = { [weak view] in view?.needsDisplay = true }
        return view
    }

    func updateNSView(_ view: PaintView, context: Context) {
        view.driver = driver
        view.setMotif(motif)
        view.economical = economical
        driver.onFrame = { [weak view] in view?.needsDisplay = true }
        view.needsDisplay = true
    }

    static func dismantleNSView(_ view: PaintView, coordinator: ()) {
        if view.driver?.onFrame != nil { view.driver?.onFrame = nil }
        view.driver = nil
    }

    final class PaintView: NSView {
        weak var driver: EspaceMotionDriver?
        private var motif: OndeMotif = .laminar
        private var hasMotif = false
        private var previousMotif: OndeMotif?
        private var transitionStart: Double = 0
        var economical = false

        func setMotif(_ value: OndeMotif) {
            guard !hasMotif || value != motif else { return }
            if !hasMotif || (driver?.rate ?? 0) == 0 {
                motif = value
                hasMotif = true
                previousMotif = nil
                needsDisplay = true
                return
            }
            previousMotif = motif
            motif = value
            transitionStart = ProcessInfo.processInfo.systemUptime
            needsDisplay = true
        }

        override var isFlipped: Bool { true }
        override var isOpaque: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func paint(_ motif: OndeMotif, alpha: CGFloat, context: CGContext) {
            EspaceVectorRenderer.paint(context, size: bounds.size, motif: motif,
                time: driver?.time ?? 0,
                quality: economical ? .economy : .balanced,
                includeGlow: true,
                alpha: alpha)
        }

        override func draw(_ dirtyRect: NSRect) {
            guard bounds.width > 0, bounds.height > 0,
                  let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            context.clip(to: bounds)
            context.setShouldAntialias(true)
            if let previousMotif {
                let progress = min(1, max(0,
                    (ProcessInfo.processInfo.systemUptime - transitionStart) / 0.45))
                paint(previousMotif, alpha: 1 - progress, context: context)
                paint(motif, alpha: progress, context: context)
                if progress >= 1 { self.previousMotif = nil }
            } else {
                paint(motif, alpha: 1, context: context)
            }
            context.restoreGState()
        }
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
            let box = EspaceVectorRenderer.bounds(size, motif: motif)
            let width = box.width, height = box.height, ox = box.minX, oy = box.minY
            let t = time.isFinite ? time : 0
            let phase = t.truncatingRemainder(dividingBy: motif.period) / motif.period * .pi * 2
            let tint = Color(hex: MusicArtworkIdentity.color(motif))
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
            var transform = CGAffineTransform(a: width, b: 0, c: 0, d: height, tx: ox, ty: oy)
            for group in EspaceVectorRenderer.groups(motif, time: t, quality: quality) {
                guard let path = group.path.copy(using: &transform) else { continue }
                var layer = context; layer.opacity = group.opacity
                layer.stroke(Path(path), with: ink, style: StrokeStyle(lineWidth: group.width, lineCap: .round, lineJoin: .round))
            }
        }.clipped().accessibilityHidden(true)
            }
        }
    }
}

/// Read-only instrumentation. No synthetic time injection or extra timer.
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
    static var snapshot: [[String: Any]] {
        live.map { ["music_id": $0.musicID, "motif": $0.motif, "fps": $0.rate, "time": $0.time] }
    }
}
