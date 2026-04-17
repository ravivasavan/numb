import Cocoa

// Figma node 2250:565 native dimensions (1280pt-wide keyboard).
// KeyboardView scales all of these by `scale` at build time.
enum KBBase {
    static let designWidth: CGFloat = 1280
    static let keyW: CGFloat       = 71.058
    static let keyH: CGFloat       = 70.102
    static let gapH: CGFloat       = 18.163
    static let gapV: CGFloat       = 16
    static let radius: CGFloat     = 7.647
    static let capsReturn: CGFloat = 140
    static let shiftL: CGFloat     = 184.018
    static let shiftR: CGFloat     = 185.133
    static let cmdWide: CGFloat    = 92.726
    static let flexSmall: CGFloat  = 121    // esc, delete, tab
    static let spaceW: CGFloat     = 434
    static let halfH: CGFloat      = 33.617
    static let stackedGap: CGFloat = 2.5
}

let keyBaseBg = NSColor(red: 0x0D/255.0, green: 0x1B/255.0, blue: 0x1E/255.0, alpha: 1.0)
let keyShadow = NSColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 0.35)

// Random-pick palette for the "mash" flash
let hotColors: [NSColor] = [
    NSColor(srgbRed: 0xE6/255.0, green: 0x39/255.0, blue: 0x46/255.0, alpha: 1),  // crimson
    NSColor(srgbRed: 0xF3/255.0, green: 0x72/255.0, blue: 0x2C/255.0, alpha: 1),  // orange
    NSColor(srgbRed: 0xF8/255.0, green: 0x96/255.0, blue: 0x1E/255.0, alpha: 1),  // amber
    NSColor(srgbRed: 0xF9/255.0, green: 0xC7/255.0, blue: 0x4F/255.0, alpha: 1),  // marigold
    NSColor(srgbRed: 0xFF/255.0, green: 0xD6/255.0, blue: 0x0A/255.0, alpha: 1),  // sun
    NSColor(srgbRed: 0xD4/255.0, green: 0xE1/255.0, blue: 0x57/255.0, alpha: 1),  // chartreuse
    NSColor(srgbRed: 0x90/255.0, green: 0xBE/255.0, blue: 0x6D/255.0, alpha: 1),  // leaf
    NSColor(srgbRed: 0x52/255.0, green: 0xB7/255.0, blue: 0x88/255.0, alpha: 1),  // mint
    NSColor(srgbRed: 0x2A/255.0, green: 0x9D/255.0, blue: 0x8F/255.0, alpha: 1),  // teal
    NSColor(srgbRed: 0x43/255.0, green: 0xAA/255.0, blue: 0x8B/255.0, alpha: 1),  // jade
    NSColor(srgbRed: 0x4C/255.0, green: 0xC9/255.0, blue: 0xF0/255.0, alpha: 1),  // sky
    NSColor(srgbRed: 0x48/255.0, green: 0x95/255.0, blue: 0xEF/255.0, alpha: 1),  // azure
    NSColor(srgbRed: 0x43/255.0, green: 0x61/255.0, blue: 0xEE/255.0, alpha: 1),  // cobalt
    NSColor(srgbRed: 0x3A/255.0, green: 0x0C/255.0, blue: 0xA3/255.0, alpha: 1),  // indigo
    NSColor(srgbRed: 0x5E/255.0, green: 0x48/255.0, blue: 0xE8/255.0, alpha: 1),  // violet
    NSColor(srgbRed: 0x72/255.0, green: 0x09/255.0, blue: 0xB7/255.0, alpha: 1),  // purple
    NSColor(srgbRed: 0x9D/255.0, green: 0x4E/255.0, blue: 0xDD/255.0, alpha: 1),  // orchid
    NSColor(srgbRed: 0xB5/255.0, green: 0x17/255.0, blue: 0x9E/255.0, alpha: 1),  // magenta
    NSColor(srgbRed: 0xE5/255.0, green: 0x38/255.0, blue: 0x3B/255.0, alpha: 1),  // red
    NSColor(srgbRed: 0xF7/255.0, green: 0x25/255.0, blue: 0x85/255.0, alpha: 1),  // pink
    NSColor(srgbRed: 0xFF/255.0, green: 0x5D/255.0, blue: 0x8F/255.0, alpha: 1),  // rose
    NSColor(srgbRed: 0xFF/255.0, green: 0x8F/255.0, blue: 0xA3/255.0, alpha: 1),  // coral
    NSColor(srgbRed: 0xFF/255.0, green: 0xB4/255.0, blue: 0xA2/255.0, alpha: 1),  // peach
    NSColor(srgbRed: 0xE9/255.0, green: 0xC4/255.0, blue: 0x6A/255.0, alpha: 1),  // sand
]

let attackDuration: CFTimeInterval = 0.08
let decayDuration:  CFTimeInterval = 2.10  // slow cascade

final class KeyView: NSView {
    let keyCode: CGKeyCode?
    private var pendingDecay: DispatchWorkItem?

    init(keyCode: CGKeyCode?, width: CGFloat, height: CGFloat, radius: CGFloat) {
        self.keyCode = keyCode
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: height),
        ])
        layer?.cornerRadius = radius
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

        let hotBg = hotColors.randomElement() ?? NSColor.white

        CATransaction.begin()
        CATransaction.setAnimationDuration(attackDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        layer.backgroundColor = hotBg.cgColor
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
}

final class KeyboardView: NSView {
    private var keyViews: [CGKeyCode: [KeyView]] = [:]
    private let scale: CGFloat

