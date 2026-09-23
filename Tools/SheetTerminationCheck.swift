import AppKit
import SwiftUI

/// Exercise a real SwiftUI presentation. Test the dirty edit before an allowed
/// Quit: AppKit may end an unprotected sheet even when the delegate cancels exit.
@main struct SheetTerminationCheck {
    @MainActor final class Policy: ObservableObject {
        @Published var dirty = false
        @Published var presented = false
    }
    @MainActor final class Delegate: NSObject, NSApplicationDelegate {
        var requests = 0
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            requests += 1
            return .terminateCancel
        }
    }
    struct Root: View {
        @ObservedObject var policy: Policy
        let legacy: Bool
        var body: some View {
            Text("Presentation host").frame(width: 500, height: 300)
                .sheet(isPresented: $policy.presented) {
                    Content(policy: policy, legacy: legacy)
                }
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
            checks.append(message); print("PASS \(message)"); fflush(stdout)
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
            parent.contentView = NSHostingView(rootView: Root(policy: policy, legacy: legacy))
            parent.makeKeyAndOrderFront(nil)
            pump()
            policy.presented = true
            pump()
            guard let sheet = parent.attachedSheet else {
                throw NSError(domain: "SheetTerminationCheck", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "\(label): SwiftUI did not present its sheet"])
            }
            try check(!sheet.preventsApplicationTerminationWhenModal, "\(label): clean sheet allows termination")
            policy.dirty = true
            pump()
            let sameSheet = parent.attachedSheet === sheet
            let protects = sheet.preventsApplicationTerminationWhenModal
            let blocked = delegate.requests
            app.terminate(nil)
            pump()
            print("DIAGNOSTIC \(label): sameSheet=\(sameSheet) protects=\(protects) presented=\(policy.presented) attached=\(parent.attachedSheet != nil) delegateDelta=\(delegate.requests - blocked)")
            fflush(stdout)
            try check(sameSheet && protects, "\(label): dirty edit updates the attached sheet policy")
            try check(delegate.requests == blocked, "\(label): protected Quit never reaches cleanup delegate")
            try check(policy.presented && parent.attachedSheet === sheet, "\(label): rejected Quit preserves the edit presentation")
            policy.dirty = false
            pump()
            try check(!sheet.preventsApplicationTerminationWhenModal, "\(label): Apply or Discard restores termination")
            app.terminate(nil)
            pump()
            try check(delegate.requests == blocked + 1, "\(label): clean Quit reaches delegate after Apply or Discard")
            try check(unaffected.preventsApplicationTerminationWhenModal, "\(label): other windows remain untouched")
            policy.presented = false
            pump()
            try check(parent.attachedSheet == nil, "\(label): completed presentation can close")
            parent.orderOut(nil)
            parent.contentView = nil
        }
        let result: [String: Any] = ["ok": true, "passed": checks.count, "checks": checks,
                                    "scope": "real SwiftUI sheet termination policy; no audio or profile"]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
