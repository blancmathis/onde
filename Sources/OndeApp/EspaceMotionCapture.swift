#if ONDE_DESIGN_CAPTURE
import SwiftUI
import AppKit
import OndeCore

/// Exercises the real EspaceRootView + hosting window + natural Timer/RunLoop path.
/// Only compiled in CI. Never writes the user's defaults, launches playback or injects time.
@MainActor enum EspaceMotionCapture {
    private static var started = false
    private static var checks: [String] = []
    @discardableResult static func runIfRequested(model: AppModel) -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let outputPath = env["ONDE_MOTION_CHECK_DIR"] else { return false }
        guard !started else { return true }; started = true
        guard let homePath = env["ONDE_HOME"] else { exit(3) }
        let home = URL(fileURLWithPath: homePath).standardizedFileURL.resolvingSymlinksInPath()
        let output = URL(fileURLWithPath: outputPath).standardizedFileURL.resolvingSymlinksInPath()
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.resolvingSymlinksInPath()
        guard home.path.hasPrefix(temporary.path + "/"), output.path.hasPrefix(home.path + "/"),
              model.store.preferences.masterVolume == 0, !model.playing, !model.store.preferences.reducedMotion else {
            fputs("Unsafe live motion validation environment.\n", stderr); exit(3)
        }
        Task { @MainActor in
            do { try await run(model: model, output: output); NSApp.terminate(nil) }
            catch { fputs("Live motion validation failed: \(error)\n", stderr); exit(4) }
        }
        return true
    }
    private static func check(_ value: @autoclosure () -> Bool, _ label: String) throws {
        guard value() else { throw NSError(domain: label, code: 1) }
        checks.append(label); print("PASS", label)
    }
    private static func wait(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    private static func running(_ expected: Bool, _ label: String) async throws {
        for _ in 0..<50 {
            if (EspaceMotionAudit.running.count == 1) == expected && (expected || EspaceMotionAudit.running.isEmpty) {
                try check(true, label); return
            }
            try await wait(0.1)
        }
        let info = EspaceMotionAudit.live.map { "time=\($0.time),rate=\($0.rate)" }.joined(separator: ";")
        throw NSError(domain: "\(label): \(info)", code: 2)
    }
    private struct Frame {
        let bytes: Data
        let png: Data
    }
    private static func frame(_ host: NSView, file: URL? = nil) throws -> Frame {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds), let bytes = bitmap.bitmapData else {
            throw NSError(domain: "LiveMotionBitmap", code: 1)
        }
        let count = bitmap.bytesPerRow * bitmap.pixelsHigh
        bytes.initialize(repeating: 0, count: count)
        host.cacheDisplay(in: host.bounds,to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "LiveMotionPNG", code: 1) }
        if let file { try png.write(to: file) }
        return Frame(bytes: Data(bytes: bytes, count: count), png: png)
    }
    private static func changed(_ a: Frame, _ b: Frame) -> Int {
        guard a.bytes.count == b.bytes.count else { return Int.max }
        return zip(a.bytes, b.bytes).reduce(0) { $0 + (abs(Int($1.0) - Int($1.1)) > 3 ? 1 : 0) }
    }
    private static func run(model: AppModel, output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "onde.live-motion-validation." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "onde.espace.visualMotion")
        defaults.set(true, forKey: "onde.espace.showArtwork")
        defaults.set("automatic", forKey: "onde.espace.artworkChoice")
        model.startDefaultMode(.focus, autostart: false)
        // Allow SwiftUI to finish its initial scene presentation before ordering it out.
        try await wait(0.7)
        // Keep the app's original scene out of view; its status item still exists.
        for window in NSApp.windows where window.title == "Onde" { window.orderOut(nil) }
        let host = NSHostingView(rootView: EspaceRootView().environmentObject(model)
            .defaultAppStorage(defaults).environment(\.locale, Locale(identifier: "en")))
        let window = NSWindow(contentRect: NSRect(x: 30, y: 50, width: 1120, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Onde — live animation check"; window.contentView = host
        window.appearance = NSAppearance(named: .darkAqua)
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        try await wait(0.7)
        window.makeFirstResponder(nil)
        _ = try frame(host, file: output.appendingPathComponent("window-presented.png"))
        for window in NSApp.windows {
            print("WINDOW", window.title, "visible", window.isVisible, "mini", window.isMiniaturized,
                  "exposed", window.occlusionState.contains(.visible), "frame", window.frame)
        }
        let reducedCase = ProcessInfo.processInfo.environment["ONDE_MOTION_CASE"] == "system-reduced"
        try check(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == reducedCase,
                  "The real system accessibility preference matches this fixture")
        if reducedCase {
            try await running(false, "Actual system Reduce Motion stops the integrated artwork")
            let a = try frame(host, file: output.appendingPathComponent("system-reduced-a.png"))
            let frozen = EspaceMotionAudit.live.map(\.time)
            try await wait(0.6)
            let b = try frame(host, file: output.appendingPathComponent("system-reduced-b.png"))
            try check(changed(a,b) == 0 && frozen == EspaceMotionAudit.live.map(\.time),
                      "Actual system Reduce Motion freezes pixels and clocks")
            try check(!model.playing && model.elapsed == 0 && model.todaySeconds == 0,
                      "Reduced-motion fixture leaves music and session time stopped")
            window.orderOut(nil); window.contentView = nil; window.close()
            try await wait(0.3); try await running(false, "Reduced-motion fixture leaves no artwork clock")
            let receipt: [String: Any] = ["passed": checks.count, "checks": checks,
                "runner_system_reduce_motion": true, "muted": true,
                "scope": "Unmodified production accessibility environment in a disposable hosted Mac; no synthetic time or scene/window override."]
            try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("motion-integration.json"))
            return
        }
        try await running(true, "Full listening view starts one animation clock without playing audio")
        let first = try frame(host, file: output.appendingPathComponent("live-initial.png"))
        try await wait(0.85)
        let second = try frame(host, file: output.appendingPathComponent("live-later.png"))
        try check(changed(first,second) > 1000, "Integrated live view changes rendered pixels without synthetic time")
        var motions: [[String: Any]] = []
        for motif in OndeMotif.allCases {
            defaults.set(motif.rawValue, forKey: "onde.espace.artworkChoice")
            try await wait(0.7) // Let the actual crossfade finish, then compare motion only.
            let a = try frame(host, file: output.appendingPathComponent("\(motif.rawValue)-a.png"))
            try await wait(0.85)
            let b = try frame(host, file: output.appendingPathComponent("\(motif.rawValue)-b.png"))
            let delta = changed(a,b)
            try check(delta > 800, "\(motif.title) moves in the real listening view")
            motions.append(["motif": motif.rawValue, "changed_bytes_over_3": delta])
        }
        defaults.set("laminar", forKey: "onde.espace.artworkChoice")
        try await wait(0.7)
        defaults.set(false, forKey: "onde.espace.visualMotion")
        try await wait(0.4); try await running(false, "Pause visual stops every artwork clock")
        let frozen = EspaceMotionAudit.live.map(\.time)
        let pa = try frame(host)
        try await wait(0.5)
        let pb = try frame(host)
        try check(frozen == EspaceMotionAudit.live.map(\.time), "Pause freezes natural clock time")
        try check(changed(pa,pb) == 0, "Pause freezes rendered pixels exactly")
        defaults.set(true, forKey: "onde.espace.visualMotion")
        try await wait(0.5); try await running(true, "Resume visual restarts the live surface")
        let resumed = EspaceMotionAudit.running.first!.time
        try check(resumed - (frozen.max() ?? 0) < 0.7, "Resume does not catch up paused wall time")
        defaults.set(false, forKey: "onde.espace.showArtwork")
        try await wait(0.4); try await running(false, "Hiding artwork removes its active clock")
        _ = try frame(host, file: output.appendingPathComponent("artwork-hidden.png"))
        defaults.set(true, forKey: "onde.espace.showArtwork")
        try await wait(0.5); try await running(true, "Showing artwork restarts motion after reattachment")
        model.store.preferences.reducedMotion = true
        try await wait(0.4); try await running(false, "Onde Reduce Motion stops the integrated animation")
        let ra = try frame(host)
        try await wait(0.3)
        let rb = try frame(host)
        try check(changed(ra,rb) == 0, "Reduced motion keeps the actual rendered view still")
        model.store.preferences.reducedMotion = false
        try await wait(0.4); try await running(true, "Explicitly leaving reduced motion resumes the surface")
        model.sheet = .settings
        try await wait(0.8); try await running(false, "A settings sheet pauses the animation behind it")
        model.sheet = nil
        try await wait(0.8); try await running(true, "Dismissing settings resumes the underlying animation")
        model.quietView = true
        try await wait(0.4); try await running(false, "Quiet view has no running decorative clock")
        model.quietView = false
        try await wait(0.5); try await running(true, "Returning from Quiet view reattaches live motion")
        window.orderOut(nil)
        try await wait(0.5); try await running(false, "Ordering the actual window out stops motion")
        let hiddenTime = EspaceMotionAudit.live.map(\.time)
        try await wait(0.4)
        try check(hiddenTime == EspaceMotionAudit.live.map(\.time), "An invisible window consumes no animation time")
        window.makeKeyAndOrderFront(nil)
        try await wait(0.5); try await running(true, "Reopening the actual window resumes motion")
        window.miniaturize(nil)
        try await wait(0.8); try check(window.isMiniaturized, "The test window really minimized")
        try await running(false, "Minimizing stops the animation clock")
        window.deminiaturize(nil); window.makeKeyAndOrderFront(nil)
        try await wait(0.8); try await running(true, "Restoring from the Dock resumes motion")
        let cover = NSWindow(contentRect: window.frame.insetBy(dx: -30, dy: -30), styleMask: [.borderless], backing: .buffered, defer: false)
        cover.isReleasedWhenClosed = false; cover.isOpaque = true; cover.backgroundColor = .black
        cover.level = .floating; cover.orderFront(nil)
        try await wait(0.6); try await running(false, "Full occlusion stops this window even with a visible status item")
        cover.orderOut(nil); cover.close()
        try await wait(0.5); try await running(true, "Uncovering the actual window resumes motion")
        // A short recording of actual elapsed RunLoop frames. Never set driver.time.
        let movie = output.appendingPathComponent("live-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: movie, withIntermediateDirectories: true)
        var timestamps: [Double] = []
        let start = ProcessInfo.processInfo.systemUptime
        for i in 0..<48 {
            _ = try frame(host, file: movie.appendingPathComponent(String(format: "%03d.png", i)))
            timestamps.append(ProcessInfo.processInfo.systemUptime - start)
            try await wait(1.0 / 12)
        }
        try check(!model.playing && model.elapsed == 0 && model.todaySeconds == 0,
                  "Animation selection and lifecycle never start music or advance session/daily time")
        window.orderOut(nil); window.contentView = nil; window.close()
        try await wait(0.3); try await running(false, "Closing the hosting window leaves no running artwork clock")
        let receipt: [String: Any] = ["passed": checks.count, "checks": checks, "motifs": motions,
            "recorded_frame_seconds": timestamps, "muted": true,
            "runner_system_reduce_motion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            "controlled_accessibility_environment": false,
            "scope": "Real EspaceRootView in NSWindow, natural Timer/RunLoop, pixel comparisons and actual window lifecycle. Programmatic preferences/actions and actual system motion preference; not a full pointer or GPU performance test.",
            "os": ProcessInfo.processInfo.operatingSystemVersionString]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("motion-integration.json"))
        print("Live artwork checks:", checks.count)
    }
}
#endif
