import SwiftUI
import AppKit
import OndeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    func applicationWillFinishLaunching(_ notification: Notification) { OndeApplicationIcon.register() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first { $0.title == "Onde" }?.makeKeyAndOrderFront(nil); return true
    }
    // Each sheet declares its own termination policy before AppKit consults
    // this delegate. Cleanup runs only after Quit has actually been accepted.
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
@main struct OndeApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Onde", id: "main") {
            EspaceRootView().environmentObject(model).environment(\.locale, Locale(identifier: "en")).onAppear { delegate.model = model; UpdateInstallationController.shared.applicationDidOpen(); EspaceCapture.runIfRequested(model: model) }
        }
        .defaultSize(width: 1120, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { model.page = "updates"; model.showWindow(); model.updates.check() }
            }
            CommandMenu("Session") {
                Button(model.playing ? "Pause" : "Play") { model.togglePlayback() }.keyboardShortcut("p", modifiers: .command)
                Button("End session") { model.stop() }.keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Focus") { model.startDefaultMode(.focus) }.keyboardShortcut("1", modifiers: .command)
                Button("Relax") { model.startDefaultMode(.relax) }.keyboardShortcut("2", modifiers: .command)
                Button("Meditation") { model.startDefaultMode(.meditation) }.keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("Quiet view") { model.quietView.toggle() }.keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Import Audio…") { model.sheet = .personal; model.importFromPanel() }.keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.page = "settings"; model.showWindow() }.keyboardShortcut(",", modifiers: .command)
            }
        }
        MenuBarExtra {
            EspaceMenuBarView().environmentObject(model).environment(\.locale, Locale(identifier: "en"))
        } label: {
            Image(nsImage: OndeStatusIcon.image)
                .renderingMode(.template)
                .accessibilityLabel("Onde")
                .help("Open Onde")
        }.menuBarExtraStyle(.window)
    }
}
struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Text("onde").font(.system(size: 28, design: .serif)); Spacer(); Text(model.mode.title).font(.system(size: 11)).foregroundStyle(Theme.accent(model.mode)) }
            Text(model.currentMusicTitle).font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text(clockText(model.elapsed)).font(.system(size: 39, weight: .light, design: .rounded)).monospacedDigit()
            HStack(spacing: 8) { ForEach(SessionMode.allCases) { mode in Button { model.startDefaultMode(mode) } label: { Text(mode.title).font(.system(size: 10)).padding(9).background(model.mode == mode ? Theme.raised : .clear, in: Capsule()) }.buttonStyle(.plain) } }
            HStack { PillButton(title: model.playing ? "Pause" : "Play", symbol: model.playing ? "pause.fill" : "play.fill", primary: true) { model.togglePlayback() }; Spacer(); Button("End session") { model.stop() }.font(.system(size: 11)).buttonStyle(.plain) }
            Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1).tint(Theme.accent).accessibilityLabel("Master volume")
            Divider()
            HStack { Button("Open Onde") { openWindow(id: "main"); model.showWindow() }; Spacer(); Button("Quit") { NSApp.terminate(nil) } }.font(.system(size: 11)).buttonStyle(.plain)
        }.padding(22).frame(width: 295).background(Theme.sidebar).foregroundStyle(Theme.ink).preferredColorScheme(.dark)
    }
}
