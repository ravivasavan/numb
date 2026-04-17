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

// MARK: - Design tokens

enum Design {
    static let night = NSColor(red: 0x0D / 255.0, green: 0x1B / 255.0, blue: 0x1E / 255.0, alpha: 1.0)
    static let white = NSColor(red: 0xFF / 255.0, green: 0xF5 / 255.0, blue: 0xF5 / 255.0, alpha: 1.0)
    static let backdropTint = NSColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0, alpha: 0.80)
    static let shadow = NSColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0, alpha: 0.25)
    static let keycapSide: CGFloat = 80
    static let keycapRadius: CGFloat = 12.444
    static let keycapGap: CGFloat = 8
    static let keySymbolSize: CGFloat = 40
    static let captionSize: CGFloat = 16
}

func mono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    if let sfMono = NSFont(name: "SFMono-Regular", size: size) {
        return sfMono
    }
    return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

func makeKeycap(_ symbol: String) -> NSView {
    let cap = NSView()
    cap.wantsLayer = true
    cap.translatesAutoresizingMaskIntoConstraints = false

    let face = cap.layer!
    face.cornerRadius = Design.keycapRadius
    face.cornerCurve = .continuous
    face.backgroundColor = Design.night.cgColor
    face.shadowColor = Design.shadow.cgColor
    face.shadowOpacity = 1.0 // alpha already baked into shadow color
    face.shadowRadius = 4
    face.shadowOffset = CGSize(width: 0, height: -4)
    face.masksToBounds = false

    let label = NSTextField(labelWithString: symbol)
    label.font = mono(Design.keySymbolSize, weight: .regular)
    label.textColor = Design.white
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false
    label.translatesAutoresizingMaskIntoConstraints = false

    cap.addSubview(label)
    NSLayoutConstraint.activate([
        cap.widthAnchor.constraint(equalToConstant: Design.keycapSide),
        cap.heightAnchor.constraint(equalToConstant: Design.keycapSide),
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
            window.setFrame(screen.frame, display: true) // anchor explicitly on this screen
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

            // Backdrop blur — system blur behind the window
            let blur = NSVisualEffectView(frame: content.bounds)
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            content.addSubview(blur)

            // Backdrop tint — rgba(26, 26, 26, 0.80)
            let tint = NSView(frame: content.bounds)
            tint.wantsLayer = true
            tint.layer?.backgroundColor = Design.backdropTint.cgColor
            tint.autoresizingMask = [.width, .height]
            content.addSubview(tint)

            // Foreground: keycaps + caption
            let keycaps = NSStackView(views: [
                makeKeycap("⌘"),
                makeKeycap("⌥"),
                makeKeycap("E"),
            ])
            keycaps.orientation = .horizontal
            keycaps.spacing = Design.keycapGap
            keycaps.alignment = .centerY

            let caption = NSTextField(labelWithString: "TO UNLOCK")
            caption.font = mono(Design.captionSize, weight: .regular)
            caption.textColor = Design.white
            caption.alignment = .center
            caption.isBezeled = false
            caption.isEditable = false
            caption.drawsBackground = false

            let stack = NSStackView(views: [keycaps, caption])
            stack.orientation = .vertical
            stack.spacing = 16
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
