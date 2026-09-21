import Foundation
import AppKit
import OndeCore

// A short-lived, same-user child of Onde, not a service or login item.
// It performs no network access and accepts only a private prepared transaction.
guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--transaction" else {
    FileHandle.standardError.write(Data("This helper can only complete an update explicitly approved in Onde.\n".utf8))
    exit(2)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
DispatchQueue.global(qos: .userInitiated).async {
    do {
        try UpdateInstallation.runHelper(directory: directory)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        if let plan = try? UpdateInstallation.loadPlan(directory) {
            try? UpdateInstallation.writeState("error: \(error.localizedDescription)", in: directory)
            let target = URL(fileURLWithPath: plan.target)
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: "app.onde.mac")
                .contains { !$0.isTerminated && $0.bundleURL?.standardizedFileURL.path == target.path }
            if !running {
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                if let home = ProcessInfo.processInfo.environment["ONDE_HOME"] { config.environment = ["ONDE_HOME": home] }
                let wait = DispatchSemaphore(value: 0)
                NSWorkspace.shared.openApplication(at: target, configuration: config) { _, _ in wait.signal() }
                _ = wait.wait(timeout: .now() + 20)
            }
        }
        exit(1)
    }
}
RunLoop.main.run()
