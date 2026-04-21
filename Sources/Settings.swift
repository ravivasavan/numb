import Cocoa

extension Notification.Name {
    static let numbSettingsDidChange = Notification.Name("numbSettingsDidChange")
    static let numbSillyProgressDidChange = Notification.Name("numbSillyProgressDidChange")
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var flagsRaw: UInt64

    var flags: CGEventFlags {
        CGEventFlags(rawValue: flagsRaw)
            .intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
    }

    var symbols: [String] {
        var out: [String] = []
        let f = flags
        if f.contains(.maskControl)   { out.append("⌃") }
        if f.contains(.maskAlternate) { out.append("⌥") }
        if f.contains(.maskShift)     { out.append("⇧") }
        if f.contains(.maskCommand)   { out.append("⌘") }
        out.append(KeySymbols.symbol(for: CGKeyCode(keyCode)))
        return out
    }

    static let `default` = Shortcut(
        keyCode: 40, // K
        flagsRaw: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
    )
}

enum AppSettings {
    private static let shortcutKey = "numb.shortcut"
    private static let sillyKey = "numb.sillyMode"

    private static var _shortcut: Shortcut = loadShortcut()
    static var shortcut: Shortcut {
        get { _shortcut }
        set {
            _shortcut = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: shortcutKey)
            }
            NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
        }
    }

    private static var _sillyMode: Bool = UserDefaults.standard.bool(forKey: sillyKey)
    static var sillyMode: Bool {
        get { _sillyMode }
        set {
            _sillyMode = newValue
            UserDefaults.standard.set(newValue, forKey: sillyKey)
            NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
        }
    }

    private static func loadShortcut() -> Shortcut {
        if let data = UserDefaults.standard.data(forKey: shortcutKey),
           let s = try? JSONDecoder().decode(Shortcut.self, from: data) {
            return s
        }
        return .default
    }
}

enum AppState {
    static var settingsOpen = false
    static var capturingShortcut = false
    static var captureLiveFlags: CGEventFlags = []
    static var pressedKeys: Set<CGKeyCode> = []
}

enum KeySymbols {
    static func symbol(for code: CGKeyCode) -> String {
        map[code] ?? "#\(code)"
    }

    static let map: [CGKeyCode: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        50: "`",
        48: "⇥", 49: "␣", 51: "⌫", 53: "⎋", 36: "⏎",
        56: "⇧", 57: "⇪", 58: "⌥", 59: "⌃", 54: "⌘", 55: "⌘", 60: "⇧", 61: "⌥", 62: "⌃", 63: "fn",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

// Keycode for `,` — used as the fixed settings shortcut (⌘,)
let settingsShortcutKeyCode: CGKeyCode = 43

final class SettingsController: NSWindowController, NSWindowDelegate {
    private var shortcutButton: NSButton!
    private var sillySwitch: NSSwitch!

    init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Numb Settings"
        w.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        w.isReleasedWhenClosed = false
        w.hidesOnDeactivate = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.center()
        super.init(window: w)
        w.delegate = self
        buildContent()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: .numbSettingsDidChange, object: nil
        )
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() {
        guard let window = self.window else { return }
        let content = NSView()

        let shortcutLabel = NSTextField(labelWithString: "Unlock shortcut")
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        shortcutButton = NSButton(title: "", target: self, action: #selector(startCapture))
        shortcutButton.bezelStyle = .rounded
        shortcutButton.setButtonType(.momentaryPushIn)

        let shortcutRow = NSStackView(views: [shortcutLabel, shortcutButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.spacing = 12
        shortcutRow.alignment = .centerY

        sillySwitch = NSSwitch()
        sillySwitch.target = self
        sillySwitch.action = #selector(toggleSilly)
        let sillyLabel = NSTextField(labelWithString: "Silly mode — mash every key before you can unlock")
        sillyLabel.font = NSFont.systemFont(ofSize: 13)
        let sillyRow = NSStackView(views: [sillySwitch, sillyLabel])
        sillyRow.orientation = .horizontal
        sillyRow.spacing = 10
        sillyRow.alignment = .centerY

        let done = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        let doneRow = NSStackView(views: [NSView(), done])
        doneRow.orientation = .horizontal
        doneRow.distribution = .fill

        let v = NSStackView(views: [shortcutRow, sillyRow, NSView(), doneRow])
        v.orientation = .vertical
        v.spacing = 14
        v.alignment = .leading
        v.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        v.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            v.topAnchor.constraint(equalTo: content.topAnchor),
            v.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            doneRow.widthAnchor.constraint(equalTo: v.widthAnchor, constant: -48),
        ])

        window.contentView = content
    }

    @objc private func refresh() {
        let title: String
        if AppState.capturingShortcut {
            let f = AppState.captureLiveFlags
            var parts: [String] = []
            if f.contains(.maskControl)   { parts.append("⌃") }
            if f.contains(.maskAlternate) { parts.append("⌥") }
            if f.contains(.maskShift)     { parts.append("⇧") }
            if f.contains(.maskCommand)   { parts.append("⌘") }
            if parts.isEmpty {
                title = "Press shortcut… (Esc to cancel)"
            } else {
                title = parts.joined(separator: " ") + " …"
            }
        } else {
            title = AppSettings.shortcut.symbols.joined(separator: " ")
        }
        shortcutButton.title = "  \(title)  "
        sillySwitch.state = AppSettings.sillyMode ? .on : .off
    }

    @objc private func startCapture() {
        AppState.capturingShortcut = true
        AppState.captureLiveFlags = []
        NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
    }

    @objc private func toggleSilly() {
        AppSettings.sillyMode = (sillySwitch.state == .on)
    }

    @objc private func doneTapped() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        AppState.settingsOpen = false
        AppState.capturingShortcut = false
        AppState.captureLiveFlags = []
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayHideCursor(CGMainDisplayID())
        NotificationCenter.default.post(name: .numbSettingsDidChange, object: nil)
    }

    func show() {
        AppState.settingsOpen = true
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
