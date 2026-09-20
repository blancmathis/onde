import SwiftUI
import AppKit
import OndeCore

/// CI only; refuses to operate without a muted temporary profile. No playback.
@MainActor enum EspaceCapture {
    private static var started = false
    private static let defaults = UserDefaults(suiteName: "onde.design-capture." + UUID().uuidString)!
    static func runIfRequested(model: AppModel) {
        #if ONDE_DESIGN_CAPTURE
        let env = ProcessInfo.processInfo.environment
        guard !started, let homePath = env["ONDE_HOME"], let outputPath = env["ONDE_DESIGN_SNAPSHOT_DIR"] else { return }
        let home = URL(fileURLWithPath: homePath).standardizedFileURL.resolvingSymlinksInPath()
        let output = URL(fileURLWithPath: outputPath).standardizedFileURL.resolvingSymlinksInPath()
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.resolvingSymlinksInPath()
        guard home.path.hasPrefix(temporary.path + "/"), output.path.hasPrefix(home.path + "/"),
              model.store.preferences.masterVolume == 0, !model.playing else {
            fputs("Unsafe design capture environment.\n", stderr); exit(3)
        }
        started = true
        Task { @MainActor in
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                // Exercise the actual Timer/RunLoop driver, separately from geometry snapshots.
                let clock = EspaceMotionDriver()
                clock.configure(fps: 24)
                try await Task.sleep(nanoseconds: 400_000_000)
                guard clock.time > 0 else { throw NSError(domain:"EspaceClockDidNotRun", code:1) }
                clock.stop()
                let frozen = clock.time
                try await Task.sleep(nanoseconds: 160_000_000)
                guard clock.time == frozen else { throw NSError(domain:"EspaceClockDidNotPause", code:2) }
                clock.configure(fps: 12)
                try await Task.sleep(nanoseconds: 400_000_000)
                guard clock.time > frozen else { throw NSError(domain:"EspaceClockDidNotResume", code:3) }
                clock.stop()
                model.startDefaultMode(.focus, autostart: false)
                try await take(RootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("before-native.png"))
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("focus-native.png"))
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:860,height:640), file:output.appendingPathComponent("compact-native.png"))
                try await take(EspaceRootView(browse:.relax).environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("browsing-native.png"))
                try await take(EspaceRootView(browse:.focus,query:"piano").environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("search-native.png"))
                try await take(EspaceRootView(browse:.focus,query:"no-such-sound").environmentObject(model), size:NSSize(width:860,height:640), file:output.appendingPathComponent("empty-native.png"))
                defaults.set(false, forKey:"onde.espace.showArtwork")
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("no-artwork-native.png"))
                defaults.set(true, forKey:"onde.espace.showArtwork")
                try await take(EspaceSurface(id:"sillage",mode:.focus,time:0), size:NSSize(width:720,height:300), file:output.appendingPathComponent("surface-0.png"))
                try await take(EspaceSurface(id:"sillage",mode:.focus,time:8), size:NSSize(width:720,height:300), file:output.appendingPathComponent("surface-8.png"))
                model.startDefaultMode(.relax, autostart:false)
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("relax-native.png"))
                model.startDefaultMode(.meditation, autostart:false)
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("meditation-native.png"))
                model.quietView = true
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:1120,height:800), file:output.appendingPathComponent("quiet-native.png"))
                model.quietView = false
                try await take(EspaceSheetView(sheet:.sound).environmentObject(model), size:NSSize(width:740,height:590), file:output.appendingPathComponent("sound-native.png"))
                try await take(EspaceSheetView(sheet:.settings).environmentObject(model), size:NSSize(width:740,height:590), file:output.appendingPathComponent("settings-native.png"))
                for tab in [EspaceSettingsTab.defaults, .meditation, .advanced] {
                    try await take(EspaceSheetView(sheet:.settings, initialSettingsTab:tab).environmentObject(model), size:NSSize(width:740,height:590), file:output.appendingPathComponent("settings-\(tab.rawValue.lowercased())-native.png"))
                }
                try await take(EspaceRootView().environmentObject(model), size:NSSize(width:860,height:640), file:output.appendingPathComponent("contrast-compact-native.png"), highContrast:true)
                try await take(EspaceMenuBarView().environmentObject(model), size:NSSize(width:340,height:480), file:output.appendingPathComponent("menubar-native.png"))
                let receipt:[String:Any] = ["scope":"NSHostingView bitmap captures of compiled SwiftUI views; not full interaction or GPU tests", "count":17, "surface_frames":2, "timer_driver_checks":3, "muted":model.store.preferences.masterVolume == 0, "playing":model.playing, "os":ProcessInfo.processInfo.operatingSystemVersionString]
                try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("capture.json"))
                NSApp.terminate(nil)
            } catch { fputs("Design capture failed: \(error)\n",stderr); exit(4) }
        }
        #endif
    }
    #if ONDE_DESIGN_CAPTURE
    private static func take<Content:View>(_ content:Content, size:NSSize, file:URL, highContrast:Bool = false) async throws {
        let hosted = NSHostingView(rootView:content.defaultAppStorage(defaults).environment(\.locale,Locale(identifier:"en")).environment(\.espaceReduceMotion,true).frame(width:size.width,height:size.height))
        hosted.frame = NSRect(origin:.zero,size:size)
        let window = NSWindow(contentRect:hosted.frame,styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView = hosted; window.appearance = NSAppearance(named:highContrast ? .accessibilityHighContrastDarkAqua : .darkAqua)
        window.orderFront(nil)
        try await Task.sleep(nanoseconds:700_000_000)
        hosted.layoutSubtreeIfNeeded(); hosted.displayIfNeeded()
        guard let bitmap = hosted.bitmapImageRepForCachingDisplay(in:hosted.bounds) else { throw NSError(domain:"EspaceCapture",code:1) }
        hosted.cacheDisplay(in:hosted.bounds,to:bitmap)
        guard let png = bitmap.representation(using:.png,properties:[:]) else { throw NSError(domain:"EspaceCapture",code:2) }
        try png.write(to:file,options:.withoutOverwriting)
        window.orderOut(nil); window.contentView = nil
    }
    #endif
}
