import AppKit
import CoreText

final class ToastCardView: NSView {
    override var isFlipped: Bool { true }

    init(detail: String, success: Bool, icon: NSImage?) {
        let ink = NSColor(srgbRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
        let muted = NSColor(srgbRed: 0.47, green: 0.45, blue: 0.41, alpha: 1)
        let detailFont = NSFont.systemFont(ofSize: 12)
        let textWidth: CGFloat = 238
        let textHeight = ceil((detail as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: detailFont]).height)
        let height = success ? 23 : max(76, textHeight + 48)
        super.init(frame: NSRect(x: 0, y: 0, width: success ? 95 : 300, height: height))
        wantsLayer = true
        let yellow = NSColor(srgbRed: 249.0 / 255, green: 199.0 / 255, blue: 13.0 / 255, alpha: 1)
        layer?.backgroundColor = (success ? yellow : NSColor(srgbRed: 0.995, green: 0.98, blue: 0.94, alpha: 1)).cgColor
        layer?.cornerRadius = success ? 11.5 : 14
        if success {
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        }

        if success {
            let content = ToastSuccessContentView(frame: bounds)
            content.setAccessibilityElement(true)
            content.setAccessibilityRole(.staticText)
            content.setAccessibilityLabel("Saved")
            addSubview(content)
            return
        }
        let image = NSImageView(frame: NSRect(x: 11, y: 14, width: 24, height: 24))
        image.image = icon
        image.imageScaling = .scaleProportionallyUpOrDown
        image.setAccessibilityLabel("GABUGABU")
        addSubview(image)

        func label(_ value: String, frame: NSRect, font: NSFont, color: NSColor) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: value)
            field.font = font; field.textColor = color; field.frame = frame
            field.maximumNumberOfLines = 0
            addSubview(field)
            return field
        }
        _ = label("保存できませんでした", frame: NSRect(x: 45, y: 15, width: textWidth, height: 21),
                  font: .systemFont(ofSize: 13, weight: .medium), color: ink)
        _ = label(detail, frame: NSRect(x: 45, y: 39, width: textWidth, height: max(18, textHeight + 3)),
                  font: detailFont, color: muted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// Center visible glyph/path bounds, rather than their unequal layout boxes.
private final class ToastSuccessContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let ink = NSColor(srgbRed: 23.0 / 255, green: 27.0 / 255, blue: 37.0 / 255, alpha: 1)
        let text = NSAttributedString(string: "Saved", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .light),
            .foregroundColor: ink, .kern: 0.15
        ])
        let line = CTLineCreateWithAttributedString(text)
        // Fill glyph outlines like the logo; CTLineDraw applies separate font hinting.
        let textPath = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
            for index in 0..<count {
                var placement = CGAffineTransform(translationX: positions[index].x, y: positions[index].y)
                if let glyphPath = CTFontCreatePathForGlyph(font, glyphs[index], &placement) { textPath.addPath(glyphPath) }
            }
        }
        let textInk = textPath.boundingBoxOfPath

        let mark = NSBezierPath()
        let center = NSPoint(x: 0.4, y: 0.5)
        mark.move(to: center)
        mark.appendArc(withCenter: center, radius: 0.38, startAngle: 45, endAngle: 315, clockwise: false)
        mark.close()
        for (offset, length) in [(0.32, 0.24), (0.48, 0.17), (0.64, 0.24)] {
            mark.append(NSBezierPath(roundedRect: NSRect(x: 0.98 - length, y: offset, width: length, height: 0.065),
                                     xRadius: 0.0325, yRadius: 0.0325))
        }
        let markInk = mark.bounds
        // Both outlines share these exact top/bottom edges, on whole device pixels
        // at standard and Retina scale, with no independent baseline adjustment.
        let visibleHeight: CGFloat = 9
        let scale = visibleHeight / markInk.height
        let textScale = visibleHeight / textInk.height
        let markWidth = markInk.width * scale
        let gap: CGFloat = 6
        let groupWidth = markWidth + gap + textInk.width * textScale
        let left = bounds.midX - groupWidth / 2
        let bottom = bounds.midY - visibleHeight / 2

        context.saveGState()
        context.translateBy(x: left, y: bottom)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -markInk.minX, y: -markInk.minY)
        ink.setFill()
        mark.fill()
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: left + markWidth + gap, y: bottom)
        context.scaleBy(x: textScale, y: textScale)
        context.translateBy(x: -textInk.minX, y: -textInk.minY)
        context.setFillColor(ink.cgColor)
        context.addPath(textPath)
        context.fillPath()
        context.restoreGState()
    }
}
