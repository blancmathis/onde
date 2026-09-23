import AppKit
import Foundation

// Independent framework diagnostic. No Onde model, audio, settings or IPC.
// Each mode runs in its own process; no daemon or security settings are changed.
@main struct HostedAlertSmoke {
    @MainActor static func main() {
        let mode = CommandLine.arguments.last ?? "plain"
        func mark(_ text: String) { print(text); fflush(stdout) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        mark("APP_READY " + mode)
        let image = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor.black.setFill(); rect.fill()
            NSColor.white.setStroke()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 12, dy: 12))
            path.lineWidth = 4; path.stroke()
            return true
        }
        if mode == "application-icon" {
            mark("BEFORE_APPLICATION_ICON")
            app.applicationIconImage = image
            mark("AFTER_APPLICATION_ICON")
        }
        if mode == "named-icon" {
            mark("BEFORE_NAMED_ICON")
            mark("NAMED_ICON_REGISTERED \(image.setName(NSImage.Name("NSApplicationIcon")))")
        }
        mark("BEFORE_ALERT_INIT")
        let alert = NSAlert()
        mark("AFTER_ALERT_INIT")
        alert.messageText = "Independent native alert check"
        alert.informativeText = "Disposable hosted test. No Onde code is involved."
        alert.addButton(withTitle: "Close")
        alert.layout()
        mark("ALERT_LAYOUT_OK")
        alert.window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        alert.window.orderOut(nil)
        mark("FRAMEWORK_ALERT_OK")
    }
}
