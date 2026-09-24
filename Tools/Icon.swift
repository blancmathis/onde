import AppKit
let path = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let rect = NSRect(origin: .zero, size: size)
let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 55, dy: 55), xRadius: 205, yRadius: 205)
NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.31, blue: 0.25, alpha: 1), ending: NSColor(srgbRed: 0.09, green: 0.14, blue: 0.11, alpha: 1))!.draw(in: shape, angle: -55)
for i in 0..<29 {
    let f = Double(i)/29, radius = 100 + f*275
    let p = NSBezierPath()
    for j in 0...200 {
        let t = Double(j)/200 * Double.pi*2
        let organic = 1 + 0.045*sin(t*3 + f*3)
        let point = NSPoint(x: 508+cos(t)*radius*organic + sin(f*3)*12, y: 512+sin(t)*radius*0.80*organic)
        if j == 0 { p.move(to: point) } else { p.line(to: point) }
    }
    p.close(); p.lineWidth = i % 5 == 0 ? 3 : 1.7
    NSColor(srgbRed: 0.82, green: 0.92, blue: 0.73, alpha: 0.28 + f*0.55).setStroke(); p.stroke()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
