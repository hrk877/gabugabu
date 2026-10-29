import AppKit
import ApplicationServices
import os

enum CaptureLog {
    private static let logger = Logger(subsystem: "io.github.hrk877.gabugabu", category: "Capture")
    // Callers pass fixed stage names and numbers only. Never pass user text or metadata.
    static func event(_ stage: String, code: Int = 0, count: Int = 0) {
        logger.notice("stage=\(stage, privacy: .public) code=\(code) count=\(count)")
    }
}

enum CaptureError: LocalizedError {
    case permission, unsupported, focusUnavailable
    var errorDescription: String? {
        switch self {
        case .permission: return "「使い方・権限設定」からアクセシビリティを許可してください。"
        case .unsupported: return "文章を選択するか、入力欄をクリックしてから ⌘⌥S を押してください。この画面の選択文は読み取れない場合があります。"
        case .focusUnavailable: return "このアプリから文章の選択位置を確認できませんでした。保存元の画面をクリックして、もう一度試してください。"
        }
    }
}

enum Capture {
    static func waitForFocus<Value>(read: @escaping (TimeInterval) -> Value?, isCurrent: @escaping () -> Bool,
                                   now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                                   schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void,
                                   completion: @escaping (Result<Value, Error>) -> Void) {
        let deadline = now() + 1.5
        func poll() {
            guard isCurrent() else { completion(.failure(CopySessionError.changed)); return }
            let remaining = deadline - now()
            guard remaining > 0 else { completion(.failure(CaptureError.focusUnavailable)); return }
            let value = read(remaining)
            guard isCurrent() else { completion(.failure(CopySessionError.changed)); return }
            guard now() < deadline else { completion(.failure(CaptureError.focusUnavailable)); return }
            if let value { completion(.success(value)); return }
            schedule(0.05, poll)
        }
        poll()
    }

