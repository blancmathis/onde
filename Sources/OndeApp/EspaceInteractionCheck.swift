#if ONDE_DESIGN_CAPTURE
import AppKit
import ApplicationServices
import SwiftUI
import OndeCore

/// In-process native accessibility actions on the real SwiftUI window. This is
/// not a VoiceOver session, inter-app automation or a physical pointer audit.
@MainActor enum EspaceInteractionCheck {
    private static var started = false
    static func runIfRequested(model: AppModel) -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["ONDE_INTERACTION_OUTPUT"] else { return false }
        guard !started else { return true }
        started = true
        guard let homePath = env["ONDE_HOME"] else { return true }
        let home = URL(fileURLWithPath: homePath).resolvingSymlinksInPath().standardizedFileURL
        let output = URL(fileURLWithPath: folder).resolvingSymlinksInPath().standardizedFileURL
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath().standardizedFileURL
        guard home.path.hasPrefix(temporary.path + "/"), output.path.hasPrefix(home.path + "/"),
              model.store.preferences.masterVolume == 0, !model.playing else {
            fputs("Refusing unsafe UI interaction fixture.\n", stderr)
            return true
        }
        Task { @MainActor in
            let check = NativeInteraction(model: model, output: output)
            await check.run()
        }
        return true
    }
}

