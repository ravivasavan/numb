import Cocoa

let exitKeyCode: CGKeyCode = 40 // 'K'
let requiredFlags: CGEventFlags = [.maskCommand, .maskAlternate]

var eventTap: CFMachPort?
var lastFlags: CGEventFlags = []
var keyboardViews: [KeyboardView] = []

func pulseAll(_ code: CGKeyCode) {
    keyboardViews.forEach { $0.pulse(code) }
}

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

    switch type {
    case .keyDown:
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        if keyCode == exitKeyCode && flags == requiredFlags {
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return nil
        }
        DispatchQueue.main.async { pulseAll(keyCode) }
        return nil

    case .keyUp:
        return nil

    case .flagsChanged:
        let newFlags = event.flags
        let pressedBits = newFlags.rawValue & ~lastFlags.rawValue
        lastFlags = newFlags
        if pressedBits != 0 {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            DispatchQueue.main.async { pulseAll(keyCode) }
        }
        return nil

    default:
        return Unmanaged.passUnretained(event)
    }
}

let trusted = AXIsProcessTrustedWithOptions(
    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
)

if !trusted {
    let alert = NSAlert()
    alert.messageText = "Numb needs Accessibility access"
    alert.informativeText = "Grant access in System Settings → Privacy & Security → Accessibility, then relaunch Numb."
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
    alert.messageText = "Numb failed to lock keyboard"
    alert.informativeText = "Could not create event tap. Make sure Accessibility access is granted."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

enum Design {
    static let backdropTint = NSColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 0.80)
    static let captionColor = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 0.70)
}

func mono(_ size: CGFloat) -> NSFont {
    NSFont(name: "SFMono-Regular", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

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
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            content.autoresizingMask = [.width, .height]
            content.wantsLayer = true

            let blur = NSVisualEffectView(frame: content.bounds)
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            content.addSubview(blur)

            let tint = NSView(frame: content.bounds)
            tint.wantsLayer = true
            tint.layer?.backgroundColor = Design.backdropTint.cgColor
            tint.autoresizingMask = [.width, .height]
            content.addSubview(tint)

            let caption = NSTextField(labelWithString: "Press cmd option k to exit")
            caption.font = mono(14)
            caption.textColor = Design.captionColor
            caption.alignment = .center
            caption.isBezeled = false
            caption.isEditable = false
            caption.drawsBackground = false

            let keyboard = KeyboardView(frame: .zero)
            keyboardViews.append(keyboard)

            let stack = NSStackView(views: [caption, keyboard])
            stack.orientation = .vertical
            stack.spacing = 28
            stack.alignment = .centerX
            stack.translatesAutoresizingMaskIntoConstraints = false

            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])

            window.contentView = content
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
