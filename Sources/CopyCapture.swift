import AppKit
import ApplicationServices
import Carbon

final class SystemCopyBoard: CopyBoard {
    private let pasteboard: NSPasteboard
    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    var generation: Int { pasteboard.changeCount }
    var text: String? { pasteboard.string(forType: .string) }

    func snapshot() throws -> ClipboardSnapshot {
        var result: ClipboardSnapshot = []
        var bytes = 0
        let sourceItems = pasteboard.pasteboardItems
        guard sourceItems != nil || (pasteboard.types ?? []).isEmpty else { throw CopySessionError.snapshot }
        for item in sourceItems ?? [] {
            var formats: [String: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else { throw CopySessionError.snapshot }
                bytes += data.count
                guard bytes <= 8 * 1024 * 1024 else { throw CopySessionError.snapshot }
                formats[type.rawValue] = data
            }
            result.append(formats)
        }
        return result
    }

    func restore(_ snapshot: ClipboardSnapshot, ifGeneration expected: Int) -> Bool {
        var items: [NSPasteboardItem] = []
        for formats in snapshot {
            let item = NSPasteboardItem()
            for (type, data) in formats {
                guard item.setData(data, forType: NSPasteboard.PasteboardType(type)) else { return false }
            }
            items.append(item)
        }
        guard pasteboard.changeCount == expected else { return false }
        pasteboard.clearContents()
        return items.isEmpty || pasteboard.writeObjects(items)
    }
}

enum CopyCapture {
    static func selected(front: NSRunningApplication, element: AXUIElement,
                         completion: @escaping (Result<String, Error>) -> Void) {
        let bundleID = front.bundleIdentifier ?? ""
        guard Capture.safeForCopy(element, bundleID: bundleID) else {
            CaptureLog.event("copy.safety-rejected")
            completion(.failure(CaptureError.unsupported)); return
        }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        func current() -> Bool {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier else { return false }
            // Reject another field/tab in the same app, not only an app switch.
            let deadline = Date().addingTimeInterval(0.1)
            guard let focused = Capture.resolvedFocus(application: application, pid: front.processIdentifier, deadline: deadline),
                  CFEqual(element, focused) else { return false }
            return true
        }
        let session = CopySession(board: SystemCopyBoard(), targetIsCurrent: current, sendCopy: {
            guard current(), let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else { throw CopySessionError.copyFailed }
            down.flags = .maskCommand; up.flags = .maskCommand
            CaptureLog.event("copy.sent", code: Int(CGEventSource.flagsState(.combinedSessionState).rawValue))
            down.postToPid(front.processIdentifier); up.postToPid(front.processIdentifier)
        }, schedule: { delay, action in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action) })
        session.start { result in
            switch result {
            case .success(let text): CaptureLog.event("copy.success", count: text.count)
            case .failure(let error):
                switch error as? CopySessionError {
                case .snapshot: CaptureLog.event("copy.snapshot-failed")
                case .unavailable: CaptureLog.event("copy.no-text-before-deadline")
                case .changed: CaptureLog.event("copy.target-or-clipboard-changed")
                default: CaptureLog.event("copy.send-failed")
                }
            }
            completion(result)
        }
    }
}
