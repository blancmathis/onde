import AppKit
import ApplicationServices
import Foundation
import Darwin

// A separate client avoids re-entrant self-AX actions. Only the exact owned
// fixture executable/PID is eligible. Never requests or modifies TCC access.
func attribute(_ element: AXUIElement, _ key: String) -> Any? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}
func label(_ element: AXUIElement) -> String {
    [kAXDescriptionAttribute, kAXTitleAttribute, "AXPlaceholderValue"]
        .compactMap { attribute(element, $0) as? String }.first { !$0.isEmpty } ?? ""
}
func execute() throws -> [String: Any] {
    guard CommandLine.arguments.count == 4,
          let pid = Int32(CommandLine.arguments[1]), pid != getpid(),
          let app = NSRunningApplication(processIdentifier: pid),
          app.executableURL?.resolvingSymlinksInPath().path ==
            URL(fileURLWithPath: CommandLine.arguments[2]).resolvingSymlinksInPath().path,
          let request = try JSONSerialization.jsonObject(with: Data(CommandLine.arguments[3].utf8)) as? [String: Any]
    else { return ["code": -1, "error": "Target is not the exact owned fixture"] }
    guard AXIsProcessTrusted() else { return ["code": -2, "error": "Accessibility access is not authorized for this fixture client"] }
    alarm(12) // A hung helper is a failed test, not an unbounded wait.
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 2)
    let application = AXUIElementCreateApplication(pid)
    var visited: [AXUIElement] = []
    var matches: [AXUIElement] = []
    func visit(_ element: AXUIElement, depth: Int, sheet: Bool) {
        guard depth < 35, visited.count < 2500, !visited.contains(where: { CFEqual($0, element) }) else { return }
        visited.append(element)
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let inSheet = sheet || role == "AXSheet"
        let id = attribute(element, "AXIdentifier") as? String ?? ""
        let requestedID = request["id"] as? String ?? ""
        let identityMatches = !requestedID.isEmpty ? id == requestedID :
            label(element) == (request["label"] as? String ?? "") && role == (request["role"] as? String ?? "")
        if identityMatches && (!(request["in_sheet"] as? Bool ?? false) || inSheet) { matches.append(element) }
        for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth: depth + 1, sheet: inSheet) }
        for child in attribute(element, "AXSheets") as? [AXUIElement] ?? [] { visit(child, depth: depth + 1, sheet: true) }
    }
    for window in attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? [] { visit(window, depth: 0, sheet: false) }
    guard matches.count == 1, let element = matches.first else {
        return ["code": -3, "error": "Expected exactly one native action target", "matches": matches.count]
    }
    let result: AXError
    if let value = request["value"] as? String {
        result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFString)
    } else {
        result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    }
    return ["code": result.rawValue, "matches": matches.count]
}
do {
    let reply = try execute()
    print(String(data: try JSONSerialization.data(withJSONObject: reply, options: [.sortedKeys]), encoding: .utf8)!)
} catch {
    let reply: [String: Any] = ["code": -4, "error": error.localizedDescription]
    print(String(data: try JSONSerialization.data(withJSONObject: reply), encoding: .utf8)!)
    exit(1)
}
