import AppKit
import Carbon
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var shortcut: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var help: NSWindow?
    private var toast: NSPanel?
    private var toastTimer: Timer?
    private var archive: Archive?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch Services normally reuses the running app; guard direct binary launches too.
        let same = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.hrk877.gabugabu")
        if same.contains(where: { $0.processIdentifier != getpid() }) { NSApp.terminate(nil); return }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "GABUGABU")
        let menu = NSMenu()
        let title = NSMenuItem(title: "GABUGABU", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(NSMenuItem(title: "選択文・入力欄を保存　⌘⌥S", action: #selector(save), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "保存フォルダーを開く", action: #selector(openArchive), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "使い方・権限設定", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        status.menu = menu
        do { archive = Archive(directory: try StorageLocation.prepare()) }
        catch {
            showHelp()
            message("GABUGABU Archiveを準備できませんでした。既存の記録は上書きしていません。\n" + error.localizedDescription, success: false)
        }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            delegate.save()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: 0x4B544C47, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &shortcut)
        if result != noErr {
            showHelp()
            message("⌘⌥S を登録できません。他アプリの同じショートカットを解除し、GABUGABUを起動し直してください。", success: false)
        } else if !AXIsProcessTrusted() { showHelp() }
    }

    @objc func save() {
        guard let archive else { message("GABUGABU Archiveの準備に失敗しています。アプリを再起動してください。", success: false); return }
        do {
            let captured = try Capture.focused()
            let file = try archive.save(text: captured.text, app: captured.app, context: captured.context)
            message("保存しました · \(file.lastPathComponent)", success: true)
        } catch { message(error.localizedDescription, success: false) }
    }

    @objc func openArchive() {
        guard let archive else { message("GABUGABU Archiveを開けません。アプリを再起動してください。", success: false); return }
        do {
            try FileManager.default.createDirectory(at: archive.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            NSWorkspace.shared.open(archive.directory)
        } catch { message(error.localizedDescription, success: false) }
    }

    @objc func showHelp() {
        if let help { NSApp.activate(ignoringOtherApps: true); help.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 370), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "GABUGABU"
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSTextField(labelWithString: "書いた言葉を、手元に残す。")
        heading.font = .systemFont(ofSize: 24, weight: .semibold)
        stack.addArrangedSubview(heading)
        let body = NSTextField(wrappingLabelWithString: "① 下のボタンでアクセシビリティ設定を開き、\n　「GABUGABU」を許可します。\n② 保存したい文章を選んで ⌘⌥S を押します。\n\n入力欄は、選択なしでも全文を保存できます。\nタイトル・URLは取得できる場合に自動記録。\n\nGABUGABU Archive：ホーム → GABUGABU → Archive\n外部送信・クリップボード操作はありません。\n対応していない画面とパスワード欄は保存しません。")
        body.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(body)
        let button = NSButton(title: "アクセシビリティ設定を開く", target: self, action: #selector(openPermission))
        button.bezelStyle = .rounded
        stack.addArrangedSubview(button)
        let done = NSButton(title: "使い始める", target: self, action: #selector(closeHelp))
        done.bezelStyle = .rounded
        stack.addArrangedSubview(done)
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26)
        ])
        help = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func closeHelp() { help?.close(); NSApp.hide(nil) }
    @objc func openPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHelp()
        return true
    }

    private func message(_ text: String, success: Bool) {
        toastTimer?.invalidate()
        toast?.close()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: success ? 62 : 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let label = NSTextField(wrappingLabelWithString: (success ? "✓ " : "保存できません · ") + text)
        label.font = .systemFont(ofSize: 14)
        label.frame = panel.contentView!.bounds.insetBy(dx: 20, dy: 16)
        label.autoresizingMask = [.width, .height]
        panel.contentView!.addSubview(label)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameTopLeftPoint(NSPoint(x: frame.midX - 210, y: frame.maxY - 35)) }
        toast = panel
        panel.orderFrontRegardless()
        toastTimer = Timer.scheduledTimer(withTimeInterval: success ? 2 : 6, repeats: false) { [weak self] _ in self?.toast?.close() }
        if !success { NSSound.beep() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
