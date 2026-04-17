import Cocoa

let exitKeyCode: CGKeyCode = 14 // 'E'
let requiredFlags: CGEventFlags = [.maskCommand, .maskAlternate]

var eventTap: CFMachPort?

func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        if keyCode == exitKeyCode && flags == requiredFlags {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return nil
        }
    }

    if type == .keyDown || type == .keyUp || type == .flagsChanged {
        return nil
    }

    return Unmanaged.passUnretained(event)
}

let trusted = AXIsProcessTrustedWithOptions(
    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
)

if !trusted {
    let alert = NSAlert()
    alert.messageText = "NUMB needs Accessibility access"
    alert.informativeText = "Grant access in System Settings → Privacy & Security → Accessibility, then relaunch NUMB."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    exit(1)
}

let mask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue) |
    (1 << CGEventType.flagsChanged.rawValue)

eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: eventCallback,
    userInfo: nil
)

guard let tap = eventTap else {
    let alert = NSAlert()
    alert.messageText = "NUMB failed to lock keyboard"
    alert.informativeText = "Could not create event tap. Make sure Accessibility access is granted."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

final class OverlayController {
    var windows: [NSWindow] = []

    func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = NSColor(white: 0, alpha: 0.78)
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let container = NSView(frame: screen.frame)
            container.wantsLayer = true

            let title = NSTextField(labelWithString: "NUMB")
            title.font = NSFont.monospacedSystemFont(ofSize: 96, weight: .heavy)
            title.textColor = NSColor.white
            title.alignment = .center
            title.isBezeled = false
            title.isEditable = false
            title.drawsBackground = false

            let status = NSTextField(labelWithString: "keyboard locked")
            status.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
            status.textColor = NSColor(white: 1, alpha: 0.7)
            status.alignment = .center
            status.isBezeled = false
            status.isEditable = false
            status.drawsBackground = false

            let hint = NSTextField(labelWithString: "press  ⌘  ⌥  E  to unlock")
            hint.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .medium)
            hint.textColor = NSColor.white
            hint.alignment = .center
            hint.isBezeled = false
            hint.isEditable = false
            hint.drawsBackground = false

            let stack = NSStackView(views: [title, status, hint])
            stack.orientation = .vertical
            stack.spacing = 24
            stack.alignment = .centerX
            stack.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            window.contentView = container
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let overlay = OverlayController()
overlay.show()

app.run()
