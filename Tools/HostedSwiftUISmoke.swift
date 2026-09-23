import AppKit
import SwiftUI
import Metal

/// Framework-only runner diagnostic: no Onde code, audio, preferences or files.
@main struct HostedSwiftUISmoke {
    @MainActor static func main() async {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        print("METAL", MTLCreateSystemDefaultDevice()?.name ?? "none"); fflush(stdout)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 500, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let canvas = CommandLine.arguments.contains("--canvas")
        let view = NSHostingView(rootView: VStack {
            Text("Framework-only SwiftUI smoke test")
            Button("Probe button") { print("PROBE_PRESS") }.accessibilityIdentifier("probe-button")
            if canvas {
                Canvas { context, size in
                    var line = Path(); line.move(to: .zero); line.addLine(to: CGPoint(x: size.width, y: size.height))
                    context.stroke(line, with: .color(.primary), lineWidth: 2)
                }.frame(width: 200, height: 100)
            }
        }.frame(width: 500, height: 300))
        window.contentView = view
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        var seen = Set<ObjectIdentifier>()
        func dump(_ item: Any, _ depth: Int) {
            guard depth < 20, let object = item as? NSObject, seen.insert(ObjectIdentifier(object)).inserted else { return }
            let modern = item as? NSAccessibilityProtocol
            let raw = object.accessibilityAttributeValue(.children) as? [Any] ?? []
            let direct = modern?.accessibilityChildren() ?? []
            print("AX", depth, String(describing: type(of: object)), "protocol", modern != nil,
                  "direct", direct.count, "legacy", raw.count,
                  "id", object.accessibilityAttributeValue(.identifier) ?? "")
            for child in direct.isEmpty ? raw : direct { dump(child, depth + 1) }
        }
        dump(window, 0)
        print("FRAMEWORK_SMOKE_OK", canvas ? "canvas" : "controls"); fflush(stdout)
        window.orderOut(nil)
    }
}
