import Cocoa

var eventTap: CFMachPort?
var lastFlags: CGEventFlags = []
var keyboardViews: [KeyboardView] = []
var overlay: OverlayController!
var settingsController: SettingsController!

func pulseAll(_ code: CGKeyCode) {
    keyboardViews.forEach { $0.pulse(code) }
}

func isMouseEvent(_ type: CGEventType) -> Bool {
    switch type {
    case .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
         .rightMouseDown, .rightMouseUp, .rightMouseDragged,
         .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel:
        return true
    default:
        return false
    }
}

func sillyReady() -> Bool {
    guard AppSettings.sillyMode else { return true }
    return AppState.pressedKeys.isSuperset(of: KeyboardView.allKeyCodes)
}

func handleKeyPressed(_ keyCode: CGKeyCode) {
    let inserted = AppState.pressedKeys.insert(keyCode).inserted
    pulseAll(keyCode)
    if inserted && AppSettings.sillyMode {
        NotificationCenter.default.post(name: .numbSillyProgressDidChange, object: nil)
    }
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

    // Mouse events: swallow while locked, pass through when settings is open.
    if isMouseEvent(type) {
        if AppState.settingsOpen {
            return Unmanaged.passUnretained(event)
        }
        return nil
    }

    // Shortcut capture mode: absorb everything. Live-echo modifier keys as
    // they're held, commit on keydown of a non-modifier + modifier. Esc cancels.
    if AppState.capturingShortcut {
        if type == .flagsChanged {
            let raw = event.flags
            lastFlags = raw
            let liveFlags = raw.intersection(
                [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            )
            DispatchQueue.main.async {
                AppState.captureLiveFlags = liveFlags
                NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
            }
        } else if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags.intersection(
                [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            )
            if keyCode == 53 { // Esc cancels
                DispatchQueue.main.async {
                    AppState.capturingShortcut = false
                    AppState.captureLiveFlags = []
                    NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
                }
            } else if !flags.isEmpty {
                let newShortcut = Shortcut(keyCode: UInt16(keyCode), flagsRaw: flags.rawValue)
                DispatchQueue.main.async {
                    // Clear capture state BEFORE assigning — the shortcut setter posts
                    // the refresh notification, which must see capturingShortcut=false.
                    AppState.capturingShortcut = false
                    AppState.captureLiveFlags = []
                    AppSettings.shortcut = newShortcut
                }
            }
        }
        return nil
    }

    switch type {
    case .keyDown:
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection(
            [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        )

        // Unlock shortcut takes priority.
        let sc = AppSettings.shortcut
        if keyCode == CGKeyCode(sc.keyCode) && flags == sc.flags {
            DispatchQueue.main.async {
                if sillyReady() {
                    NSApp.terminate(nil)
                } else {
                    handleKeyPressed(keyCode)
                }
            }
            return nil
        }

        // ⌘, opens settings (when not already open and not used as unlock).
        if keyCode == settingsShortcutKeyCode && flags == [.maskCommand] && !AppState.settingsOpen {
            DispatchQueue.main.async { settingsController.show() }
            return nil
        }

        // While settings is open, let keystrokes reach the settings window.
        if AppState.settingsOpen {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async { handleKeyPressed(keyCode) }
        return nil

    case .keyUp:
        if AppState.settingsOpen {
            return Unmanaged.passUnretained(event)
        }
        return nil

    case .flagsChanged:
        let newFlags = event.flags
        let pressedBits = newFlags.rawValue & ~lastFlags.rawValue
        lastFlags = newFlags
        if pressedBits != 0 {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            DispatchQueue.main.async { handleKeyPressed(keyCode) }
        }
        if AppState.settingsOpen {
            return Unmanaged.passUnretained(event)
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
    (1 << CGEventType.flagsChanged.rawValue) |
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.leftMouseDown.rawValue) |
    (1 << CGEventType.leftMouseUp.rawValue) |
    (1 << CGEventType.leftMouseDragged.rawValue) |
    (1 << CGEventType.rightMouseDown.rawValue) |
    (1 << CGEventType.rightMouseUp.rawValue) |
    (1 << CGEventType.rightMouseDragged.rawValue) |
    (1 << CGEventType.otherMouseDown.rawValue) |
    (1 << CGEventType.otherMouseUp.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue) |
    (1 << CGEventType.scrollWheel.rawValue)

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

// Cursor goes numb too.
CGDisplayHideCursor(CGMainDisplayID())

enum Design {
    static let backdropTint = NSColor(red: 0x32/255.0, green: 0x32/255.0, blue: 0x32/255.0, alpha: 0.80)
    static let white = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 1.0)
    static let dim = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 0.60)
    static let captionBottomInset: CGFloat = 72
    static let captionTopInset: CGFloat = 28
    static let captionSideInset: CGFloat = 28
    static let hintKeycapSide: CGFloat = 26
    static let hintKeycapSmallSide: CGFloat = 20
    static let hintKeycapRadius: CGFloat = 4
    static let hintFontSize: CGFloat = 13
    static let hintSmallFontSize: CGFloat = 11
}

func mono(_ size: CGFloat) -> NSFont {
    NSFont(name: "SFMono-Regular", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

func makeHintKeycap(_ symbol: String, side: CGFloat = Design.hintKeycapSide,
                    fontSize: CGFloat = Design.hintFontSize,
                    color: NSColor = Design.white) -> NSView {
    let cap = NSView()
    cap.wantsLayer = true
    cap.layer?.cornerRadius = Design.hintKeycapRadius
    cap.layer?.cornerCurve = .continuous
    cap.layer?.borderWidth = 1
    cap.layer?.borderColor = color.cgColor
    cap.layer?.backgroundColor = NSColor.clear.cgColor
    cap.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(labelWithString: symbol)
    label.font = mono(fontSize)
    label.textColor = color
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false
    label.translatesAutoresizingMaskIntoConstraints = false

    cap.addSubview(label)
    NSLayoutConstraint.activate([
        cap.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
        cap.heightAnchor.constraint(equalToConstant: side),
        label.centerXAnchor.constraint(equalTo: cap.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
        label.leadingAnchor.constraint(greaterThanOrEqualTo: cap.leadingAnchor, constant: 4),
        label.trailingAnchor.constraint(lessThanOrEqualTo: cap.trailingAnchor, constant: -4),
    ])
    return cap
}

func buildUnlockHint(symbols: [String]) -> NSView {
    let caps = NSStackView(views: symbols.map { makeHintKeycap($0) })
    caps.orientation = .horizontal
    caps.spacing = 2
    caps.alignment = .centerY

    let label = NSTextField(labelWithString: "TO UNLOCK")
    label.font = mono(Design.hintFontSize)
    label.textColor = Design.white
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false

    let row = NSStackView(views: [caps, label])
    row.orientation = .horizontal
    row.spacing = 10
    row.alignment = .centerY
    return row
}

func buildSillyHint() -> NSView {
    let total = KeyboardView.allKeyCodes.count
    let done = AppState.pressedKeys.intersection(KeyboardView.allKeyCodes).count
    let text = "MASH EVERY KEY · \(done)/\(total)"
    let label = NSTextField(labelWithString: text)
    label.font = mono(Design.hintFontSize)
    label.textColor = Design.white
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false
    return label
}

func buildSettingsHint() -> NSView {
    let caps = NSStackView(views: [
        makeHintKeycap("⌘", side: Design.hintKeycapSmallSide, fontSize: Design.hintSmallFontSize, color: Design.dim),
        makeHintKeycap(",", side: Design.hintKeycapSmallSide, fontSize: Design.hintSmallFontSize, color: Design.dim),
    ])
    caps.orientation = .horizontal
    caps.spacing = 2
    caps.alignment = .centerY

    let label = NSTextField(labelWithString: "SETTINGS")
    label.font = mono(Design.hintSmallFontSize)
    label.textColor = Design.dim
    label.alignment = .center
    label.isBezeled = false
    label.isEditable = false
    label.drawsBackground = false

    let row = NSStackView(views: [caps, label])
    row.orientation = .horizontal
    row.spacing = 8
    row.alignment = .centerY
    return row
}

final class OverlayController {
    var windows: [NSWindow] = []
    var bottomHintHosts: [NSView] = []
    var topHintHosts: [NSView] = []

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

            let keyboard = KeyboardView(targetWidth: screen.frame.width * 0.75)
            keyboardViews.append(keyboard)
            content.addSubview(keyboard)
            NSLayoutConstraint.activate([
                keyboard.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                keyboard.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])

            // Bottom hint host — rebuilt whenever settings/silly-progress changes.
            let bottomHost = NSView()
            bottomHost.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(bottomHost)
            NSLayoutConstraint.activate([
                bottomHost.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                bottomHost.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Design.captionBottomInset),
            ])
            bottomHintHosts.append(bottomHost)

            // Top-right settings hint.
            let topHost = NSView()
            topHost.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(topHost)
            NSLayoutConstraint.activate([
                topHost.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Design.captionSideInset),
                topHost.topAnchor.constraint(equalTo: content.topAnchor, constant: Design.captionTopInset),
            ])
            topHintHosts.append(topHost)

            window.contentView = content
            window.orderFrontRegardless()
            windows.append(window)
        }
        refreshHints()
        scheduleSettingsHintFade()
    }

    private func scheduleSettingsHintFade() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            for host in self.topHintHosts {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 1.0
                    host.animator().alphaValue = 0
                }
            }
        }
    }

    func refreshHints() {
        for host in bottomHintHosts {
            host.subviews.forEach { $0.removeFromSuperview() }
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 10
            stack.alignment = .centerX
            stack.translatesAutoresizingMaskIntoConstraints = false

            if AppSettings.sillyMode && !sillyReady() {
                stack.addArrangedSubview(buildSillyHint())
            }
            stack.addArrangedSubview(buildUnlockHint(symbols: AppSettings.shortcut.symbols))

            host.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                stack.topAnchor.constraint(equalTo: host.topAnchor),
                stack.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
        }

        for host in topHintHosts {
            if host.subviews.isEmpty {
                let hint = buildSettingsHint()
                hint.translatesAutoresizingMaskIntoConstraints = false
                host.addSubview(hint)
                NSLayoutConstraint.activate([
                    hint.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    hint.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                    hint.topAnchor.constraint(equalTo: host.topAnchor),
                    hint.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                ])
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

overlay = OverlayController()
overlay.show()

settingsController = SettingsController()

let nc = NotificationCenter.default
nc.addObserver(forName: .numbSettingsDidChange, object: nil, queue: .main) { _ in
    overlay.refreshHints()
}
nc.addObserver(forName: .numbSillyProgressDidChange, object: nil, queue: .main) { _ in
    overlay.refreshHints()
}

app.run()
