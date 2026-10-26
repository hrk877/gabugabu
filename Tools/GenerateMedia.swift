import AppKit
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let ink = NSColor(srgbRed: 0.09, green: 0.11, blue: 0.15, alpha: 1)
let cream = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1)
let orange = NSColor(srgbRed: 0.95, green: 0.42, blue: 0.25, alpha: 1)
let muted = NSColor(srgbRed: 0.43, green: 0.45, blue: 0.49, alpha: 1)

func rect(_ r: NSRect, _ color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
}
func text(_ value: String, _ r: NSRect, size: CGFloat, color: NSColor = ink, weight: NSFont.Weight = .regular, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    (value as NSString).draw(in: r, withAttributes: [.font: font, .foregroundColor: color])
}
func render(_ width: Int, _ height: Int, _ draw: () -> Void) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}
func png(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest))
}
func mark(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat) {
    rect(NSRect(x: x, y: y, width: side, height: side), orange, radius: side * 0.22)
    let shape = NSBezierPath()
    let center = NSPoint(x: x + side * 0.44, y: y + side * 0.5)
    shape.move(to: center)
    shape.appendArc(withCenter: center, radius: side * 0.33, startAngle: 45, endAngle: 315, clockwise: false)
    shape.close()
    ink.setFill(); shape.fill()
    for i in 0..<3 {
        rect(NSRect(x: x + side * (i == 1 ? 0.7 : 0.65), y: y + side * (0.4 + Double(i) * 0.08), width: side * (i == 1 ? 0.17 : 0.22), height: side * 0.035), cream, radius: side * 0.017)
    }
}

let cover = render(1200, 630) {
    rect(NSRect(x: 0, y: 0, width: 1200, height: 630), cream)
    mark(68, 64, 72)
    text("GABUGABU", NSRect(x: 160, y: 74, width: 700, height: 70), size: 46, weight: .heavy)
    text("書いた言葉を、\nひとくちで保存。", NSRect(x: 68, y: 206, width: 1050, height: 180), size: 65, weight: .bold)
    rect(NSRect(x: 70, y: 448, width: 238, height: 70), orange, radius: 18)
    text("⌘  ⌥  S", NSRect(x: 108, y: 461, width: 220, height: 48), size: 32, color: .white, weight: .semibold)
    text("選ぶ → 押す → Markdownで残る", NSRect(x: 340, y: 470, width: 770, height: 45), size: 27, weight: .medium)
    text("macOS  /  LOCAL FILES  /  NO ACCOUNT", NSRect(x: 70, y: 560, width: 1000, height: 30), size: 17, color: muted, weight: .medium)
}
png(cover, output.appendingPathComponent("social.png"))

let icons = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = render(pixels, pixels) { mark(0, 0, CGFloat(pixels)) }
        png(image, icons.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}

let demo = Process()
demo.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
demo.arguments = ["swift", "Tools/GenerateDemo.swift", output.appendingPathComponent("demo.gif").path]
try demo.run()
demo.waitUntilExit()
precondition(demo.terminationStatus == 0, "Demo generation failed")
print("Generated social.png, demo.gif and AppIcon.iconset")
