import AppKit
import ApplicationServices

let abrID = "com.fasttracksoftware.adminbyrequest"
let approvalNotice = """
Your request for temporary administrator permission has been approved. After clicking OK, you will become administrator on your computer for a limited time, and a small countdown window will appear on the lower right side of your screen.

Please note that during the admin session, actions will be logged in the BITS system. Activity should be consistent with the Broad IT Acceptable Use policy (broad.io/AcceptableUse). If you have questions or concerns about this, please cancel this request and reach out to BITS (broad.io/help).
"""

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}
func string(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}
func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}
func descendants(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 10 else { return [] }
    return [element] + children(element).flatMap { descendants($0, depth: depth + 1) }
}
func button(_ window: AXUIElement, _ title: String) -> AXUIElement? {
    descendants(window).first { string($0, kAXRoleAttribute) == kAXButtonRole && string($0, kAXTitleAttribute) == title }
}
func hasText(_ window: AXUIElement, _ text: String) -> Bool {
    descendants(window).contains {
        string($0, kAXRoleAttribute) == kAXStaticTextRole &&
        (string($0, kAXValueAttribute) == text || string($0, kAXTitleAttribute) == text)
    }
}
func press(_ element: AXUIElement) throws {
    guard AXUIElementPerformAction(element, kAXPressAction as CFString) == .success else {
        throw Failure.message("Could not click an Admin By Request control.")
    }
}
enum Failure: Error { case message(String) }
enum SessionState { case unavailable, permissionRequired, unknown, inactive, active }
enum Operation { case enable, stop }

