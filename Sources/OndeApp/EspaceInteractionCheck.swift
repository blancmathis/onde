#if ONDE_DESIGN_CAPTURE
import AppKit
import ApplicationServices
import SwiftUI
import OndeCore

/// Public AX actions on the actual owned app, not model-command substitutes.
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
        Task { @MainActor in await NativeInteraction(model: model, output: output).run() }
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
    func nodes() async -> [NativeAXNode] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: NativeAXNode.snapshot())
            }
        }
    }
    func find(id: String? = nil, title: String? = nil, in root: Any? = nil) async throws -> NativeAXNode {
        let inSheet = (root as? NSWindow)?.sheetParent != nil
        let candidates = await nodes()
        guard let node = candidates.first(where: {
            guard !inSheet || $0.inSheet else { return false }
            if let id { return $0.id == id }
            return $0.label == title && $0.role != "AXStaticText" && $0.role != "AXGroup"
        }) else {
            throw NSError(domain: "OndeNativeInteraction", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Missing native control: \(id ?? title ?? "unknown")"])
        }
        return node
    }
    func perform(_ node: NativeAXNode, value: String? = nil) async -> Int32 {
        let pid = ProcessInfo.processInfo.processIdentifier
        let executable = Bundle.main.executableURL!.path
        let helper = ProcessInfo.processInfo.environment["ONDE_AX_ACTION_HELPER"]
        var request: [String: Any] = ["id": node.id, "label": node.label, "role": node.role, "in_sheet": node.inSheet, "element_path": node.path]
        if let value { request["value"] = value }
        guard let helper, let data = try? JSONSerialization.data(withJSONObject: request),
              let argument = String(data: data, encoding: .utf8) else { return -10 }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process(), pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: helper)
                process.arguments = [String(pid), executable, argument]
                process.standardOutput = pipe
                do {
                    try process.run()
                    let reply = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0,
                          let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any],
                          let code = object["code"] as? Int32 else {
                        print("AX_HELPER_FAILED \(String(data: reply, encoding: .utf8) ?? "")")
                        continuation.resume(returning: -11); return
                    }
                    print("AX_HELPER \(String(data: reply, encoding: .utf8) ?? "")"); fflush(stdout)
                    continuation.resume(returning: code)
                } catch {
                    print("AX_HELPER_ERROR \(error)"); fflush(stdout)
                    continuation.resume(returning: -12)
                }
            }
        }
    }
    func press(id: String? = nil, title: String? = nil, in root: Any? = nil) async throws {
        let node = try await find(id: id, title: title, in: root)
        try require(node.enabled, "Control enabled: \(id ?? title ?? "unknown")")
        let result = await perform(node)
        try require(result == AXError.success.rawValue, "Native press accepted: \(id ?? title ?? "unknown") [\(result)]")
        try await pause()
    }
    func dismiss(title: String, preserving expectedState: () -> Bool) async throws {
        let node = try await find(title: title)
        try require(node.enabled, "Dismissal control enabled: \(title)")
        let result = await perform(node)
        try await pause()
        let after = await nodes()
        let targetGone = !after.contains { $0.label == node.label && $0.role == node.role }
        // AppKit may remove a confirmation's AX element during its own action.
        // Do not mistake that invalidated reply for failed cancellation, or
        // accept it unless both the actual control and expected state agree.
        let reported = [AXError.success.rawValue, AXError.invalidUIElement.rawValue,
                        AXError.attributeUnsupported.rawValue].contains(result)
        try require(reported && targetGone && expectedState(),
                    "Native dismissal verified: \(title), target removed and state preserved [AX \(result)]")
    }
    func edit(id: String? = nil, title: String? = nil, text: String, in root: Any? = nil) async throws {
        let node = try await find(id: id, title: title, in: root)
        let result = await perform(node, value: text)
        try require(result == AXError.success.rawValue, "Native field edit accepted: \(id ?? title ?? "unknown") [\(result)]")
        try await pause()
        let current = try await find(id: id, title: title, in: root)
        try require(current.value == text, "Native field contains text: \(id ?? title ?? "unknown")")
    }
    func waitFor(_ name: String, seconds: Double = 15, _ predicate: () -> Bool) async throws {
        let end = ProcessInfo.processInfo.systemUptime + seconds
        while !predicate(), ProcessInfo.processInfo.systemUptime < end { try await pause(0.1) }
        try require(predicate(), name)
    }
    func dump(_ name: String) async throws {
        let snapshot = await nodes()
        let items: [[String: Any]] = snapshot.map {
            ["id": $0.id, "label": $0.label, "role": $0.role,
             "enabled": $0.enabled, "value": $0.value, "in_sheet": $0.inSheet]
        }
        try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(name + ".json"))
    }
    func run() async {
        var failure: String?
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            checks += try await UpdateMetadataCapture.run()
            try require(AXIsProcessTrusted(), "Native UI fixture has existing accessibility access; no permission override")
            try await pause(1)
            guard let window = NSApp.windows.first(where: { $0.title == "Onde" }) else {
                throw NSError(domain: "OndeNativeInteraction", code: 3)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            try await pause()
            try await dump("initial-elements")
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
            let searched = await nodes()
            try require(searched.contains { $0.label == "No matching sounds" || $0.value == "No matching sounds" },
                        "Search displays its native empty state")
            try await press(title: "Clear search", in: window)
            let search = try await find(id: "music-search", in: window)
            try require(search.value == "", "Clear search restores an empty native field")
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
            try await dismiss(title: "Cancel", preserving: { model.store.mixes.count == 1 })
            try require(model.store.mixes.count == 1, "Cancelling the native deletion preserves the mix")
            try await press(id: "delete-mix-" + id)
            try await dismiss(title: "Delete saved mix", preserving: { model.store.mixes.isEmpty })
            try require(model.store.mixes.isEmpty && !model.playing, "Confirming native deletion removes only the saved mix")
            try await dismiss(title: "Done", preserving: { model.sheet == nil })
            try await waitFor("Done dismisses the real sheet") { window.attachedSheet == nil && model.sheet == nil }
            try require(model.store.preferences.masterVolume == 0 && model.errorMessage == nil, "UI audit stays muted without unhandled errors")
            try await dump("final-elements")
        } catch {
            failure = error.localizedDescription
            try? await dump("failure-elements")
            fputs("Native interaction failed: \(error)\n", stderr)
        }
        let result: [String: Any] = ["ok": failure == nil, "passed": checks.count, "checks": checks,
                                     "error": failure as Any? ?? NSNull(), "muted": model.store.preferences.masterVolume == 0,
                                     "scope": "Public AX actions on this owned native process and real SwiftUI presentations; not a full VoiceOver or physical-pointer audit"]
        try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("interaction.json"))
        model.sheet = nil; model.errorMessage = nil; model.stop()
        try? await pause()
        NSApp.terminate(nil)
    }
}

