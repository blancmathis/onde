import AppKit
import Foundation

/// Uses the production icon registration with the actual distribution bundle.
/// No service reset, synthetic permissions, model or audio. Parent CI timeout
/// remains a failure if an Apple framework stops responding.
@main struct AppIconCheck {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            throw NSError(domain: "AppIconCheck", code: 1)
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        var checks: [String] = []
        func check(_ condition: Bool, _ text: String) throws {
            guard condition else {
                throw NSError(domain: "AppIconCheck", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: text])
            }
            checks.append(text); print("PASS \(text)"); fflush(stdout)
        }
        try check(OndeApplicationIcon.register(in: bundle), "Register the real bundled application icon")
        guard let icon = NSImage(named: NSImage.applicationIconName) else {
            throw NSError(domain: "AppIconCheck", code: 3)
        }
        try check(icon.isValid && icon.size.width >= 128 && icon.size.height >= 128,
                  "The cached icon is a valid full-resolution image, not a placeholder")
        try check(OndeApplicationIcon.register(in: bundle), "Repeated registration is idempotent")
        try check(NSImage(named: NSImage.applicationIconName) === icon, "Repeated registration preserves the original image")
        print("BEFORE_NATIVE_ALERT"); fflush(stdout)
        let alert = NSAlert()
        alert.messageText = "Onde error presentation"
        alert.informativeText = "An error remains visible and can be acknowledged without blocking the local controls. This is an isolated validation window."
        alert.addButton(withTitle: "Close")
        alert.layout()
        try check(alert.buttons.count == 1 && alert.buttons[0].isEnabled,
                  "Native alert creation and layout finish with an enabled acknowledgement")
        alert.window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        if let view = alert.window.contentView,
           let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: image)
            if let data = image.representation(using: .png, properties: [:]) {
                try data.write(to: output.appendingPathComponent("native-alert.png"))
            }
        }
        alert.window.orderOut(nil)
        let receipt: [String: Any] = ["ok": true, "passed": checks.count, "checks": checks,
                                     "scope": "Production bundled-icon registration and real NSAlert construction; not an exhaustive interaction test"]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("app-icon.json"))
    }
}
