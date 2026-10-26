import AppKit

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
        let height = success ? 46 : max(76, textHeight + 48)
        super.init(frame: NSRect(x: 0, y: 0, width: success ? 174 : 300, height: height))
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.995, green: 0.98, blue: 0.94, alpha: 1).cgColor
        layer?.cornerRadius = 14

        let image = NSImageView(frame: NSRect(x: 11, y: success ? 11 : 14, width: 24, height: 24))
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
        _ = label(success ? "保存しました" : "保存できませんでした",
                  frame: NSRect(x: 45, y: success ? 13 : 15, width: success ? 116 : textWidth, height: 21),
                  font: .systemFont(ofSize: 13, weight: .medium), color: ink)
        if !success {
            _ = label(detail, frame: NSRect(x: 45, y: 39, width: textWidth, height: max(18, textHeight + 3)),
                      font: detailFont, color: muted)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
