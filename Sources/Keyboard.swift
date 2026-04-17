import Cocoa

enum KB {
    // Sized from Figma node 2250:565 at 0.75× scale
    static let keyW: CGFloat = 53
    static let keyH: CGFloat = 52
    static let gapH: CGFloat = 14
    static let gapV: CGFloat = 12
    static let radius: CGFloat = 6
    static let capsReturn: CGFloat = 105
    static let shiftL: CGFloat = 138
    static let shiftR: CGFloat = 139
    static let cmdWide: CGFloat = 70
    static let flexSmall: CGFloat = 91   // esc, delete, tab
    static let spaceW: CGFloat = 325
    static let halfH: CGFloat = 25
    static let stackedGap: CGFloat = 2
    static let dotSize: CGFloat = 5
}

let keyBaseBg = NSColor(red: 0x0D/255.0, green: 0x1B/255.0, blue: 0x1E/255.0, alpha: 1.0)
let keyHotBg  = NSColor(red: 0xFF/255.0, green: 0xF5/255.0, blue: 0xF5/255.0, alpha: 1.0)
let keyShadow = NSColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 0.35)

let attackDuration: CFTimeInterval = 0.08
let decayDuration:  CFTimeInterval = 0.70

final class KeyView: NSView {
    let keyCode: CGKeyCode?
    private var pendingDecay: DispatchWorkItem?

    init(keyCode: CGKeyCode?, width: CGFloat, height: CGFloat) {
        self.keyCode = keyCode
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: height),
        ])
        layer?.cornerRadius = KB.radius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = keyBaseBg.cgColor
        layer?.shadowColor = keyShadow.cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowRadius = 1
        layer?.shadowOffset = CGSize(width: 0, height: -0.75)
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func pulse() {
        pendingDecay?.cancel()
        guard let layer = self.layer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(attackDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        layer.backgroundColor = keyHotBg.cgColor
        CATransaction.commit()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let layer = self.layer else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(decayDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            layer.backgroundColor = keyBaseBg.cgColor
            CATransaction.commit()
        }
        pendingDecay = work
        DispatchQueue.main.asyncAfter(deadline: .now() + attackDuration, execute: work)
    }

    func addIndicatorDot() {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.35).cgColor
        dot.layer?.cornerRadius = KB.dotSize / 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: KB.dotSize),
            dot.heightAnchor.constraint(equalToConstant: KB.dotSize),
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

final class KeyboardView: NSView {
    private var keyViews: [CGKeyCode: [KeyView]] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func makeKey(_ code: CGKeyCode?, w: CGFloat, h: CGFloat = KB.keyH) -> KeyView {
        let v = KeyView(keyCode: code, width: w, height: h)
        if let c = code {
            keyViews[c, default: []].append(v)
        }
        return v
    }

    private func hrow(_ views: [NSView], alignment: NSLayoutConstraint.Attribute = .centerY) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.spacing = KB.gapH
        s.alignment = alignment
        return s
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        let row1 = hrow([
            makeKey(53,  w: KB.flexSmall),          // esc
            makeKey(122, w: KB.keyW), makeKey(120, w: KB.keyW),
            makeKey(99,  w: KB.keyW), makeKey(118, w: KB.keyW),
            makeKey(96,  w: KB.keyW), makeKey(97,  w: KB.keyW),
            makeKey(98,  w: KB.keyW), makeKey(100, w: KB.keyW),
            makeKey(101, w: KB.keyW), makeKey(109, w: KB.keyW),
            makeKey(103, w: KB.keyW), makeKey(111, w: KB.keyW),
            makeKey(nil, w: KB.keyW),                // Touch ID placeholder
        ])

        let row2 = hrow([
            makeKey(50, w: KB.keyW), makeKey(18, w: KB.keyW),
            makeKey(19, w: KB.keyW), makeKey(20, w: KB.keyW),
            makeKey(21, w: KB.keyW), makeKey(23, w: KB.keyW),
            makeKey(22, w: KB.keyW), makeKey(26, w: KB.keyW),
            makeKey(28, w: KB.keyW), makeKey(25, w: KB.keyW),
            makeKey(29, w: KB.keyW), makeKey(27, w: KB.keyW),
            makeKey(24, w: KB.keyW),
            makeKey(51, w: KB.flexSmall),            // delete
        ])

        let row3 = hrow([
            makeKey(48, w: KB.flexSmall),            // tab
            makeKey(12, w: KB.keyW), makeKey(13, w: KB.keyW),
            makeKey(14, w: KB.keyW), makeKey(15, w: KB.keyW),
            makeKey(17, w: KB.keyW), makeKey(16, w: KB.keyW),
            makeKey(32, w: KB.keyW), makeKey(34, w: KB.keyW),
            makeKey(31, w: KB.keyW), makeKey(35, w: KB.keyW),
            makeKey(33, w: KB.keyW), makeKey(30, w: KB.keyW),
            makeKey(42, w: KB.keyW),
        ])

        let caps = makeKey(57, w: KB.capsReturn)
        caps.addIndicatorDot()
        let row4 = hrow([
            caps,
            makeKey(0, w: KB.keyW), makeKey(1, w: KB.keyW),
            makeKey(2, w: KB.keyW), makeKey(3, w: KB.keyW),
            makeKey(5, w: KB.keyW), makeKey(4, w: KB.keyW),
            makeKey(38, w: KB.keyW), makeKey(40, w: KB.keyW),
            makeKey(37, w: KB.keyW), makeKey(41, w: KB.keyW),
            makeKey(39, w: KB.keyW),
            makeKey(36, w: KB.capsReturn),
        ])

        let row5 = hrow([
            makeKey(56, w: KB.shiftL),
            makeKey(6, w: KB.keyW), makeKey(7, w: KB.keyW),
            makeKey(8, w: KB.keyW), makeKey(9, w: KB.keyW),
            makeKey(11, w: KB.keyW), makeKey(45, w: KB.keyW),
            makeKey(46, w: KB.keyW), makeKey(43, w: KB.keyW),
            makeKey(47, w: KB.keyW), makeKey(44, w: KB.keyW),
            makeKey(60, w: KB.shiftR),
        ])

        // Arrow cluster — half-height ← and → bottom-aligned, stacked ↑/↓ column in between
        let leftArrow  = makeKey(123, w: KB.keyW, h: KB.halfH)
        let rightArrow = makeKey(124, w: KB.keyW, h: KB.halfH)
        let upArrow    = makeKey(126, w: KB.keyW, h: KB.halfH)
        let downArrow  = makeKey(125, w: KB.keyW, h: KB.halfH)

        let stackedCol = NSStackView(views: [upArrow, downArrow])
        stackedCol.orientation = .vertical
        stackedCol.spacing = KB.stackedGap
        stackedCol.alignment = .centerX
        stackedCol.translatesAutoresizingMaskIntoConstraints = false

        let row6 = hrow([
            makeKey(63, w: KB.keyW), makeKey(59, w: KB.keyW),
            makeKey(58, w: KB.keyW), makeKey(55, w: KB.cmdWide),
            makeKey(49, w: KB.spaceW),
            makeKey(54, w: KB.cmdWide), makeKey(61, w: KB.keyW),
            leftArrow, stackedCol, rightArrow,
        ], alignment: .bottom)

        let vstack = NSStackView(views: [row1, row2, row3, row4, row5, row6])
        vstack.orientation = .vertical
        vstack.spacing = KB.gapV
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
