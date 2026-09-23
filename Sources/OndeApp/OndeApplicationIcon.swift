import AppKit

/// Register this bundle's real icon before AppKit needs NSApplicationIcon.
/// This process-local image cache avoids a synchronous IconServices lookup
/// when constructing alerts. It does not replace another registered image,
/// alter system services or substitute a different identity for the app.
@MainActor enum OndeApplicationIcon {
    private static var retainedImage: NSImage?

    @discardableResult
    static func register(in bundle: Bundle = .main) -> Bool {
        if retainedImage != nil { return true }
        guard let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url), image.isValid else { return false }
        guard image.setName(NSImage.applicationIconName) else { return false }
        retainedImage = image
        return true
    }
}
