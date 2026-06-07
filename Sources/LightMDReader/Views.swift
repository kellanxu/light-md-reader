import AppKit

final class ThemeAwareContentView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

final class MonogramIconView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor = .systemBlue {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 26, height: 26)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.integral.insetBy(dx: 0.5, dy: 0.5)
        fillColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        let drawRect = NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2 - 0.5,
            width: size.width,
            height: size.height
        )
        attributed.draw(in: drawRect)
    }
}

final class RoundedReaderView: NSView {
    private let cornerRadius: CGFloat = 14

    var fillColor: NSColor = .windowBackgroundColor {
        didSet {
            layer?.backgroundColor = fillColor.cgColor
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.38).cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = fillColor.cgColor
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.38).cgColor
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }
}
