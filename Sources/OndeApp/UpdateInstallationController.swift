import Foundation
import AppKit
import OndeCore

/// One in-memory coordinator. Installation requires a separate, explicit UI confirmation.
final class UpdateInstallationController: ObservableObject {
    static let shared = UpdateInstallationController()
    @Published private(set) var busy = false
    @Published private(set) var status: String?
    @Published private(set) var error: String?
    private var helper: Process?
    private var timer: Timer?
    private let pendingKey = "OndePendingUpdateTransaction"
    private var acknowledged = false

    func install(archive: URL, update: VerifiedUpdate) {
        guard !busy else { return }
        let alert = NSAlert()
        alert.messageText = "Install and relaunch Onde?"
        alert.informativeText = "\(update.title)\n\nPlayback will stop while Onde restarts. Your settings, saved soundscapes, history and imports will be kept."
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        error = nil
        status = "Preparing and verifying the application…"
        let target = Bundle.main.bundleURL.standardizedFileURL
        let parentPID = ProcessInfo.processInfo.processIdentifier
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let directory = try UpdateInstallation.prepare(archive: archive, update: update, target: target, parentPID: parentPID)
                DispatchQueue.main.async { self.startHelper(in: directory) }
            } catch {
                DispatchQueue.main.async { self.fail(error.localizedDescription) }
            }
        }
    }

    private func startHelper(in directory: URL) {
        do {
            let process = Process()
            process.executableURL = directory.appendingPathComponent(UpdateInstallation.helperName)
            process.arguments = ["--transaction", directory.path]
            let log = directory.appendingPathComponent("helper.log")
            FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
            let handle = try FileHandle(forWritingTo: log)
            process.standardOutput = handle
            process.standardError = handle
            try process.run()
            try? handle.close()
            helper = process
            UserDefaults.standard.set(directory.path, forKey: pendingKey)
            status = "Waiting for the installer…"
            let deadline = Date().addingTimeInterval(20)
            timer?.invalidate()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                let state = UpdateInstallation.state(in: directory)
                if state == "ready" {
                    timer.invalidate()
                    self.status = "Installing and relaunching…"
                    do {
                        let plan = try UpdateInstallation.loadPlan(directory)
                        try Data(plan.token.utf8).write(to: directory.appendingPathComponent("authorize.txt"), options: .atomic)
                        // Uses the ordinary termination path, which saves the session and stops audio.
                        NSApp.terminate(nil)
                        // If termination was cancelled, keep watching for the helper's bounded timeout.
                        self.watchCompletion(in: directory)
                    } catch { self.fail(error.localizedDescription) }
                } else if let state, state.hasPrefix("error:") {
                    timer.invalidate(); self.fail(String(state.dropFirst(6)))
                } else if !process.isRunning || Date() > deadline {
                    timer.invalidate()
                    // Without authorize.txt the helper is incapable of replacing the app.
                    self.fail("The installer could not start. Onde remains open and unchanged. Retry, or use Show in Finder for a manual installation.")
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } catch { fail(error.localizedDescription) }
    }

    /// Called only after the real root window has appeared and AppModel is attached.
    func applicationDidOpen() {
        guard !acknowledged else { return }
        acknowledged = true
        UpdateInstallation.acknowledgeLaunch(arguments: CommandLine.arguments)
        guard let path = UserDefaults.standard.string(forKey: pendingKey) else { return }
        let directory = URL(fileURLWithPath: path)
        guard let plan = try? UpdateInstallation.loadPlan(directory), plan.target == Bundle.main.bundleURL.standardizedFileURL.path else {
            UserDefaults.standard.removeObject(forKey: pendingKey)
            return
        }
        watchCompletion(in: directory)
    }

    private func watchCompletion(in directory: URL) {
        timer?.invalidate()
        let deadline = Date().addingTimeInterval(70)
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if UpdateInstallation.state(in: directory) == "success" {
                timer.invalidate()
                self.busy = false
                self.error = nil
                self.status = "Onde \(AppBuild.version) was installed successfully."
                // Cleanup only an authenticated, private transaction for this installed build.
                if let plan = try? UpdateInstallation.loadPlan(directory), plan.build == AppBuild.number,
                   plan.target == Bundle.main.bundleURL.standardizedFileURL.path {
                    try? FileManager.default.removeItem(at: directory)
                    UserDefaults.standard.removeObject(forKey: self.pendingKey)
                }
            } else if let state = UpdateInstallation.state(in: directory), state.hasPrefix("error:") {
                timer.invalidate()
                self.fail(String(state.dropFirst(6)))
                let alert = NSAlert()
                alert.messageText = "The update was not completed"
                alert.informativeText = self.error ?? "Open Updates to retry."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else if Date() > deadline {
                timer.invalidate()
                self.fail("The update did not report completion. Your downloaded archive and any previous-app backup are preserved. Open Updates to retry.")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func fail(_ message: String) {
        timer?.invalidate()
        timer = nil
        busy = false
        status = nil
        error = message
    }
}
