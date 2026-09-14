import SwiftUI
import AppKit
import OndeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first { $0.title == "Onde" }?.makeKeyAndOrderFront(nil); return true
    }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
@main struct OndeApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Onde", id: "main") {
            RootView().environmentObject(model).onAppear { delegate.model = model }
        }
        .defaultSize(width: 1220, height: 840)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Rechercher une mise à jour…") { model.page = "updates"; model.showWindow(); model.updates.check() }
            }
            CommandMenu("Session") {
                Button(model.playing ? "Pause" : "Lecture") { model.togglePlayback() }.keyboardShortcut("p", modifiers: .command)
                Button("Terminer") { model.stop() }.keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Focus") { model.startMode(.focus) }.keyboardShortcut("1", modifiers: .command)
                Button("Relax") { model.startMode(.relax) }.keyboardShortcut("2", modifiers: .command)
                Button("Méditation") { model.startMode(.meditation) }.keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("Vue calme") { model.quietView.toggle() }.keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Importer un son…") { model.importFromPanel() }.keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Réglages…") { model.page = "settings"; model.showWindow() }.keyboardShortcut(",", modifiers: .command)
            }
        }
        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            Image(systemName: model.playing ? "waveform" : "waveform.path")
            if model.playing { Text(clockText(model.elapsed)) }
        }.menuBarExtraStyle(.window)
    }
}
struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Text("onde").font(.system(size: 28, design: .serif)); Spacer(); Text(model.mode.title).font(.system(size: 11)).foregroundStyle(Theme.accent(model.mode)) }
            Text(clockText(model.elapsed)).font(.system(size: 39, weight: .light, design: .rounded)).monospacedDigit()
            HStack(spacing: 8) { ForEach(SessionMode.allCases) { mode in Button { model.startMode(mode) } label: { Text(mode.title).font(.system(size: 10)).padding(9).background(model.mode == mode ? Theme.raised : .clear, in: Capsule()) }.buttonStyle(.plain) } }
            HStack { PillButton(title: model.playing ? "Pause" : "Lecture", symbol: model.playing ? "pause.fill" : "play.fill", primary: true) { model.togglePlayback() }; Spacer(); Button("Terminer") { model.stop() }.font(.system(size: 11)).buttonStyle(.plain) }
            Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1).tint(Theme.accent).accessibilityLabel("Volume général")
            Divider()
            HStack { Button("Ouvrir Onde") { openWindow(id: "main"); model.showWindow() }; Spacer(); Button("Quitter") { NSApp.terminate(nil) } }.font(.system(size: 11)).buttonStyle(.plain)
        }.padding(22).frame(width: 295).background(Theme.sidebar).foregroundStyle(Theme.ink).preferredColorScheme(.dark)
    }
}
