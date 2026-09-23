import SwiftUI
import AppKit

extension View {
    /// Saved settings and informational sheets are not unsaved documents.
    /// A genuine unapplied edit remains protected until Apply or Discard.
    @ViewBuilder
    func ondeSheetTerminationPolicy(preventsTermination: Bool) -> some View {
        if #available(macOS 15.4, *) {
            presentationPreventsAppTermination(preventsTermination)
        } else {
            background {
                LegacySheetTerminationPolicy(preventsTermination: preventsTermination)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

/// macOS 14–15.3 equivalent, scoped to the window hosting this sheet only.
/// Never touches another window, dismisses a sheet, or forces process exit.
struct LegacySheetTerminationPolicy: NSViewRepresentable {
    var preventsTermination: Bool

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.preventsTermination = preventsTermination
        return view
    }
    func updateNSView(_ nsView: Probe, context: Context) {
        nsView.preventsTermination = preventsTermination
    }

    final class Probe: NSView {
        var preventsTermination = true { didSet { applyPolicy() } }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyPolicy()
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        private func applyPolicy() {
            window?.preventsApplicationTerminationWhenModal = preventsTermination
        }
    }
}
