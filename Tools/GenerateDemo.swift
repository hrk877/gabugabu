import AppKit
import ImageIO
import UniformTypeIdentifiers

// A synthetic editorial animation, never a recording of personal content.
// Run: xcrun swift Tools/GenerateDemo.swift assets/demo.gif
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/demo.gif")
let paper = NSColor(srgbRed: 0.98, green: 0.96, blue: 0.90, alpha: 1)
let ink = NSColor(srgbRed: 0.19, green: 0.20, blue: 0.17, alpha: 1)
let orange = NSColor(srgbRed: 0.93, green: 0.35, blue: 0.16, alpha: 1)
let quiet = NSColor(srgbRed: 0.46, green: 0.45, blue: 0.39, alpha: 1)
let highlight = NSColor(srgbRed: 1, green: 0.84, blue: 0.40, alpha: 1)
let line = NSColor(srgbRed: 0.85, green: 0.82, blue: 0.74, alpha: 1)
func box(_ r: NSRect, _ fill: NSColor, _ radius: CGFloat = 0) {
    fill.setFill(); NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
}
func label(_ value: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
           _ size: CGFloat, _ color: NSColor = ink, _ weight: NSFont.Weight = .regular) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 7
    (value as NSString).draw(in: NSRect(x: x, y: y, width: w, height: h), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}
func stroke(_ points: [NSPoint], color: NSColor = ink, width: CGFloat = 3) {
    let p = NSBezierPath(); p.move(to: points[0]); points.dropFirst().forEach { p.line(to: $0) }
    p.lineWidth = width; p.lineCapStyle = .round; color.setStroke(); p.stroke()
}
func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
func ease(_ value: Double) -> Double { let t = clamp(value); return t * t * (3 - 2 * t) }

struct Bite {
    let source: String
    let title: String
    let before: String
    let selected: String
    let after: String
    let short: String
}
let bites = [
    Bite(source: "AIへのプロンプト", title: "送る前のひとことも。", before: "この企画のアイデアを、", selected: "いつもと違う角度から\n一緒に考えてほしい。", after: "", short: "企画のプロンプト"),
    Bite(source: "Webページの一節", title: "読んでいて、引っかかった言葉も。", before: "街の小さな店を訪ねて", selected: "余白があるから、\n会話が生まれる。", after: "記事の続きを読んでみる。", short: "記事で見つけた一節"),
    Bite(source: "作業中のメモ", title: "ふと浮かんだ、まだ途中の案も。", before: "次に試してみたいこと", selected: "捨てるはずの布で、\n小さなポーチをつくる。", after: "色は、まだ決めなくていい。", short: "思いついたアイデア"),
    Bite(source: "会話の中の文章", title: "誰かと話して、残したくなったら。", before: "さっきの打ち合わせで", selected: "完成させる前に、\n一度使ってもらおう。", after: "まずは小さく試してみる。", short: "会話で出たヒント"),
    Bite(source: "調べもののメモ", title: "調べものの、気になる部分だけ。", before: "つくり方の覚え書き", selected: "色を重ねる前に、\n一度しっかり乾かす。", after: "次の試作でやってみる。", short: "あとで使う覚え書き"),
    Bite(source: "自分の書きかけ", title: "まとまってなくても、そのまま。", before: "今日、考えていたこと", selected: "うまく言えないけど、\nこの感じは覚えておきたい。", after: "", short: "書きかけの考え")
]

func mouth(_ x: CGFloat, _ y: CGFloat, _ opening: Double, _ bounce: Double = 0) {
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.translateBy(x: x, y: y + CGFloat(bounce))
    box(NSRect(x: -58, y: -58, width: 116, height: 116), orange, 36)
    // A left-facing hungry mouth; the paper visibly travels into the opening.
    let gap = CGFloat(9 + opening * 32)
    let p = NSBezierPath()
    p.move(to: NSPoint(x: -60, y: -gap))
    p.curve(to: NSPoint(x: 34, y: 0), controlPoint1: NSPoint(x: 10, y: -gap - 5), controlPoint2: NSPoint(x: 38, y: -gap))
    p.curve(to: NSPoint(x: -60, y: gap), controlPoint1: NSPoint(x: 38, y: gap), controlPoint2: NSPoint(x: 10, y: gap + 5))
    p.close(); ink.setFill(); p.fill()
    box(NSRect(x: -25, y: -gap + 1, width: 14, height: 11), paper, 2)
    box(NSRect(x: -2, y: gap - 11, width: 14, height: 11), paper, 2)
    box(NSRect(x: 19, y: -44, width: 8, height: 8), ink, 4)
    context.restoreGState()
}