@MainActor private final class NativeInteraction {
    let model: AppModel
    let output: URL
    var checks: [String] = []
    init(model: AppModel, output: URL) { self.model = model; self.output = output }
    func pause(_ seconds: Double = 0.35) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    func require(_ condition: Bool, _ name: String) throws {
        guard condition else { throw NSError(domain: "OndeNativeInteraction", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: name]) }
        checks.append(name); print("PASS \(name)"); fflush(stdout)
    }
    func elements(in root: Any) -> [NSAccessibilityProtocol] {
        var found: [NSAccessibilityProtocol] = [], seen = Set<ObjectIdentifier>()
        func visit(_ item: Any, depth: Int) {
            guard depth < 35, found.count < 2500, let node = item as? NSAccessibilityProtocol else { return }
            guard seen.insert(ObjectIdentifier(node as AnyObject)).inserted else { return }
            found.append(node)
            for child in node.accessibilityChildren() ?? [] { visit(child, depth: depth + 1) }
        }
        visit(root, depth: 0)
        return found
    }
    func allElements() -> [NSAccessibilityProtocol] { NSApp.windows.flatMap { elements(in: $0) } }
    func label(_ node: NSAccessibilityProtocol) -> String {
        node.accessibilityLabel() ?? node.accessibilityTitle() ?? ""
    }
    func find(id: String? = nil, title: String? = nil, in root: Any? = nil) throws -> NSAccessibilityProtocol {
        let nodes = root.map { elements(in: $0) } ?? allElements()
        guard let node = nodes.first(where: {
            if let id { return $0.accessibilityIdentifier() == id }
            return label($0) == title && $0.accessibilityRole() != .staticText
        }) else {
            throw NSError(domain: "OndeNativeInteraction", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Missing native control: \(id ?? title ?? "unknown")"])
        }
        return node
    }
    func press(id: String? = nil, title: String? = nil, in root: Any? = nil) async throws {
        let node = try find(id: id, title: title, in: root)
        try require(node.isAccessibilityEnabled(), "Control enabled: \(id ?? title ?? "unknown")")
        try require(node.accessibilityPerformPress(), "Native press accepted: \(id ?? title ?? "unknown")")
        try await pause()
    }
    func edit(id: String? = nil, title: String? = nil, text: String, in root: Any? = nil) async throws {
        let node = try find(id: id, title: title, in: root)
        node.setAccessibilityValue(text)
        try await pause()
        try require((node.accessibilityValue() as? String) == text, "Native field accepted text: \(id ?? title ?? "unknown")")
    }
    func waitFor(_ name: String, seconds: Double = 15, _ predicate: () -> Bool) async throws {
        let end = ProcessInfo.processInfo.systemUptime + seconds
        while !predicate(), ProcessInfo.processInfo.systemUptime < end { try await pause(0.1) }
        try require(predicate(), name)
    }
    func dump(_ name: String) throws {
        let items: [[String: Any]] = allElements().map {
            ["id": $0.accessibilityIdentifier() ?? "", "label": label($0),
             "role": $0.accessibilityRole()?.rawValue ?? "", "enabled": $0.isAccessibilityEnabled(),
             "value": String(describing: $0.accessibilityValue() ?? ""),
             "frame": NSStringFromRect($0.accessibilityFrame())]
        }
        try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(name + ".json"))
    }
    func run() async {
        var failure: String?
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            checks += try await UpdateMetadataCapture.run()
            let axStatus: Int32 = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    // Read this very process only; do not request or modify TCC permissions.
                    let app = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
                    AXUIElementSetMessagingTimeout(app, 2)
                    var value: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
                    continuation.resume(returning: result.rawValue)
                }
            }
            print("SELF_AX_READ", axStatus, "TRUSTED", AXIsProcessTrusted()); fflush(stdout)
            try await pause(1)
            guard let window = NSApp.windows.first(where: { $0.title == "Onde" }) else {
                throw NSError(domain: "OndeNativeInteraction", code: 3)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            try await pause()
            try dump("initial-elements")
            try require(!model.playing && model.elapsed == 0, "First launch is silent and does not count time")
            let initialMusic = model.selectedMusicID
            try await press(id: "default-ambre", in: window)
            try require(model.defaultMusicID(for: .focus) == "ambre" && model.selectedMusicID == initialMusic && !model.playing,
                        "Starring a native row changes only the default, without playback")
            try await press(id: "music-card-ambre", in: window)
            try await waitFor("Native card starts its requested audio") {
                model.selectedMusicID == "ambre" && model.clock.running && model.elapsed > 0.3
            }
            try await press(id: "transport-play", in: window)
            let frozen = model.clock.elapsed(at: model.now)
            try await pause(0.5)
            try require(!model.playing && abs(model.clock.elapsed(at: model.now) - frozen) < 0.02,
                        "Native Pause freezes the session")
            try await press(id: "transport-play", in: window)
            try await waitFor("Native Resume continues the existing session") { model.clock.elapsed(at: model.now) > frozen + 0.2 }
            try await press(id: "quiet-view", in: window)
            try require(model.quietView && model.playing, "Quiet view preserves native playback")
            try await press(id: "quiet-view", in: window)
            try require(!model.quietView && model.playing, "Leaving Quiet view preserves native playback")
            try await press(title: "End session · ⌘.", in: window)
            try require(!model.playing && model.elapsed == 0, "Native End session resets only the current session")
            try await edit(id: "music-search", text: "zz-no-such-sound", in: window)
            try require(allElements().contains { label($0) == "No matching sounds" || ($0.accessibilityValue() as? String) == "No matching sounds" },
                        "Search displays its native empty state")
            try await press(title: "Clear search", in: window)
            try require((try find(id: "music-search", in: window).accessibilityValue() as? String) == "",
                        "Clear search restores an empty native field")
            try await press(title: "Settings · ⌘,", in: window)
            try await waitFor("Settings is an attached native sheet") { window.attachedSheet != nil && model.sheet == .settings }
            let sheet = window.attachedSheet!
            try await press(title: "Meditation", in: sheet)
            let originalMarkers = model.store.preferences.markers
            try await edit(title: "Chime times in minutes, separated by commas", text: "5, 15", in: sheet)
            try require(model.store.preferences.markers == originalMarkers && sheet.preventsApplicationTerminationWhenModal,
                        "Typing chime times preserves saved data and protects the actual sheet")
            NSApp.terminate(nil)
            try await pause(0.5)
            try require(window.attachedSheet === sheet && model.sheet == .settings,
                        "Real Quit is refused while chime edits remain unapplied")
            try await edit(title: "Chime times in minutes, separated by commas", text: "invalid, 3", in: sheet)
            try await press(title: "Apply times", in: sheet)
            try require(model.store.preferences.markers == originalMarkers && sheet.preventsApplicationTerminationWhenModal,
                        "Invalid native chime input is not partially saved")
            try await edit(title: "Chime times in minutes, separated by commas", text: "5, 15", in: sheet)
            try await press(title: "Apply times", in: sheet)
            try require(model.store.preferences.markers == [300, 900] && !sheet.preventsApplicationTerminationWhenModal,
                        "Native Apply saves validated times and clears the quit barrier")
            try await press(title: "Advanced", in: sheet)
            try await press(title: "Personal audio & mixes", in: sheet)
            try await waitFor("Native settings link presents Personal audio without losing the destination") { model.sheet == .personal && window.attachedSheet != nil }
            try await edit(title: "Name this mix", text: "Native UI fixture")
            try await press(title: "Save current mix")
            try require(model.store.mixes.count == 1 && !model.playing, "Native Save creates one mix without autoplay")
            let id = model.store.mixes[0].id
            try await press(id: "delete-mix-" + id)
            try await press(title: "Cancel")
            try require(model.store.mixes.count == 1, "Cancelling the native deletion preserves the mix")
            try await press(id: "delete-mix-" + id)
            try await press(title: "Delete saved mix")
            try require(model.store.mixes.isEmpty && !model.playing, "Confirming native deletion removes only the saved mix")
            try await press(title: "Done")
            try await waitFor("Done dismisses the real sheet") { window.attachedSheet == nil && model.sheet == nil }
            try require(model.store.preferences.masterVolume == 0 && model.errorMessage == nil, "UI audit stays muted without unhandled errors")
            try dump("final-elements")
        } catch {
            failure = error.localizedDescription
            try? dump("failure-elements")
            fputs("Native interaction failed: \(error)\n", stderr)
        }
        let result: [String: Any] = ["ok": failure == nil, "passed": checks.count, "checks": checks,
                                     "error": failure as Any? ?? NSNull(), "muted": model.store.preferences.masterVolume == 0,
                                     "scope": "Native in-process accessibility actions and real SwiftUI presentations; not a full VoiceOver or physical-pointer audit"]
        try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("interaction.json"))
        // Only the disposable fixture. Failure remains recorded even if cleanup exits normally.
        model.sheet = nil; model.errorMessage = nil; model.stop()
        try? await pause()
        NSApp.terminate(nil)
    }
}
#endif
