import AppKit

if Bundle.main.bundleIdentifier == "io.github.hrk877.gabugabu.toast-preview" {
    let project = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    precondition(FileManager.default.changeCurrentDirectoryPath(project.path))
}
let app = NSApplication.shared
app.setActivationPolicy(Bundle.main.bundleIdentifier == "io.github.hrk877.gabugabu.toast-preview" ? .accessory : .prohibited)
let icon = NSImage(contentsOfFile: "assets/AppIcon.icns")
var clicks = 0
let clickable = ToastCardView(detail: "アクセシビリティを許可してください。", success: false, icon: icon,
                              actionTitle: "アクセシビリティ設定を開く", onClick: { clicks += 1 })
precondition(clickable.accessibilityPerformPress() && clicks == 1, "A settings toast must perform its action")
precondition(clickable.acceptsFirstMouse(for: nil), "A settings toast must accept the first click without activating the app")
let hit = clickable.hitTest(NSPoint(x: 60, y: 20))
precondition(hit === clickable, "Clicking message text must reach the card action")
let passive = ToastCardView(detail: "", success: true, icon: icon)
precondition(!passive.accessibilityPerformPress() && !passive.acceptsFirstMouse(for: nil), "Saved must remain passive")
let clickPanel = ToastPanel(card: clickable)
let passivePanel = ToastPanel(card: passive)
precondition(!clickPanel.ignoresMouseEvents && passivePanel.ignoresMouseEvents, "Settings must receive clicks; Saved must pass them through")
let inside = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: clickable.bounds.midX, y: clickable.bounds.midY),
                                modifierFlags: [], timestamp: 0, windowNumber: clickPanel.windowNumber,
                                context: nil, eventNumber: 1, clickCount: 1, pressure: 0)!
clickable.mouseUp(with: inside)
precondition(clicks == 2, "Mouse release inside the card performs the action once")
let outside = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: -10, y: -10),
                                 modifierFlags: [], timestamp: 0, windowNumber: clickPanel.windowNumber,
                                 context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!
clickable.mouseUp(with: outside)
precondition(clicks == 2, "Dragging out of the card cancels the action")
print("PASS: settings toast action, first click and label hit routing; Saved stays passive")
let samples: [(String, Bool, String)] = [
    ("success", true, "2026-10-26.md"),
    ("error", false, "文章を選んでから ⌘⌥S を押してください。通常のコピーができる文章が対象です。"),
    ("settings", false, "保存するには、GABUGABUのアクセシビリティを許可してください。")
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
    let view = ToastCardView(detail: detail, success: success, icon: icon,
                             actionTitle: name == "settings" ? ToastAction.accessibilitySettings.title : nil,
                             onClick: name == "settings" ? {} : nil)
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

if Bundle.main.bundleIdentifier == "io.github.hrk877.gabugabu.toast-preview" {
    let destination: ToastAction = CommandLine.arguments.contains("--keyboard") ? .keyboardSettings : .accessibilitySettings
    let card = ToastCardView(detail: "設定が必要です。この通知をクリックしてください。", success: false, icon: icon,
                             actionTitle: destination.title, onClick: {
        let opened = NSWorkspace.shared.open(destination.url)
        print("Settings URL opened: \(opened)")
        exit(opened ? 0 : 1)
    })
    let panel = ToastPanel(card: card)
    if let frame = NSScreen.main?.visibleFrame {
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 16))
    }
    panel.orderFrontRegardless()
    Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { _ in exit(0) }
    app.run()
}
