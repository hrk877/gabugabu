import AppKit

func require(_ condition: Bool, _ message: String) {
    if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
// A private named pasteboard: never inspect or modify the user's general clipboard.
let pasteboard = NSPasteboard.withUniqueName()
defer { pasteboard.releaseGlobally() }
let board = SystemCopyBoard(pasteboard: pasteboard)
let first = NSPasteboardItem()
first.setString("日本語の元のコピー", forType: .string)
first.setData(Data("{\\rtf1\\ansi old rich text}".utf8), forType: .rtf)
let second = NSPasteboardItem()
second.setData(Data([9, 8, 7]), forType: NSPasteboard.PasteboardType("test.private.binary"))
require(pasteboard.writeObjects([first, second]), "Initialize synthetic clipboard")
let original = try board.snapshot()
require(original.count == 2 && original[0][NSPasteboard.PasteboardType.string.rawValue] == Data("日本語の元のコピー".utf8)
    && original[0][NSPasteboard.PasteboardType.rtf.rawValue] == Data("{\\rtf1\\ansi old rich text}".utf8)
    && original[1]["test.private.binary"] == Data([9, 8, 7]), "Preserve multiple items and formats, allowing macOS-added aliases")
pasteboard.clearContents(); pasteboard.setString("selected text", forType: .string)
let copiedGeneration = board.generation
require(board.restore(original, ifGeneration: copiedGeneration), "Restore original formats")
require(try board.snapshot() == original, "Exact binary roundtrip on real NSPasteboard")
pasteboard.clearContents(); pasteboard.setString("newer user copy", forType: .string)
require(!board.restore(original, ifGeneration: copiedGeneration), "Stale generation never overwrites newer content")
require(board.text == "newer user copy", "Newer copy preserved")
pasteboard.clearContents()
let big = NSPasteboardItem()
big.setData(Data(repeating: 1, count: 8 * 1024 * 1024 + 1), forType: NSPasteboard.PasteboardType("public.data"))
require(pasteboard.writeObjects([big]), "Set large synthetic payload")
do { _ = try board.snapshot(); require(false, "Reject backups larger than 8 MiB") }
catch CopySessionError.snapshot {}
print("PASS: real private pasteboard multi-item/binary restore, newer generation protection, size cap")
