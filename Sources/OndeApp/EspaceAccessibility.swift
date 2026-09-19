import SwiftUI

/// accessibilityReduceMotion is read-only. Combine system and app preferences
/// at EspaceRootView, then propagate the effective policy through our own key.
private struct EspaceReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var espaceReduceMotion: Bool {
        get { self[EspaceReduceMotionKey.self] }
        set { self[EspaceReduceMotionKey.self] = newValue }
    }
}
