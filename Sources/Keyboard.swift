import Cocoa

enum KeyStyle {
    case regular
    case modifier
    case space
}

struct KeySpec {
    let keyCode: CGKeyCode?
    let label: String
    let widthUnits: CGFloat
    let style: KeyStyle
}

func key(_ code: CGKeyCode?, _ label: String, width: CGFloat = 1, style: KeyStyle = .regular) -> KeySpec {
    KeySpec(keyCode: code, label: label, widthUnits: width, style: style)
}

let keyboardRows: [[KeySpec]] = [
    [
        key(53, "esc", style: .modifier),
        key(122, "F1"), key(120, "F2"), key(99, "F3"), key(118, "F4"),
        key(96, "F5"), key(97, "F6"), key(98, "F7"), key(100, "F8"),
        key(101, "F9"), key(109, "F10"), key(103, "F11"), key(111, "F12"),
    ],
    [
        key(50, "`"), key(18, "1"), key(19, "2"), key(20, "3"), key(21, "4"),
        key(23, "5"), key(22, "6"), key(26, "7"), key(28, "8"), key(25, "9"),
        key(29, "0"), key(27, "−"), key(24, "="),
        key(51, "delete", width: 1.5, style: .modifier),
    ],
    [
        key(48, "tab", width: 1.5, style: .modifier),
        key(12, "Q"), key(13, "W"), key(14, "E"), key(15, "R"), key(17, "T"),
        key(16, "Y"), key(32, "U"), key(34, "I"), key(31, "O"), key(35, "P"),
        key(33, "["), key(30, "]"), key(42, "\\"),
    ],
    [
        key(57, "caps", width: 1.75, style: .modifier),
        key(0, "A"), key(1, "S"), key(2, "D"), key(3, "F"), key(5, "G"),
        key(4, "H"), key(38, "J"), key(40, "K"), key(37, "L"),
        key(41, ";"), key(39, "'"),
        key(36, "return", width: 1.75, style: .modifier),
    ],
    [
        key(56, "shift", width: 2.25, style: .modifier),
        key(6, "Z"), key(7, "X"), key(8, "C"), key(9, "V"), key(11, "B"),
        key(45, "N"), key(46, "M"),
        key(43, ","), key(47, "."), key(44, "/"),
        key(60, "shift", width: 2.25, style: .modifier),
    ],
    [
        key(63, "fn", style: .modifier),
        key(59, "⌃", style: .modifier),
        key(58, "⌥", style: .modifier),
        key(55, "⌘", width: 1.25, style: .modifier),
        key(49, "", width: 5, style: .space),
        key(54, "⌘", width: 1.25, style: .modifier),
        key(61, "⌥", style: .modifier),
        key(123, "←"), key(125, "↓"), key(126, "↑"), key(124, "→"),
    ],
]

// Colors
let keyBaseBg    = NSColor(red: 0x0D/255.0, green: 0x1B/255.0, blue: 0x1E/255.0, alpha: 1.0)
let keyBaseBorder = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.06)
let keyBaseText  = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 0.55)
let keyHotBg     = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 1.0)
let keyHotText   = NSColor(red: 0x0D/255.0, green: 0x1B/255.0, blue: 0x1E/255.0, alpha: 1.0)

let attackDuration: CFTimeInterval = 0.08  // quick ease-in
let decayDuration:  CFTimeInterval = 0.70  // slow ease-out

final class KeyView: NSView {
    let spec: KeySpec
    private let textLayer = CATextLayer()
    private let font: NSFont
    private var pendingDecay: DispatchWorkItem?

    init(spec: KeySpec) {
        self.spec = spec
        self.font = Self.font(for: spec)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        layer?.backgroundColor = keyBaseBg.cgColor
        layer?.borderColor = keyBaseBorder.cgColor

        textLayer.string = spec.label
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        textLayer.foregroundColor = keyBaseText.cgColor
        textLayer.alignmentMode = .center
        textLayer.truncationMode = .end
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer?.addSublayer(textLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let lineHeight = font.pointSize * 1.25
        textLayer.frame = CGRect(
            x: 0,
            y: (bounds.height - lineHeight) / 2,
            width: bounds.width,
            height: lineHeight
        )
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        textLayer.contentsScale = window?.backingScaleFactor ?? 2.0
    }

    private static func font(for spec: KeySpec) -> NSFont {
        let size: CGFloat
        switch spec.style {
        case .regular: size = 14
        case .modifier: size = spec.label.count > 2 ? 10 : 13
        case .space: size = 10
        }
        return NSFont(name: "SFMono-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func pulse() {
        pendingDecay?.cancel()
        guard let layer = self.layer else { return }

        // Quick ease-in → white
        CATransaction.begin()
        CATransaction.setAnimationDuration(attackDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        layer.backgroundColor = keyHotBg.cgColor
        layer.borderColor = keyHotBg.cgColor
        textLayer.foregroundColor = keyHotText.cgColor
        CATransaction.commit()

        // Slow ease-out → back to Night
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let layer = self.layer else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(decayDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            layer.backgroundColor = keyBaseBg.cgColor
            layer.borderColor = keyBaseBorder.cgColor
            self.textLayer.foregroundColor = keyBaseText.cgColor
            CATransaction.commit()
        }
        pendingDecay = work
        DispatchQueue.main.asyncAfter(deadline: .now() + attackDuration, execute: work)
    }
}

final class KeyboardView: NSView {
    private var keyViews: [CGKeyCode: [KeyView]] = [:]
    private let unit: CGFloat = 40
    private let gap: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        let rowStacks: [NSStackView] = keyboardRows.map { row in
            let views: [NSView] = row.map { spec in
                let kv = KeyView(spec: spec)
                let w = spec.widthUnits * unit + (spec.widthUnits - 1) * gap
                kv.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    kv.widthAnchor.constraint(equalToConstant: w),
                    kv.heightAnchor.constraint(equalToConstant: unit),
                ])
                if let code = spec.keyCode {
                    keyViews[code, default: []].append(kv)
                }
                return kv
            }
            let stack = NSStackView(views: views)
            stack.orientation = .horizontal
            stack.spacing = gap
            stack.alignment = .centerY
            stack.distribution = .fill
            return stack
        }

        let vstack = NSStackView(views: rowStacks)
        vstack.orientation = .vertical
        vstack.spacing = gap
        vstack.alignment = .centerX
        vstack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.leadingAnchor.constraint(equalTo: leadingAnchor),
            vstack.trailingAnchor.constraint(equalTo: trailingAnchor),
            vstack.topAnchor.constraint(equalTo: topAnchor),
            vstack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func pulse(_ keyCode: CGKeyCode) {
        keyViews[keyCode]?.forEach { $0.pulse() }
    }
}