/// Use the public AX server, not private SwiftUI implementation objects.
/// Calls run off the app's main thread so its actual AX server can reply.
private final class NativeAXNode: @unchecked Sendable {
    let element: AXUIElement
    let path: [Int]
    let id: String
    let label: String
    let role: String
    let value: String
    let enabled: Bool
    let inSheet: Bool
    init(element: AXUIElement, inSheet: Bool, path: [Int]) {
        self.element = element
        self.path = path
        self.id = Self.attribute(element, "AXIdentifier") as? String ?? ""
        self.role = Self.attribute(element, kAXRoleAttribute) as? String ?? ""
        self.label = [Self.attribute(element, kAXDescriptionAttribute) as? String,
                      Self.attribute(element, kAXTitleAttribute) as? String,
                      Self.attribute(element, "AXPlaceholderValue") as? String]
            .compactMap { $0 }.first(where: { !$0.isEmpty }) ?? ""
        self.value = Self.attribute(element, kAXValueAttribute).map { String(describing: $0) } ?? ""
        self.enabled = Self.attribute(element, kAXEnabledAttribute) as? Bool ?? false
        self.inSheet = inSheet || self.role == "AXSheet"
    }
    static func attribute(_ element: AXUIElement, _ key: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
    static func snapshot() -> [NativeAXNode] {
        let app = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 2)
        var result: [NativeAXNode] = []
        func visit(_ element: AXUIElement, depth: Int, inSheet: Bool, path: [Int]) {
            guard depth < 35, result.count < 2500,
                  !result.contains(where: { CFEqual($0.element, element) }) else { return }
            let node = NativeAXNode(element: element, inSheet: inSheet, path: path)
            result.append(node)
            for (index, child) in (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).enumerated() {
                visit(child, depth: depth + 1, inSheet: node.inSheet, path: path + [1, index])
            }
            for (index, child) in (attribute(element, "AXSheets") as? [AXUIElement] ?? []).enumerated() {
                visit(child, depth: depth + 1, inSheet: true, path: path + [2, index])
            }
        }
        for (index, window) in (attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).enumerated() {
            visit(window, depth: 0, inSheet: false, path: [0, index])
        }
        return result
    }
}
#endif
