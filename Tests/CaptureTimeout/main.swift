import AppKit
import ApplicationServices

// Replace only the external AX calls when compiling Capture.swift for this test.
// Distinct objects deliberately share a PID: timeouts belong to the object, not the app.
var timeouts: [UInt: Float] = [:]
var unbounded: [String] = []
var mode = "full"
var reads = 0
var stalled = false
var focusScenario = ""
var focusApplication: AXUIElement!
var focusSystem: AXUIElement!
var focusField: AXUIElement!
var focusOther: AXUIElement!
var accessibilityEnabled = false
func testSystemWide() -> AXUIElement { focusSystem }
func testGetPid(_ element: AXUIElement, _ pid: UnsafeMutablePointer<pid_t>) -> AXError {
    observe(element, "pid")
    pid.pointee = CFEqual(element, focusOther) ? 999 : 123
    return .success
}
func testSetAttribute(_ element: AXUIElement, _ name: CFString, _ value: CFTypeRef) -> AXError {
    observe(element, "set-attribute")
    require(CFEqual(element, focusApplication) && name as String == "AXManualAccessibility" && CFEqual(value, kCFBooleanTrue), "Only enable the target app's accessibility")
    accessibilityEnabled = true
    return .success
}
func identity(_ element: AXUIElement) -> UInt { UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque()) }
@discardableResult func testSetTimeout(_ element: AXUIElement, _ value: Float) -> AXError {
    timeouts[identity(element)] = value
    return .success
}
func observe(_ element: AXUIElement, _ operation: String) {
    reads += 1
    // Consume each grant so a stale timeout cannot hide a missing refresh.
    if let timeout = timeouts.removeValue(forKey: identity(element)), timeout > 0, timeout <= 0.75 { return }
    unbounded.append(operation)
}
func testCopyAttribute(_ element: AXUIElement, _ name: CFString, _ result: UnsafeMutablePointer<CFTypeRef?>) -> AXError {
    let key = name as String
    observe(element, key)
    if key == kAXRoleAttribute && mode == "secure-role" { result.pointee = "AXSecureTextField" as CFString; return .success }
    if !focusScenario.isEmpty && key == kAXFocusedUIElementAttribute {
        if CFEqual(element, focusApplication) {
            if focusScenario == "application" || (focusScenario == "electron" && accessibilityEnabled) {
                result.pointee = focusField; return .success
            }
        } else if CFEqual(element, focusSystem) {
            if focusScenario == "system" { result.pointee = focusField; return .success }
            if focusScenario == "other-app" { result.pointee = focusOther; return .success }
        }
        return .noValue
    }
    if key == kAXRoleAttribute && mode == "unknown-role" { return .cannotComplete }
    if key == kAXSubroleAttribute && mode == "failed-subrole" { return .cannotComplete }
    if key == kAXSubroleAttribute && mode == "unsupported-subrole" { return .attributeUnsupported }
    // Canva's ordinary AXTextArea returns kAXErrorNoValue, not attributeUnsupported.
    if key == kAXSubroleAttribute && mode == "absent-subrole" { return .noValue }
    if key == kAXSubroleAttribute && mode == "malformed-subrole" { result.pointee = nil; return .success }
    if key == kAXSubroleAttribute && mode == "secure" { result.pointee = "AXSecureTextField" as CFString; return .success }
    if mode == "stall" && !stalled {
        stalled = true
        Thread.sleep(forTimeInterval: 0.85)
        result.pointee = nil
        return .cannotComplete
    }
    if key == kAXSelectedTextAttribute && mode == "range" { return .attributeUnsupported }
    if key == kAXSelectedTextRangeAttribute {
        var range = CFRange(location: 0, length: 7)
        result.pointee = AXValueCreate(.cfRange, &range)
        return .success
    }
    let values: [String: Any] = [kAXRoleAttribute: "AXTextArea", kAXSubroleAttribute: "",
        kAXSelectedTextAttribute: mode == "selected" ? "excerpt" : "", "AXEditable": true,
        kAXValueAttribute: "whole field"]
    result.pointee = values[key] as AnyObject?
    return result.pointee == nil ? .attributeUnsupported : .success
}
func testIsSettable(_ element: AXUIElement, _ name: CFString, _ result: UnsafeMutablePointer<DarwinBoolean>) -> AXError {
    observe(element, "settable")
    result.pointee = true
    return .success
}
func testCopyParameterized(_ element: AXUIElement, _ name: CFString, _ parameter: CFTypeRef, _ result: UnsafeMutablePointer<CFTypeRef?>) -> AXError {
    observe(element, "string-for-range")
    result.pointee = "excerpt" as CFString
    return .success
}
func require(_ condition: Bool, _ message: String) {
    if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
for scenario in ["full", "selected", "range", "stall"] {
    mode = scenario; timeouts = [:]; unbounded = []; reads = 0; stalled = false
    let application = AXUIElementCreateApplication(getpid())
    let field = AXUIElementCreateApplication(getpid())
    _ = testSetTimeout(application, 1)
    do {
        let value = try Capture.read(field, bundleID: "test.synthetic")
        require(scenario != "stall", "An expired capture must stop")
        require(value.text == (scenario == "full" ? "whole field" : "excerpt"), "Original text and selection semantics preserved")
        require(value.mode == (scenario == "full" ? .full : .selection), "Capture mode preserved")
    } catch {
        require(scenario == "stall", "Unexpected failure in \(scenario): \(error)")
    }
    require(unbounded.isEmpty, "\(scenario): untimed field API calls: \(unbounded.joined(separator: ","))")
    if scenario == "stall" { require(reads == 1, "No AX reads after the shared deadline expires") }
}
print("PASS: exact-element AX timeouts, selection/full/range capture, no reads after deadline")
for (scenario, allowed) in [("normal", true), ("unsupported-subrole", true), ("absent-subrole", true), ("malformed-subrole", false), ("unknown-role", false), ("failed-subrole", false), ("secure", false), ("secure-role", false)] {
    mode = scenario; timeouts = [:]; unbounded = []
    let field = AXUIElementCreateApplication(getpid())
    require(Capture.safeForCopy(field, bundleID: "test.synthetic") == allowed, "Copy safety classification: \(scenario)")
    require(!Capture.safeForCopy(field, bundleID: "com.apple.Passwords"), "Never copy from blocked apps, including absent subroles")
    require(unbounded.isEmpty, "Copy safety reads must also have per-call timeouts")
}
print("PASS: copy fallback rejects unknown/failed security reads and secure fields")
for scenario in ["application", "system", "other-app", "missing", "electron", "expired"] {
    focusScenario = scenario; accessibilityEnabled = false; timeouts = [:]; unbounded = []
    focusApplication = AXUIElementCreateApplication(123)
    focusSystem = AXUIElementCreateApplication(456)
    focusField = AXUIElementCreateApplication(123)
    focusOther = AXUIElementCreateApplication(999)
    reads = 0
    let result = Capture.resolvedFocus(application: focusApplication, pid: 123, enableAccessibility: scenario == "electron", deadline: Date().addingTimeInterval(scenario == "expired" ? -1 : 0.3))
    require((result != nil) == ["application", "system", "electron"].contains(scenario), "Resolve known focused field: \(scenario)")
    require(accessibilityEnabled == (scenario == "electron"), "Do not enable accessibility unnecessarily")
    require(unbounded.isEmpty, "Focus resolution must bound every AX call")
    if scenario == "expired" { require(reads == 0, "Do not resolve or initialize accessibility after the deadline") }
}
print("PASS: application/system focus resolution, reject other PID and unknown focus, Electron initialization")
for scenario in ["cold", "missing", "switch", "late"] {
    var clock: TimeInterval = 0
    var jobs: [() -> Void] = []
    var active = true
    var result: Result<AXUIElement, Error>?
    var callbacks = 0
    Capture.waitForFocus(read: { _ in
        if scenario == "late" { clock = 2; return focusField }
        if scenario == "switch" { active = false }
        return scenario == "cold" && clock >= 0.6 ? focusField : nil
    }, isCurrent: { active }, now: { clock }, schedule: { delay, action in
        jobs.append { clock += delay; action() }
    }) { value in result = value; callbacks += 1 }
    for _ in 0..<100 {
        guard !jobs.isEmpty else { break }
        jobs.removeFirst()()
    }
    require(result != nil && callbacks == 1, "Focus readiness completes exactly once: \(scenario)")
    require(((try? result!.get()) != nil) == (scenario == "cold"), "Wait for cold focus, reject unknown/switched/late focus: \(scenario)")
}
print("PASS: one capture waits for cold AX readiness, bounded missing focus, app switch and late-result refusal")