    init(targetWidth: CGFloat) {
        self.scale = targetWidth / KBBase.designWidth
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func s(_ figma: CGFloat) -> CGFloat { figma * scale }

    private func makeKey(_ code: CGKeyCode?, w figW: CGFloat, h figH: CGFloat = KBBase.keyH) -> KeyView {
        let v = KeyView(keyCode: code, width: s(figW), height: s(figH), radius: s(KBBase.radius))
        if let c = code {
            keyViews[c, default: []].append(v)
        }
        return v
    }

    private func hrow(_ views: [NSView], alignment: NSLayoutConstraint.Attribute = .centerY) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = s(KBBase.gapH)
        stack.alignment = alignment
        return stack
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        let row1 = hrow([
            makeKey(53,  w: KBBase.flexSmall),
            makeKey(122, w: KBBase.keyW), makeKey(120, w: KBBase.keyW),
            makeKey(99,  w: KBBase.keyW), makeKey(118, w: KBBase.keyW),
            makeKey(96,  w: KBBase.keyW), makeKey(97,  w: KBBase.keyW),
            makeKey(98,  w: KBBase.keyW), makeKey(100, w: KBBase.keyW),
            makeKey(101, w: KBBase.keyW), makeKey(109, w: KBBase.keyW),
            makeKey(103, w: KBBase.keyW), makeKey(111, w: KBBase.keyW),
            makeKey(nil, w: KBBase.keyW),
        ])

        let row2 = hrow([
            makeKey(50, w: KBBase.keyW), makeKey(18, w: KBBase.keyW),
            makeKey(19, w: KBBase.keyW), makeKey(20, w: KBBase.keyW),
            makeKey(21, w: KBBase.keyW), makeKey(23, w: KBBase.keyW),
            makeKey(22, w: KBBase.keyW), makeKey(26, w: KBBase.keyW),
            makeKey(28, w: KBBase.keyW), makeKey(25, w: KBBase.keyW),
            makeKey(29, w: KBBase.keyW), makeKey(27, w: KBBase.keyW),
            makeKey(24, w: KBBase.keyW),
            makeKey(51, w: KBBase.flexSmall),
        ])

        let row3 = hrow([
            makeKey(48, w: KBBase.flexSmall),
            makeKey(12, w: KBBase.keyW), makeKey(13, w: KBBase.keyW),
            makeKey(14, w: KBBase.keyW), makeKey(15, w: KBBase.keyW),
            makeKey(17, w: KBBase.keyW), makeKey(16, w: KBBase.keyW),
            makeKey(32, w: KBBase.keyW), makeKey(34, w: KBBase.keyW),
            makeKey(31, w: KBBase.keyW), makeKey(35, w: KBBase.keyW),
            makeKey(33, w: KBBase.keyW), makeKey(30, w: KBBase.keyW),
            makeKey(42, w: KBBase.keyW),
        ])

        let row4 = hrow([
            makeKey(57, w: KBBase.capsReturn),
            makeKey(0, w: KBBase.keyW), makeKey(1, w: KBBase.keyW),
            makeKey(2, w: KBBase.keyW), makeKey(3, w: KBBase.keyW),
            makeKey(5, w: KBBase.keyW), makeKey(4, w: KBBase.keyW),
            makeKey(38, w: KBBase.keyW), makeKey(40, w: KBBase.keyW),
            makeKey(37, w: KBBase.keyW), makeKey(41, w: KBBase.keyW),
            makeKey(39, w: KBBase.keyW),
            makeKey(36, w: KBBase.capsReturn),
        ])

        let row5 = hrow([
            makeKey(56, w: KBBase.shiftL),
            makeKey(6, w: KBBase.keyW), makeKey(7, w: KBBase.keyW),
            makeKey(8, w: KBBase.keyW), makeKey(9, w: KBBase.keyW),
            makeKey(11, w: KBBase.keyW), makeKey(45, w: KBBase.keyW),
            makeKey(46, w: KBBase.keyW), makeKey(43, w: KBBase.keyW),
            makeKey(47, w: KBBase.keyW), makeKey(44, w: KBBase.keyW),
            makeKey(60, w: KBBase.shiftR),
        ])

        let leftArrow  = makeKey(123, w: KBBase.keyW, h: KBBase.halfH)
        let rightArrow = makeKey(124, w: KBBase.keyW, h: KBBase.halfH)
        let upArrow    = makeKey(126, w: KBBase.keyW, h: KBBase.halfH)
        let downArrow  = makeKey(125, w: KBBase.keyW, h: KBBase.halfH)

        let stackedCol = NSStackView(views: [upArrow, downArrow])
        stackedCol.orientation = .vertical
        stackedCol.spacing = s(KBBase.stackedGap)
        stackedCol.alignment = .centerX
        stackedCol.translatesAutoresizingMaskIntoConstraints = false

        let row6 = hrow([
            makeKey(63, w: KBBase.keyW), makeKey(59, w: KBBase.keyW),
            makeKey(58, w: KBBase.keyW), makeKey(55, w: KBBase.cmdWide),
            makeKey(49, w: KBBase.spaceW),
            makeKey(54, w: KBBase.cmdWide), makeKey(61, w: KBBase.keyW),
            leftArrow, stackedCol, rightArrow,
        ], alignment: .bottom)

        let vstack = NSStackView(views: [row1, row2, row3, row4, row5, row6])
        vstack.orientation = .vertical
        vstack.spacing = s(KBBase.gapV)
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
