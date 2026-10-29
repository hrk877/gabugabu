import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let icon = NSImage(contentsOfFile: "assets/AppIcon.icns")
let samples: [(String, Bool, String)] = [
    ("success", true, "2026-10-26.md"),
    ("error", false, "「使い方・権限設定」からアクセシビリティを許可してください。")
]
func verifySavedEdges(_ bitmap: NSBitmapImageRep, scale: Int) {
    func rows(_ left: Int, _ right: Int) -> [Int] {
        (0..<bitmap.pixelsHigh).filter { y in
            (left * scale..<right * scale).contains { x in
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                return color.alphaComponent > 0.5 && max(color.redComponent, color.greenComponent, color.blueComponent) < 120.0 / 255
            }
        }
    }
    let icon = rows(10, 37), text = rows(37, 85)
    precondition(!icon.isEmpty && !text.isEmpty && icon.first == text.first && icon.last == text.last,
                 "Saved/icon visible top and bottom must match at \(scale)x")
    print("PASS: Saved/icon pixel edges match at \(scale)x")
}
for (name, success, detail) in samples {
    let view = ToastCardView(detail: detail, success: success, icon: icon)
    let window = NSWindow(contentRect: view.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    if success { verifySavedEdges(bitmap, scale: 1) }
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/toast-\(name).png"))
    let retina = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2),
                                 pixelsHigh: Int(view.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                 hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    retina.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: retina)
    if success { verifySavedEdges(retina, scale: 2) }
    try retina.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/toast-\(name)@2x.png"))
    window.orderOut(nil)
}
print("Rendered actual success/error card views")
