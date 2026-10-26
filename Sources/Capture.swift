import AppKit
import ApplicationServices

enum CaptureError: LocalizedError {
    case permission, unsupported
    var errorDescription: String? {
        switch self {
        case .permission: return "「使い方・権限設定」からアクセシビリティを許可してください。"
        case .unsupported: return "文章を選択するか、入力欄をクリックしてから ⌘⌥S を押してください。この画面の選択文は読み取れない場合があります。"
        }
    }
}

enum Capture {
    static func attribute(_ element: AXUIElement, _ name: String, deadline: Date? = nil) -> CFTypeRef? {
        if let deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return nil }
            AXUIElementSetMessagingTimeout(element, Float(min(0.08, remaining)))
        }
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
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
        return result as? String
    }

    static func read(_ element: AXUIElement, bundleID: String) throws -> (text: String, mode: CaptureContext.Mode) {
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        guard CapturePolicy.allowedSelection(role: role, subrole: subrole, app: bundleID) else { throw CaptureError.unsupported }
        let selected = selectedText(element)
        if let selected, !selected.isEmpty { return (selected, .selection) }
        var writable = DarwinBoolean(false)
        let settable = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &writable)
        let editable = attribute(element, "AXEditable") as? Bool ?? false
        if CapturePolicy.allowed(role: role, subrole: subrole, app: bundleID)
            && (editable || (settable == .success && writable.boolValue)) {
            // Never replace a failed selection read with the entire input field.
            do { return (try CapturePolicy.text(selected: selected, full: attribute(element, kAXValueAttribute) as? String), .full) }
            catch { throw CaptureError.unsupported }
        }
        // Read-only views often put selection on the containing Web area, not the focused link/text.
        // Walk only this control's ancestors. Never read their full values or scan sibling content.
        guard CapturePolicy.maySearchAncestors(role: role) else { throw CaptureError.unsupported }
        let deadline = Date().addingTimeInterval(0.75)
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

    static func focused() throws -> (text: String, app: String, context: CaptureContext) {
        guard AXIsProcessTrusted() else { throw CaptureError.permission }
        guard let front = NSWorkspace.shared.frontmostApplication else { throw CaptureError.unsupported }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        guard let value = attribute(application, kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw CaptureError.unsupported
        }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        let bundleID = front.bundleIdentifier ?? ""
        let draft = try read(element, bundleID: bundleID)
        let metadata = context(element: element, mode: draft.mode, bundleID: bundleID)
        // Do not archive a stale field if the user switches apps while Accessibility responds.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier else { throw CaptureError.unsupported }
        return (draft.text, front.localizedName ?? "Unknown", metadata)
    }
}
