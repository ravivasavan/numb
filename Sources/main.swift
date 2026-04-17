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
    static let backdropTint = NSColor(red: 0x32/255.0, green: 0x32/255.0, blue: 0x32/255.0, alpha: 0.80)
    static let white = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 1.0)
    static let captionBottomInset: CGFloat = 72
    static let hintKeycapSide: CGFloat = 26
    static let hintKeycapRadius: CGFloat = 4
    static let hintFontSize: CGFloat = 13
}

func mono(_ size: CGFloat) -> NSFont {
    NSFont(name: "SFMono-Regular", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

func makeHintKeycap(_ symbol: String) -> NSView {
    let cap = NSView()
    cap.wantsLayer = true
    cap.layer?.cornerRadius = Design.hintKeycapRadius
    cap.layer?.cornerCurve = .continuous
    cap.layer?.borderWidth = 1
    cap.layer?.borderColor = Design.white.cgColor
    cap.layer?.backgroundColor = NSColor.clear.cgColor
    cap.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(labelWithString: symbol)
    label.font = mono(Design.hintFontSize)
    label.textColor = Design.white
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false
    label.translatesAutoresizingMaskIntoConstraints = false

    cap.addSubview(label)
    NSLayoutConstraint.activate([
        cap.widthAnchor.constraint(equalToConstant: Design.hintKeycapSide),
        cap.heightAnchor.constraint(equalToConstant: Design.hintKeycapSide),
        label.centerXAnchor.constraint(equalTo: cap.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
    ])
    return cap
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

            // Keyboard — 75% of this screen's width, centered
            let keyboard = KeyboardView(targetWidth: screen.frame.width * 0.75)
            keyboardViews.append(keyboard)
            content.addSubview(keyboard)
            NSLayoutConstraint.activate([
                keyboard.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                keyboard.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])

            // Bottom hint — ⌘ ⌥ K keycaps + TO UNLOCK
            let keycaps = NSStackView(views: [
                makeHintKeycap("⌘"),
                makeHintKeycap("⌥"),
                makeHintKeycap("K"),
            ])
            keycaps.orientation = .horizontal
            keycaps.spacing = 2
            keycaps.alignment = .centerY

            let toUnlock = NSTextField(labelWithString: "TO UNLOCK")
            toUnlock.font = mono(Design.hintFontSize)
            toUnlock.textColor = Design.white
            toUnlock.alignment = .center
            toUnlock.isBezeled = false
            toUnlock.isEditable = false
            toUnlock.drawsBackground = false

            let hint = NSStackView(views: [keycaps, toUnlock])
            hint.orientation = .horizontal
            hint.spacing = 10
            hint.alignment = .centerY
            hint.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(hint)
            NSLayoutConstraint.activate([
                hint.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Design.captionBottomInset),
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
