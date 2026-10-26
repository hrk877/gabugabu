import AppKit

final class ToastCardView: NSView {
    override var isFlipped: Bool { true }

    init(detail: String, success: Bool, icon: NSImage?) {
        let ink = NSColor(srgbRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
        let muted = NSColor(srgbRed: 0.47, green: 0.45, blue: 0.41, alpha: 1)
        let orange = NSColor(srgbRed: 0.95, green: 0.42, blue: 0.25, alpha: 1)
        let detailFont = NSFont.systemFont(ofSize: 12)
        let textWidth: CGFloat = 232
        let textHeight = ceil((detail as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: detailFont]).height)
        let height = success ? 100 : max(100, textHeight + 69)
        super.init(frame: NSRect(x: 0, y: 0, width: 350, height: height))
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.995, green: 0.98, blue: 0.94, alpha: 1).cgColor
        layer?.cornerRadius = 22
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(srgbRed: 0.84, green: 0.78, blue: 0.68, alpha: 0.5).cgColor

        let image = NSImageView(frame: NSRect(x: 18, y: (height - 52) / 2, width: 52, height: 52))
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
        let brand = label("GABUGABU", frame: NSRect(x: 86, y: 16, width: 200, height: 15),
                          font: .systemFont(ofSize: 9, weight: .heavy), color: orange)
        brand.attributedStringValue = NSAttributedString(string: "GABUGABU", attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .heavy), .foregroundColor: orange, .kern: 1.4
        ])
        _ = label(success ? "保存しました" : "保存できませんでした",
                  frame: NSRect(x: 85, y: 35, width: 232, height: 24),
                  font: .systemFont(ofSize: 17, weight: .semibold), color: ink)
        let subtitle = label(detail, frame: NSRect(x: 86, y: 63, width: textWidth, height: max(18, textHeight + 3)),
                             font: detailFont, color: muted)
        if success {
            subtitle.maximumNumberOfLines = 1
            subtitle.lineBreakMode = .byTruncatingMiddle
            let check = NSImageView(frame: NSRect(x: 313, y: 20, width: 16, height: 16))
            check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "保存完了")
            check.contentTintColor = orange
            addSubview(check)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
