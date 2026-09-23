import AppKit
import SwiftUI

/// Native policy test, not a pointer/VoiceOver or end-to-end draft-edit test.
/// The delegate rejects every accepted request so this checker never exits early.
@main struct SheetTerminationCheck {
    @MainActor final class Policy: ObservableObject {
        @Published var dirty = false
    }
    @MainActor final class Delegate: NSObject, NSApplicationDelegate {
        var requests = 0
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            requests += 1
            return .terminateCancel
        }
    }
    struct Content: View {
        @ObservedObject var policy: Policy
        let legacy: Bool
        var body: some View {
            if legacy {
                content.background {
                    LegacySheetTerminationPolicy(preventsTermination: policy.dirty)
                        .frame(width: 0, height: 0).allowsHitTesting(false)
                }
            } else {
                content.ondeSheetTerminationPolicy(preventsTermination: policy.dirty)
            }
        }
        private var content: some View {
            Text(policy.dirty ? "Unapplied edit" : "Saved settings")
                .frame(width: 400, height: 160)
                .interactiveDismissDisabled(policy.dirty)
        }
    }
    @MainActor static func main() throws {
        let app = NSApplication.shared
        let delegate = Delegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        var checks: [String] = []
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else {
                throw NSError(domain: "SheetTerminationCheck", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: message])
            }
            checks.append(message); print("PASS \(message)")
        }
        func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.7)) }
        let unaffected = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        unaffected.preventsApplicationTerminationWhenModal = true
        for legacy in [false, true] {
            let label = legacy ? "legacy AppKit policy" : "current OS policy"
            let policy = Policy()
            let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            sheet.contentView = NSHostingView(rootView: Content(policy: policy, legacy: legacy))
            parent.makeKeyAndOrderFront(nil)
            parent.beginSheet(sheet)
            pump()
            try check(!sheet.preventsApplicationTerminationWhenModal, "\(label): clean sheet allows termination")
            let before = delegate.requests
            app.terminate(nil)
            pump()
            try check(delegate.requests == before + 1, "\(label): clean Quit reaches delegate")
            policy.dirty = true
            pump()
            try check(sheet.preventsApplicationTerminationWhenModal, "\(label): dirty sheet protects unapplied edit")
            let blocked = delegate.requests
            app.terminate(nil)
            pump()
            try check(delegate.requests == blocked, "\(label): protected Quit never reaches cleanup delegate")
            policy.dirty = false
            pump()
            try check(!sheet.preventsApplicationTerminationWhenModal, "\(label): Apply or Discard restores termination")
            app.terminate(nil)
            pump()
            try check(delegate.requests == blocked + 1, "\(label): Quit works again without reopening the sheet")
            try check(unaffected.preventsApplicationTerminationWhenModal, "\(label): other windows remain untouched")
            parent.endSheet(sheet)
            pump()
            sheet.orderOut(nil); parent.orderOut(nil)
            sheet.contentView = nil
        }
        let result: [String: Any] = ["ok": true, "passed": checks.count, "checks": checks,
                                    "scope": "real NSWindow sheet termination policy; no audio or profile"]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
