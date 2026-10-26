import Foundation
import Darwin

enum ArchiveError: LocalizedError {
    case empty, unsafePath, io
    var errorDescription: String? {
        switch self {
        case .empty: return "入力欄に保存する文章がありません。"
        case .unsafePath: return "保存先が通常のフォルダー／ファイルではありません。"
        case .io: return "保存できませんでした。保存先の空き容量・アクセス権を確認してください。"
        }
    }
}

struct CapturePolicy {
    enum SelectionError: Error { case unavailable }

    static func text(selected: String?, full: @autoclosure () -> String?) throws -> String {
        guard let selected else { throw SelectionError.unavailable }
        if !selected.isEmpty { return selected }
        guard let value = full() else { throw SelectionError.unavailable }
        return value
    }

    static func allowed(role: String, subrole: String?, app: String) -> Bool {
        return ["AXTextArea", "AXTextField", "AXComboBox"].contains(role)
            && allowedSelection(role: role, subrole: subrole, app: app)
    }

    static func allowedSelection(role: String, subrole: String?, app: String) -> Bool {
        let blocked = ["1password", "bitwarden", "lastpass", "keepass", "dashlane", "com.apple.passwords", "keychainaccess"]
        return role != "AXSecureTextField" && subrole != "AXSecureTextField"
            && !blocked.contains(where: { app.lowercased().contains($0) })
    }

    static func maySearchAncestors(role: String) -> Bool {
        return !["AXWebArea", "AXWindow", "AXApplication"].contains(role)
    }
}

struct CaptureContext {
    enum Mode: String { case selection, full }
    var title: String?
    var source: String?
    var mode: Mode
    var bundleID: String

    init(title: String? = nil, source: String? = nil, mode: Mode = .full, bundleID: String = "") {
        self.title = title
        self.source = source
        self.mode = mode
        self.bundleID = bundleID
    }

    var sourceURL: URL? {
        guard let source, let url = URL(string: source),
              let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) else { return nil }
        if scheme != "file" && (url.host?.isEmpty ?? true) { return nil }
        return url
    }

    var documentPath: String? {
        if let url = sourceURL, url.isFileURL { return url.path }
        if let source, source.hasPrefix("/") { return source }
        return nil
    }

    func metadata(app: String, timestamp: String) -> [String: String] {
        let url = sourceURL
        return ["id": UUID().uuidString.lowercased(), "created_at": timestamp,
                "app": app, "bundle_id": bundleID, "title": title ?? "",
                "url": url?.isFileURL == false ? url!.absoluteString : "",
                "document_path": documentPath ?? "", "capture_mode": mode.rawValue]
    }
}

struct Archive {
    let directory: URL

    func save(text: String, app: String, context: CaptureContext = CaptureContext(), date: Date = Date()) throws -> URL {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ArchiveError.empty }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        let dir = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard dir >= 0 else { throw ArchiveError.unsafePath }
        defer { close(dir) }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let name = day.string(from: date) + ".md"
        let fd = openat(dir, name, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard fd >= 0 else { throw ArchiveError.unsafePath }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1 else { throw ArchiveError.unsafePath }
        guard flock(fd, LOCK_EX) == 0 else { throw ArchiveError.io }
        defer { flock(fd, LOCK_UN) }
        guard fchmod(fd, 0o600) == 0 else { throw ArchiveError.io }
        var fence = "```"
        while text.contains(fence) { fence += "`" }
        let timestamp = ISO8601DateFormatter().string(from: date)
        let appName = app.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let metadata = String(decoding: try encoder.encode(context.metadata(app: app, timestamp: timestamp)), as: UTF8.self)
        let entry = "\n## \(timestamp) · \(appName)\n\n```json\n\(metadata)\n```\n\n\(fence)text\n\(text)\n\(fence)\n"
        let data = Data(entry.utf8)
        let originalSize = lseek(fd, 0, SEEK_END)
        guard originalSize >= 0 else { throw ArchiveError.io }
        do {
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let count = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw ArchiveError.io }
                    offset += count
                }
            }
            guard fsync(fd) == 0 else { throw ArchiveError.io }
        } catch {
            _ = ftruncate(fd, originalSize)
            _ = fsync(fd)
            throw error
        }
        return directory.appendingPathComponent(name)
    }
}
