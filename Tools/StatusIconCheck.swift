import AppKit

@main struct StatusIconCheck {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an output directory") }
        let icon = OndeStatusIcon.image
        precondition(icon.isTemplate && icon.size == NSSize(width:18,height:18))
        precondition(icon.accessibilityDescription == "Onde")
        let directory = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        for scale in [1,2] {
            let pixels = 18 * scale
            let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,
                bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,
                bytesPerRow:0,bitsPerPixel:0)!
            bitmap.size = NSSize(width:18,height:18)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
            icon.draw(in:NSRect(x:0,y:0,width:18,height:18))
            NSGraphicsContext.restoreGraphicsState()
            var opaque = 0, transparent = 0
            for y in 0..<pixels { for x in 0..<pixels {
                let alpha = bitmap.colorAt(x:x,y:y)!.alphaComponent
                if alpha > 0.5 { opaque += 1 }
                if alpha < 0.05 { transparent += 1 }
            } }
            // Upper-right corner formerly contained the detached orbit dot.
            for y in 0..<(3 * scale) { for x in (14 * scale)..<pixels {
                precondition(bitmap.colorAt(x:x,y:y)!.alphaComponent < 0.05,
                             "No detached point is allowed above the right-hand ring")
            } }
            precondition(opaque > pixels && transparent > pixels,"Icon must be visible on a transparent background")
            try bitmap.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent("onde-menu-bar-\(scale)x.png"))
            print("PASS Onde template at \(scale)x: \(pixels) × \(pixels), no title or playback state")
        }
    }
}
