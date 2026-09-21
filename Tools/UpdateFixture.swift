// CI-only synthetic application. Never packaged or run against personal state.
import AppKit
import Foundation

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--pid-file"), args.indices.contains(i + 1) {
            try? Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(to: URL(fileURLWithPath: args[i + 1]))
        }
        if let i = args.firstIndex(of: "--onde-update-transaction"), args.indices.contains(i + 1) {
            if Bundle.main.infoDictionary?["OndeFixtureBehavior"] as? String == "crash" { exit(7) }
            let directory = URL(fileURLWithPath: args[i + 1])
            if let data = try? Data(contentsOf: directory.appendingPathComponent("plan.json")),
               let plan = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = plan["token"] as? String {
                try? Data(token.utf8).write(to: directory.appendingPathComponent("ack.txt"), options: .atomic)
            }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateNow }
}
let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