let intro = 12
let cycle = 26
let ending = 30
let frames = intro + bites.count * cycle + ending
let gif = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let previews = output.deletingLastPathComponent().appendingPathComponent("../build/demo-preview", isDirectory: true).standardizedFileURL
try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
for frame in 0..<frames {
    let image: CGImage = autoreleasepool {
        let cg = CGContext(data: nil, width: 1200, height: 720, bitsPerComponent: 8, bytesPerRow: 4800,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        cg.translateBy(x: 0, y: 720); cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }
        box(NSRect(x: 0, y: 0, width: 1200, height: 720), paper)
        label("GABUGABU", 48, 30, 700, 50, 32, ink, .heavy)
        label("言葉を、ガブガブ。", 870, 41, 300, 35, 19, quiet, .medium)
        let elapsed = max(0, frame - intro)
        let index = min(bites.count - 1, elapsed / cycle)
        let t = frame < intro ? 0 : Double(elapsed % cycle) / Double(cycle)
        let done = frame >= intro + bites.count * cycle
        let bite = bites[index]
        let count = done ? bites.count : min(bites.count, index + (t >= 0.81 ? 1 : 0))
        label(done ? "ぜんぶ、あとで使う材料に。" : "あ、これも。ガブッ。", 48, 102, 1110, 80, 53, ink, .bold)
        label("プロンプトも、Webの一節も。あとでAIに渡すメモに。", 50, 185, 1100, 42, 24, quiet)

        // The source is an everyday text surface, not a fictional app dashboard.
        box(NSRect(x: 48, y: 255, width: 530, height: 316), .white, 12)
        box(NSRect(x: 48, y: 255, width: 6, height: 316), highlight, 3)
        label(bite.source, 77, 276, 450, 30, 17, quiet, .semibold)
        label(bite.before, 77, 328, 470, 44, 23)
        let selected = t >= 0.15 || done
        if selected { box(NSRect(x: 72, y: 379, width: 464, height: 95), highlight, 3) }
        label(bite.selected, 82, 383, 450, 100, 27, ink, .semibold)
        label(bite.after, 77, 502, 460, 42, 20, quiet)

        // A paper strip leaves the selection, shrinks into the mouth, then becomes a saved row.
        if !done && t >= 0.38 && t < 0.69 {
            let travel = ease((t - 0.38) / 0.31)
            cg.saveGState()
            cg.translateBy(x: 326 + 368 * travel, y: 421 - 30 * sin(travel * .pi))
            cg.rotate(by: CGFloat(-0.08 + 0.16 * travel))
            let scale = 1 - 0.92 * travel
            cg.scaleBy(x: scale, y: scale)
            box(NSRect(x: -208, y: -43, width: 416, height: 86), highlight, 4)
            label(bite.selected.replacingOccurrences(of: "\n", with: " "), -190, -21, 390, 60, 21, ink, .medium)
            cg.restoreGState()
        }
        let chewing = !done && t >= 0.6 && t < 0.85
        let opening = done ? 0.12 : (t < 0.38 ? 0.35 : (chewing ? abs(sin((t - 0.6) * 32)) : 0.95))
        mouth(698, 424, opening, chewing ? sin(t * 55) * 3 : 0)
        if chewing {
            label("ガブッ", 638, 298, 150, 45, 28, orange, .heavy)
            stroke([NSPoint(x: 768, y: 396), NSPoint(x: 785, y: 389)], color: orange)
            stroke([NSPoint(x: 771, y: 425), NSPoint(x: 790, y: 427)], color: orange)
        } else { label(done ? "満腹。" : "ひとくち保存", 634, 510, 170, 40, 19, quiet, .medium) }

        // Rows are a visual metaphor for daily Markdown, not an app UI or user tagging step.
        box(NSRect(x: 830, y: 258, width: 320, height: 330), line, 10)
        box(NSRect(x: 830, y: 246, width: 155, height: 32), line, 6)
        label("GABUGABU Archive", 850, 279, 280, 35, 21, ink, .bold)
        for row in 0..<count {
            let yy = CGFloat(322 + row * 40)
            box(NSRect(x: 848, y: yy, width: 284, height: 34), paper, 3)
            label("✓", 859, yy + 5, 27, 28, 16, orange, .bold)
            label(bites[row].short, 886, yy + 5, 240, 28, 16, ink, .medium)
        }
        if count == 0 { label("選んだ言葉が、\nここにたまっていく。", 858, 364, 260, 110, 23, quiet) }
        label("\(count) 件の言葉  /  ローカルのMarkdown", 846, 598, 320, 32, 15, quiet)

        box(NSRect(x: 49, y: 603, width: 166, height: 61), (!done && t >= 0.3 && t < 0.6) ? orange : ink, 10)
        label("⌘ ⌥ S", 72, 610, 145, 48, 31, paper, .semibold)
        label(done ? "Macの中にためて、あとでAIに読ませよう。" : bite.title, 237, 617, 900, 42, 24, ink, .medium)
        label("操作イメージ・架空の文章を使用｜保存対象は取得できる文章。対応範囲はアプリによって異なります。", 49, 686, 1110, 24, 13, quiet)
        return cg.makeImage()!
    }
    CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
    if [0, 26, 31, 36, 60, 110, frames - 1].contains(frame) {
        let png = CGImageDestinationCreateWithURL(previews.appendingPathComponent("frame-\(frame).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(png, image, nil); precondition(CGImageDestinationFinalize(png))
    }
}
precondition(CGImageDestinationFinalize(gif))
print("Generated \(output.path): \(frames) frames, \(Double(frames) / 10) seconds")
