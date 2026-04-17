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

func makeKeycap(_ symbol: String) -> NSView {
    let side: CGFloat = 96
    let cap = NSView()
    cap.wantsLayer = true
    cap.translatesAutoresizingMaskIntoConstraints = false

    let face = cap.layer!
    face.cornerRadius = 18
    face.cornerCurve = .continuous
    face.backgroundColor = NSColor(white: 1.0, alpha: 0.96).cgColor
    face.borderColor = NSColor(white: 1.0, alpha: 0.85).cgColor
    face.borderWidth = 1
    face.shadowColor = NSColor.black.cgColor
    face.shadowOpacity = 0.45
    face.shadowRadius = 18
    face.shadowOffset = CGSize(width: 0, height: -8)
    face.masksToBounds = false

    // Subtle inner highlight on top edge for the keycap feel
    let highlight = CALayer()
    highlight.frame = CGRect(x: 6, y: side - 4, width: side - 12, height: 2)
    highlight.backgroundColor = NSColor(white: 1.0, alpha: 0.9).cgColor
    highlight.cornerRadius = 1
    face.addSublayer(highlight)

    let label = NSTextField(labelWithString: symbol)
    label.font = NSFont.systemFont(ofSize: 44, weight: .semibold)
    label.textColor = NSColor(white: 0.08, alpha: 1.0)
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false
    label.translatesAutoresizingMaskIntoConstraints = false

    cap.addSubview(label)
    NSLayoutConstraint.activate([
        cap.widthAnchor.constraint(equalToConstant: side),
        cap.heightAnchor.constraint(equalToConstant: side),
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
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true

            // Real blur of everything behind the window
            let blur = NSVisualEffectView(frame: container.bounds)
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            container.addSubview(blur)

            // Dim tint on top of the blur for contrast
            let tint = NSView(frame: container.bounds)
            tint.wantsLayer = true
            tint.layer?.backgroundColor = NSColor(white: 0, alpha: 0.38).cgColor
            tint.autoresizingMask = [.width, .height]
            container.addSubview(tint)

            // Text + keycaps
            let title = NSTextField(labelWithString: "Numb")
            title.font = NSFont.monospacedSystemFont(ofSize: 84, weight: .heavy)
            title.textColor = NSColor.white
            title.alignment = .center
            title.isBezeled = false
            title.isEditable = false
            title.drawsBackground = false

            let caption = NSTextField(labelWithString: "keyboard locked")
            caption.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            caption.textColor = NSColor(white: 1, alpha: 0.55)
            caption.alignment = .center
            caption.isBezeled = false
            caption.isEditable = false
            caption.drawsBackground = false

            let hint = NSTextField(labelWithString: "press to unlock")
            hint.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
            hint.textColor = NSColor(white: 1, alpha: 0.7)
            hint.alignment = .center
            hint.isBezeled = false
            hint.isEditable = false
            hint.drawsBackground = false

            let keycaps = NSStackView(views: [
                makeKeycap("⌘"),
                makeKeycap("⌥"),
                makeKeycap("E"),
            ])
            keycaps.orientation = .horizontal
            keycaps.spacing = 18
            keycaps.alignment = .centerY

            let stack = NSStackView(views: [title, caption, hint, keycaps])
            stack.orientation = .vertical
            stack.spacing = 22
            stack.alignment = .centerX
            stack.setCustomSpacing(36, after: hint)
            stack.setCustomSpacing(6, after: title)
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
