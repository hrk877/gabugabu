import Foundation
import Darwin

func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw NSError(domain: message, code: 1) }
}

let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: root) }
do {
    let migrationHome = root.appendingPathComponent("migration-home")
    let legacy = migrationHome.appendingPathComponent("PromptArchive")
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    let legacyText = "previous private record\n日本語\n"
    try legacyText.write(to: legacy.appendingPathComponent("2026-10-25.md"), atomically: true, encoding: .utf8)
    let destination = try StorageLocation.prepare(home: migrationHome)
    try check(destination.path == migrationHome.appendingPathComponent("GABUGABU/Archive").path, "Branded default path")
    try check(try String(contentsOf: destination.appendingPathComponent("2026-10-25.md"), encoding: .utf8) == legacyText, "Migration preserves exact content")
    try check(!FileManager.default.fileExists(atPath: legacy.path), "Legacy directory moved")
    let archivePermissions = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as! NSNumber
    try check(archivePermissions.intValue & 0o077 == 0, "Migrated archive remains private")
    _ = try StorageLocation.prepare(home: migrationHome)
    try check(try FileManager.default.contentsOfDirectory(atPath: destination.path).count == 1, "Repeated startup does not duplicate records")
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    try "collision".write(to: legacy.appendingPathComponent("2026-10-25.md"), atomically: true, encoding: .utf8)
    _ = try StorageLocation.prepare(home: migrationHome)
    let imports = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("Imported-") }
    try check(imports.count == 1, "Existing archive imports legacy into separate directory")
    try check(try String(contentsOf: imports[0].appendingPathComponent("2026-10-25.md"), encoding: .utf8) == "collision", "Collision preserved separately")
    try check(try String(contentsOf: destination.appendingPathComponent("2026-10-25.md"), encoding: .utf8) == legacyText, "Collision never overwrites existing record")
    let linkedHome = root.appendingPathComponent("linked-home")
    try FileManager.default.createDirectory(at: linkedHome, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedHome.appendingPathComponent("GABUGABU"), withDestinationURL: migrationHome)
    do { _ = try StorageLocation.prepare(home: linkedHome); throw NSError(domain: "Storage parent symlink accepted", code: 1) }
    catch ArchiveError.unsafePath {}
    let archive = Archive(directory: root)
    let date = ISO8601DateFormatter().date(from: "2026-10-26T03:00:00Z")!
    let text = "  日本語の文章\n```swift\nprint(\"hello\")\n```\n末尾  "
    let file = try archive.save(text: text, app: "Test\nApp", date: date)
    try check(try String(contentsOf: file, encoding: .utf8).contains(text), "Japanese and whitespace preserved")
    _ = try archive.save(text: "second entry", app: "Test", date: date)
    let saved = try String(contentsOf: file, encoding: .utf8)
    try check(saved.contains(text) && saved.contains("second entry"), "Append preserves earlier entry")
    let context = CaptureContext(title: "企画\n\"見直し\"", source: "https://example.com/conversation/123?q=idea", mode: .selection, bundleID: "com.example.app")
    let contextFile = try archive.save(text: "context test", app: "Test", context: context, date: date)
    let enriched = try String(contentsOf: contextFile, encoding: .utf8)
    let blocks = enriched.components(separatedBy: "```json\n").dropFirst()
    let records = try blocks.map { block -> [String: String] in
        let json = block.components(separatedBy: "\n```").first!
        return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
    }
    try check(records.count == 3, "Every new entry has machine readable metadata")
    try check(Set(records.compactMap { $0["id"] }).count == 3, "Each entry has a unique ID")
    let record = records.last!
    try check(record["title"] == context.title, "Multiline title survives JSON")
    try check(record["url"] == "https://example.com/conversation/123?q=idea", "URL preserved")
    try check(record["capture_mode"] == "selection" && record["bundle_id"] == "com.example.app", "Mode and app identity recorded")
    try check(records.first?["url"] == "" && records.first?["title"] == "", "Missing metadata remains blank")
    try check(CaptureContext(source: "file:///Users/test/My%20Note.txt").documentPath == "/Users/test/My Note.txt", "Document path decoded")
    try check(CaptureContext(source: "javascript:alert(1)").sourceURL == nil, "Unsupported URL discarded")
    try check(CaptureContext(source: "not a URL").sourceURL == nil, "Non URL discarded")
    try check(CaptureContext(source: "/Users/test/note.md").documentPath == "/Users/test/note.md", "Native absolute document path preserved")
    let before = enriched
    do { _ = try archive.save(text: " \n\t", app: "Test", date: date); throw NSError(domain: "Empty accepted", code: 1) }
    catch ArchiveError.empty {}
    try check(try String(contentsOf: file, encoding: .utf8) == before, "Empty does not change file")
    let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as! NSNumber
    try check(permissions.intValue & 0o077 == 0, "File private")
    try check(CapturePolicy.allowed(role: "AXTextArea", subrole: nil, app: "com.apple.TextEdit"), "Text area allowed")
    try check(!CapturePolicy.allowed(role: "AXTextField", subrole: "AXSecureTextField", app: "test"), "Password denied")
    try check(!CapturePolicy.allowed(role: "AXStaticText", subrole: nil, app: "test"), "Static text denied")
    try check(!CapturePolicy.allowed(role: "AXTextField", subrole: nil, app: "com.1password.1password"), "Password app denied")
    try check(CapturePolicy.allowedSelection(role: "AXStaticText", subrole: nil, app: "com.google.Chrome"), "Read-only page selection allowed")
    try check(CapturePolicy.allowedSelection(role: "AXWebArea", subrole: nil, app: "com.apple.Safari"), "Web area selection allowed")
    try check(CapturePolicy.allowedSelection(role: "AXTextArea", subrole: nil, app: "com.apple.Preview"), "Read-only document selection allowed")
    try check(!CapturePolicy.allowedSelection(role: "AXSecureTextField", subrole: nil, app: "test"), "Secure role selection denied")
    try check(!CapturePolicy.allowedSelection(role: "AXTextField", subrole: "AXSecureTextField", app: "test"), "Secure subrole selection denied")
    try check(!CapturePolicy.allowedSelection(role: "AXWebArea", subrole: nil, app: "com.bitwarden.desktop"), "Password app selection denied")
    try check(!CapturePolicy.maySearchAncestors(role: "AXWebArea"), "Never search outside focused web document")
    try check(!CapturePolicy.maySearchAncestors(role: "AXWindow"), "Never search outside focused window")
    try check(CapturePolicy.maySearchAncestors(role: "AXStaticText"), "Text may search its enclosing document")
    try check(try CapturePolicy.text(selected: "excerpt", full: "whole field") == "excerpt", "Selection takes precedence")
    try check(try CapturePolicy.text(selected: "", full: "whole field") == "whole field", "Confirmed empty selection captures field")
    do { _ = try CapturePolicy.text(selected: nil, full: "private surrounding text"); throw NSError(domain: "Selection failure exposed whole field", code: 1) }
    catch CapturePolicy.SelectionError.unavailable {}
    let victim = root.appendingPathComponent("victim.txt")
    try "untouched".write(to: victim, atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: file)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: victim)
    do { _ = try archive.save(text: "attack", app: "Test", date: date); throw NSError(domain: "Symlink accepted", code: 1) }
    catch ArchiveError.unsafePath {}
    try check(try String(contentsOf: victim, encoding: .utf8) == "untouched", "Symlink target untouched")
    let alias = root.appendingPathComponent("alias")
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
    do { _ = try Archive(directory: alias).save(text: "attack", app: "Test", date: date); throw NSError(domain: "Directory symlink accepted", code: 1) }
    catch ArchiveError.unsafePath {}
    let concurrentArchive = Archive(directory: root.appendingPathComponent("concurrent"))
    let errorLock = NSLock()
    var concurrentErrors: [String] = []
    DispatchQueue.concurrentPerform(iterations: 8) { worker in
        for item in 0..<25 {
            do { _ = try concurrentArchive.save(text: "worker-\(worker)-item-\(item)-日本語", app: "Stress", date: date) }
            catch { errorLock.lock(); concurrentErrors.append(String(describing: error)); errorLock.unlock() }
        }
    }
    try check(concurrentErrors.isEmpty, "Concurrent saves all succeed: \(concurrentErrors)")
    let concurrentFile = try FileManager.default.contentsOfDirectory(at: concurrentArchive.directory, includingPropertiesForKeys: nil)[0]
    let concurrentText = try String(contentsOf: concurrentFile, encoding: .utf8)
    try check(concurrentText.components(separatedBy: "```json\n").count - 1 == 200, "Concurrent appends preserve all metadata records")
    for worker in 0..<8 {
        for item in 0..<25 {
            let marker = "worker-\(worker)-item-\(item)-日本語\n"
            try check(concurrentText.components(separatedBy: marker).count - 1 == 1, "Each concurrent text saved exactly once")
        }
    }
    let unsafeDirectory = root.appendingPathComponent("unsafe-file-tests")
    try FileManager.default.createDirectory(at: unsafeDirectory, withIntermediateDirectories: true)
    let unsafeArchive = Archive(directory: unsafeDirectory)
    let unsafeFile = try unsafeArchive.save(text: "seed", app: "Test", date: date)
    try FileManager.default.removeItem(at: unsafeFile)
    try FileManager.default.linkItem(at: victim, to: unsafeFile)
    do { _ = try unsafeArchive.save(text: "hardlink attack", app: "Test", date: date); throw NSError(domain: "Hard link accepted", code: 1) }
    catch ArchiveError.unsafePath {}
    try check(try String(contentsOf: victim, encoding: .utf8) == "untouched", "Hard link target untouched")
    try FileManager.default.removeItem(at: unsafeFile)
    try check(mkfifo(unsafeFile.path, 0o600) == 0, "FIFO fixture created")
    do { _ = try unsafeArchive.save(text: "fifo attack", app: "Test", date: date); throw NSError(domain: "FIFO accepted", code: 1) }
    catch ArchiveError.unsafePath {}
    print("PASS: 200 concurrent Japanese appends exactly once, hardlink and FIFO rejection")
    print("PASS: archive preservation, append, empty input, private permissions, capture policy, selection precedence and read failure, file/directory symlinks, metadata JSON, unique IDs, URL/path normalization and missing context")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