    static func resolvedFocus(application: AXUIElement, pid: pid_t, enableAccessibility: Bool = false,
                              deadline: Date) -> AXUIElement? {
        func matching(_ element: AXUIElement?) -> AXUIElement? {
            guard let element, Date() < deadline else { return nil }
            AXUIElementSetMessagingTimeout(element, Float(min(0.08, deadline.timeIntervalSinceNow)))
            var owner: pid_t = 0
            guard AXUIElementGetPid(element, &owner) == .success, owner == pid, Date() < deadline else { return nil }
            return element
        }
        if let element = matching(elementAttribute(application, kAXFocusedUIElementAttribute, deadline: deadline)) { return element }
        if enableAccessibility, Date() < deadline {
            AXUIElementSetMessagingTimeout(application, Float(min(0.08, deadline.timeIntervalSinceNow)))
            let status = AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            CaptureLog.event("focus.enable", code: Int(status.rawValue))
            if let element = matching(elementAttribute(application, kAXFocusedUIElementAttribute, deadline: deadline)) { return element }
        }
        // Some apps expose keyboard focus only through the system-wide AX object.
        // Never substitute an element from a different process.
        return matching(elementAttribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute, deadline: deadline))
    }

    static func attribute(_ element: AXUIElement, _ name: String, deadline: Date? = nil) -> CFTypeRef? {
        if let deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return nil }
            AXUIElementSetMessagingTimeout(element, Float(min(0.08, remaining)))
        }
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        if let deadline, Date() >= deadline { return nil }
        return result
    }

    static func selectedText(_ element: AXUIElement, deadline: Date? = nil) -> String? {
        if let text = attribute(element, kAXSelectedTextAttribute, deadline: deadline) as? String { return text }
        // Some read-only native controls expose a selection range instead of AXSelectedText.
        guard let value = attribute(element, kAXSelectedTextRangeAttribute, deadline: deadline), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let rangeValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(rangeValue) == .cfRange else { return nil }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        if range.length == 0 { return "" }
        if let deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return nil }
            AXUIElementSetMessagingTimeout(element, Float(min(0.08, remaining)))
        }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString,
                                                         value, &result) == .success else { return nil }
        if let deadline, Date() >= deadline { return nil }
        return result as? String
    }

    static func read(_ element: AXUIElement, bundleID: String) throws -> (text: String, mode: CaptureContext.Mode) {
        // AX timeouts apply to the exact object, not the app or its child objects.
        // Share one budget across field reads and ancestor search.
        let deadline = Date().addingTimeInterval(0.75)
        guard let role = attribute(element, kAXRoleAttribute, deadline: deadline) as? String else { throw CaptureError.unsupported }
        let subrole = attribute(element, kAXSubroleAttribute, deadline: deadline) as? String
        guard CapturePolicy.allowedSelection(role: role, subrole: subrole, app: bundleID) else { throw CaptureError.unsupported }
        let selected = selectedText(element, deadline: deadline)
        guard Date() < deadline else { throw CaptureError.unsupported }
        if let selected, !selected.isEmpty { return (selected, .selection) }
        var writable = DarwinBoolean(false)
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { throw CaptureError.unsupported }
        AXUIElementSetMessagingTimeout(element, Float(min(0.08, remaining)))
        let settable = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &writable)
        let editable = attribute(element, "AXEditable", deadline: deadline) as? Bool ?? false
        if CapturePolicy.allowed(role: role, subrole: subrole, app: bundleID)
            && (editable || (settable == .success && writable.boolValue)) {
            // Never replace a failed selection read with the entire input field.
            do { return (try CapturePolicy.text(selected: selected, full: attribute(element, kAXValueAttribute, deadline: deadline) as? String), .full) }
            catch { throw CaptureError.unsupported }
        }
        // Read-only views often put selection on the containing Web area, not the focused link/text.
        // Walk only this control's ancestors. Never read their full values or scan sibling content.
        guard CapturePolicy.maySearchAncestors(role: role) else { throw CaptureError.unsupported }
        var current = element
        for _ in 0..<24 {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            guard let parent = elementAttribute(current, kAXParentAttribute, deadline: deadline) else { break }
            let parentRole = attribute(parent, kAXRoleAttribute, deadline: deadline) as? String ?? ""
            if parentRole == kAXWindowRole || parentRole == kAXApplicationRole { break }
            let parentSubrole = attribute(parent, kAXSubroleAttribute, deadline: deadline) as? String
            guard CapturePolicy.allowedSelection(role: parentRole, subrole: parentSubrole, app: bundleID) else { break }
            if let text = selectedText(parent, deadline: deadline), !text.isEmpty { return (text, .selection) }
            if parentRole == "AXWebArea" { break }
            current = parent
        }
        throw CaptureError.unsupported
    }

    static func elementAttribute(_ element: AXUIElement, _ name: String, deadline: Date? = nil) -> AXUIElement? {
        guard let value = attribute(element, name, deadline: deadline), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    // Only inspect the focused control's ancestors and its own window. Never scan other tabs.
    // Metadata is best-effort and has a small time budget; failure must not block saving text.
    static func context(element: AXUIElement, mode: CaptureContext.Mode, bundleID: String) -> CaptureContext {
        var result = CaptureContext(mode: mode, bundleID: bundleID)
        let deadline = Date().addingTimeInterval(0.5)
        func get(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return nil }
            AXUIElementSetMessagingTimeout(node, Float(min(0.1, remaining)))
            return attribute(node, name)
        }
        func getElement(_ node: AXUIElement, _ name: String) -> AXUIElement? {
            guard let value = get(node, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return unsafeBitCast(value, to: AXUIElement.self)
        }
        func source(_ node: AXUIElement, _ name: String) -> String? {
            let value = get(node, name)
            if let url = value as? URL { return url.absoluteString }
            return value as? String
        }
        // Never substitute the application's newly focused window for this control's window.
        if let window = getElement(element, kAXWindowAttribute) {
            result.title = get(window, kAXTitleAttribute) as? String
            result.source = source(window, kAXDocumentAttribute)
        }
        var current: AXUIElement? = element
        for _ in 0..<24 {
            guard let node = current, Date() < deadline else { break }
            let role = get(node, kAXRoleAttribute) as? String
            if role == "AXWebArea" {
                if let title = get(node, kAXTitleAttribute) as? String, !title.isEmpty { result.title = title }
                if let url = source(node, kAXURLAttribute), CaptureContext(source: url).sourceURL != nil {
                    result.source = url
                }
                break
            }
            if role == kAXWindowRole {
                if result.title == nil { result.title = get(node, kAXTitleAttribute) as? String }
                if result.source == nil { result.source = source(node, kAXDocumentAttribute) }
                break
            }
            current = getElement(node, kAXParentAttribute)
        }
        return result
    }

    static func safeForCopy(_ element: AXUIElement, bundleID: String) -> Bool {
        let deadline = Date().addingTimeInterval(0.2)
        guard let role = attribute(element, kAXRoleAttribute, deadline: deadline) as? String, !role.isEmpty else { return false }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return false }
        AXUIElementSetMessagingTimeout(element, Float(min(0.08, remaining)))
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)
        CaptureLog.event("copy.subrole-status", code: Int(status.rawValue))
        // Electron editors (including Canva) may expose the attribute with no value.
        // This is absence of an optional subrole, not a failed security read.
        guard Date() < deadline,
              status == .attributeUnsupported || status == .noValue || (status == .success && value is String) else { return false }
        return CapturePolicy.allowedSelection(role: role, subrole: value as? String, app: bundleID)
    }

    // Prime AX identity only, never selected text, as the user switches applications.
    static func prepare(_ front: NSRunningApplication) {
        guard AXIsProcessTrusted(), front.processIdentifier != getpid(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier,
              CapturePolicy.allowedSelection(role: "", subrole: nil, app: front.bundleIdentifier ?? "") else { return }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        let electron = isElectron(front)
        _ = resolvedFocus(application: application, pid: front.processIdentifier, enableAccessibility: electron,
                          deadline: Date().addingTimeInterval(0.15))
    }

    private static func isElectron(_ front: NSRunningApplication) -> Bool {
        front.bundleURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) } ?? false
    }

    static func focused(completion: @escaping (Result<(text: String, app: String, context: CaptureContext), Error>) -> Void) {
        CaptureLog.event("capture.start")
        guard AXIsProcessTrusted() else { CaptureLog.event("permission.denied"); completion(.failure(CaptureError.permission)); return }
        guard let front = NSWorkspace.shared.frontmostApplication else { completion(.failure(CaptureError.unsupported)); return }
        CaptureLog.event("capture.target", code: Int(front.processIdentifier))
        let bundleID = front.bundleIdentifier ?? ""
        guard CapturePolicy.allowedSelection(role: "", subrole: nil, app: bundleID) else { completion(.failure(CaptureError.unsupported)); return }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        var initialize = isElectron(front)
        waitForFocus(read: { remaining in
            let enable = initialize
            initialize = false
            return resolvedFocus(application: application, pid: front.processIdentifier, enableAccessibility: enable,
                                 deadline: Date().addingTimeInterval(min(0.3, remaining)))
        }, isCurrent: { NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier },
        schedule: { delay, action in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action) }) { result in
            switch result {
            case .success(let element): capture(element: element, front: front, application: application, completion: completion)
            case .failure(let error):
                CaptureLog.event("focus.unavailable")
                completion(.failure(error))
            }
        }
    }

    private static func capture(element: AXUIElement, front: NSRunningApplication, application: AXUIElement,
                                completion: @escaping (Result<(text: String, app: String, context: CaptureContext), Error>) -> Void) {
        let bundleID = front.bundleIdentifier ?? ""
        do {
            let deadline = Date().addingTimeInterval(0.2)
            let role = attribute(element, kAXRoleAttribute, deadline: deadline) as? String ?? ""
            let subrole = attribute(element, kAXSubroleAttribute, deadline: deadline) as? String
            guard CapturePolicy.allowedSelection(role: role, subrole: subrole, app: bundleID) else { completion(.failure(CaptureError.unsupported)); return }
            if let draft = try? read(element, bundleID: bundleID), !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let metadata = context(element: element, mode: draft.mode, bundleID: bundleID)
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier,
                      let current = resolvedFocus(application: application, pid: front.processIdentifier, deadline: Date().addingTimeInterval(0.1)),
                      CFEqual(element, current) else { completion(.failure(CopySessionError.changed)); return }
                CaptureLog.event("accessibility.success", count: draft.text.count)
                completion(.success((draft.text, front.localizedName ?? "Unknown", metadata)))
                return
            }
        }
        var metadata = context(element: element, mode: .selection, bundleID: bundleID)
        metadata.method = .copy
        CaptureLog.event("copy.begin")
        CopyCapture.selected(front: front, element: element) { result in
            completion(result.map { ($0, front.localizedName ?? "Unknown", metadata) })
        }
    }
}
