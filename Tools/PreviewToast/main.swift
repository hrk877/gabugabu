import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let icon = NSImage(contentsOfFile: "assets/AppIcon.icns")
let samples: [(String, Bool, String)] = [
    ("success", true, "2026-10-26.md"),
    ("error", false, "「使い方・権限設定」からアクセシビリティを許可してください。")
]
for (name, success, detail) in samples {
    let view = ToastCardView(detail: detail, success: success, icon: icon)
    let window = NSWindow(contentRect: view.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/toast-\(name).png"))
    window.orderOut(nil)
}
print("Rendered actual success/error card views")
