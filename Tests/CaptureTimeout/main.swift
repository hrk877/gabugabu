import AppKit
import ApplicationServices

// Replace only the external AX calls when compiling Capture.swift for this test.
// Distinct objects deliberately share a PID: timeouts belong to the object, not the app.
var timeouts: [UInt: Float] = [:]
var unbounded: [String] = []
var mode = "full"
var reads = 0
var stalled = false
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