final class Controller: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let action = NSMenuItem(title: "Checking status…", action: #selector(toggle), keyEquivalent: "")
    var state = SessionState.unknown
    var operation: Operation?
    var deadline = Date.distantPast
    var typedReason = false
    var submittedReason = false
    var lastFinish = Date.distantPast
    var stoppedSamples = 0
    var timer: Timer?
    var lastReport = ""
    var verificationStage = 0
    #if VERIFICATION
    let verifying = CommandLine.arguments.contains("--verify-cycle")
    #else
    let verifying = false
    #endif
    let verificationDeadline = Date().addingTimeInterval(660)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.3)
        menu.delegate = self
        menu.autoenablesItems = false
        action.target = self
        menu.addItem(action)
        item.menu = menu
        tick()
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func menuWillOpen(_ menu: NSMenu) { tick() }

    func snapshot() -> (NSRunningApplication, [AXUIElement])? {
        guard AXIsProcessTrusted(), let app = NSRunningApplication.runningApplications(withBundleIdentifier: abrID).first else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        guard let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        return (app, windows)
    }

    func menuItem(_ app: NSRunningApplication, _ title: String) -> AXUIElement? {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        guard let value = attribute(root, "AXExtrasMenuBar"), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return descendants(value as! AXUIElement).first {
            string($0, kAXRoleAttribute) == kAXMenuItemRole && string($0, kAXTitleAttribute).lowercased() == title.lowercased()
        }
    }

    func tick() {
        guard let (app, windows) = snapshot() else {
            state = !AXIsProcessTrusted() ? .permissionRequired :
                NSRunningApplication.runningApplications(withBundleIdentifier: abrID).isEmpty ? .unavailable : .unknown
            if operation != nil && (state == .unavailable || !AXIsProcessTrusted() || Date() > deadline) {
                fail("Cannot read Admin By Request. Check that it is running and Accessibility is allowed.")
            }
            updateMenu()
            return
        }
        let session = windows.first { string($0, kAXTitleAttribute) == "Administrator Access" && button($0, "Finish") != nil }
        if menuItem(app, "End administrator access") != nil { state = .active }
        else if menuItem(app, "Request administrator access") != nil { state = .inactive }
        else { state = .unknown }
        if let operation {
            if Date() > deadline {
                fail("The operation has not completed. Check Admin By Request for authentication, approval, or an unfamiliar prompt.")
            } else {
                do { try advance(operation, app: app, windows: windows, session: session) }
                catch { fail("Could not complete the action: \(error)") }
            }
        }
        updateMenu()
    }

    func advance(_ operation: Operation, app: NSRunningApplication, windows: [AXUIElement], session: AXUIElement?) throws {
        switch operation {
        case .enable:
            if state == .active {
                if menuItem(app, "Show timer window") != nil {
                    self.operation = nil
                } else if let session {
                    _ = AXUIElementSetAttributeValue(session, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                }
                return
            }
            for window in windows {
                let title = string(window, kAXTitleAttribute)
                if title == "Instructions" {
                    if hasText(window, "Do you want to start an administrator session?"), let yes = button(window, "Yes") { try press(yes); return }
                    if hasText(window, approvalNotice), let ok = button(window, "OK") { try press(ok); return }
                }
                if title == "Request Administrator Access", !submittedReason {
                    let fields = descendants(window).filter { string($0, kAXRoleAttribute) == kAXTextFieldRole }
                    guard fields.count == 1 else { throw Failure.message("The reason form has changed; please complete it in Admin By Request.") }
                    if !typedReason {
                        if !app.isActive {
                            NSApp.yieldActivation(to: app)
                            app.activate()
                            return
                        }
                        guard AXUIElementSetAttributeValue(fields[0], kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
                            throw Failure.message("Could not focus the reason field.")
                        }
                        let root = AXUIElementCreateApplication(app.processIdentifier)
                        guard let focused = attribute(root, kAXFocusedUIElementAttribute), CFEqual(focused, fields[0]) else {
                            throw Failure.message("The reason field did not receive focus.")
                        }
                        guard AXUIElementSetAttributeValue(fields[0], kAXValueAttribute as CFString, "" as CFString) == .success else {
                            throw Failure.message("Could not clear the previous reason.")
                        }
                        // AX value writes do not trigger this form's validation. Send text to ABR's PID only.
                        sendReason(to: app.processIdentifier)
                        typedReason = true
                        return
                    }
                    guard string(fields[0], kAXValueAttribute) == "Update/install applications" else {
                        return
                    }
                    if let ok = button(window, "OK"), attribute(ok, kAXEnabledAttribute) as? Bool == true {
                        try press(ok)
                        submittedReason = true
                        deadline = Date().addingTimeInterval(600)
                        return
                    }
                }
            }
        case .stop:
            if let confirmation = windows.first(where: { hasText($0, "Are you done with your administrator session?") }), let yes = button(confirmation, "Yes") {
                try press(yes)
                stoppedSamples = 0
            } else if state == .active {
                stoppedSamples = 0
                if Date().timeIntervalSince(lastFinish) > 2, let end = menuItem(app, "End administrator access") {
                    try press(end)
                    lastFinish = Date()
                }
            } else if state == .inactive {
                // Require consecutive observations so a window transition isn't reported as completion.
                stoppedSamples += 1
                if stoppedSamples >= 3 { self.operation = nil }
            }
        }
    }

    func sendReason(to pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        // Keep each Unicode event short; no layout-dependent select-all shortcut.
        for character in "Update/install applications" {
            let text = Array(String(character).utf16)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                event?.flags = []
                text.withUnsafeBufferPointer { event?.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress!) }
                event?.postToPid(pid)
            }
        }
    }

    func updateMenu() {
        let busy = operation != nil
        if let operation { action.title = operation == .enable ? "Enabling Admin…" : "Stopping Admin…" }
        else {
            switch state {
            case .active: action.title = "Stop Admin"
            case .inactive: action.title = "Enable Admin"
            case .permissionRequired: action.title = "Enable Admin"
            case .unknown: action.title = "Cannot read Admin By Request status"
            case .unavailable: action.title = "Admin By Request is not running"
            }
        }
        action.isEnabled = !busy && (state == .active || state == .inactive || state == .permissionRequired)
        if action.title != lastReport {
            NSLog("ABR Shortcut: %@", action.title)
            lastReport = action.title
        }
        if verifying { DispatchQueue.main.async { self.verifyCycle() } }
        let symbol = busy ? "ellipsis.circle" : state == .active ? "person.fill" : "person"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ABR Shortcut: \(action.title)")
        item.button?.toolTip = "ABR Shortcut — \(action.title)"
    }

    // Explicit opt-in smoke test; refuse to disturb a pre-existing admin session.
    func verifyCycle() {
        guard verificationStage >= 0 else { return }
        if Date() > verificationDeadline || state == .permissionRequired || state == .unavailable {
            verificationStage = -1
            NSLog("VERIFY FAILED: unavailable or timed out; check ABR for a pending or active session")
            exit(EXIT_FAILURE)
        }
        guard operation == nil else { return }
        switch verificationStage {
        case 0:
            if state == .unknown { return }
            guard state == .inactive else {
                verificationStage = -1
                NSLog("VERIFY REFUSED: start from an inactive session")
                exit(EXIT_FAILURE)
            }
            if begin(.enable) { verificationStage = 1 }
        case 1:
            guard state == .active, let (app, _) = snapshot(), menuItem(app, "Show timer window") != nil else { return }
            NSLog("VERIFY: enabled and timer minimized")
            if begin(.stop) { verificationStage = 2 }
        case 2:
            guard state == .inactive else { return }
            verificationStage = -1
            NSLog("VERIFY PASSED: enabled, hid timer, stopped, returned to Enable Admin")
            exit(EXIT_SUCCESS)
        default: break
        }
    }

    @objc func toggle() {
        tick()
        if state == .permissionRequired {
            allowAccessibility()
            return
        }
        if state == .active { _ = begin(.stop) }
        else if state == .inactive { _ = begin(.enable) }
    }
    @discardableResult
    func begin(_ requested: Operation) -> Bool {
        guard operation == nil else { return false }
        tick()
        guard (requested == .enable && state == .inactive) || (requested == .stop && state == .active) else { return false }
        operation = requested
        deadline = Date().addingTimeInterval(30)
        typedReason = false
        submittedReason = false
        lastFinish = .distantPast
        stoppedSamples = 0
        if operation == .enable { requestAdmin() }
        updateMenu()
        return operation == requested
    }
    func requestAdmin() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: abrID) else {
            fail("Admin By Request is not installed.")
            return
        }
        NSWorkspace.shared.open([URL(string: "adminbyrequest://request-admin")!], withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { DispatchQueue.main.async { self.fail(error.localizedDescription) } }
            }
    }
    func allowAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func fail(_ message: String) {
        if verifying {
            verificationStage = -1
            NSLog("VERIFY FAILED: %@; check ABR for a pending or active session", message)
            exit(EXIT_FAILURE)
        }
        operation = nil
        updateMenu()
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "ABR Shortcut"
            alert.informativeText = message
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let controller = Controller()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
