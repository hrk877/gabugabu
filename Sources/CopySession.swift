import Foundation

typealias ClipboardSnapshot = [[String: Data]]

protocol CopyBoard: AnyObject {
    var generation: Int { get }
    var text: String? { get }
    func snapshot() throws -> ClipboardSnapshot
    func restore(_ snapshot: ClipboardSnapshot, ifGeneration: Int) -> Bool
}

enum CopySessionError: LocalizedError {
    case snapshot, unavailable, changed, copyFailed
    var errorDescription: String? {
        switch self {
        case .snapshot: return "クリップボードを安全に退避できません。コピー内容を整理してから試してください。"
        case .unavailable: return "文章を選んでから ⌘⌥S を押してください。通常のコピーができる文章が対象です。"
        case .changed: return "保存中に画面やコピー内容が変わりました。文章を選んで、もう一度試してください。"
        case .copyFailed: return "コピーを実行できません。アクセシビリティの許可を確認してください。"
        }
    }
}

final class CopySession {
    private let board: CopyBoard
    private let targetIsCurrent: () -> Bool
    private let sendCopy: () throws -> Void
    private let now: () -> TimeInterval
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private var completion: ((Result<String, Error>) -> Void)?
    private var backup: ClipboardSnapshot?
    private var originalGeneration = 0
    private var deadline: TimeInterval = 0
    private var finished = false

    init(board: CopyBoard, targetIsCurrent: @escaping () -> Bool,
         sendCopy: @escaping () throws -> Void,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void) {
        self.board = board; self.targetIsCurrent = targetIsCurrent; self.sendCopy = sendCopy
        self.now = now; self.schedule = schedule
    }

    func start(completion: @escaping (Result<String, Error>) -> Void) {
        guard self.completion == nil, !finished else { return }
        self.completion = completion
        do {
            guard targetIsCurrent() else { throw CopySessionError.changed }
            originalGeneration = board.generation
            backup = try board.snapshot()
            guard board.generation == originalGeneration, targetIsCurrent() else { throw CopySessionError.changed }
            // Native apps may initialize their copy handlers lazily on the first request.
            deadline = now() + 2.0
            try sendCopy()
            schedule(0.02) { self.poll() }
        } catch { finish(.failure(error)) }
    }

    private func poll() {
        guard !finished else { return }
        guard targetIsCurrent() else { finish(.failure(CopySessionError.changed)); return }
        let generation = board.generation
        if now() >= deadline {
            if generation != originalGeneration, let backup { _ = board.restore(backup, ifGeneration: generation) }
            finish(.failure(CopySessionError.unavailable)); return
        }
        if generation != originalGeneration, let text = board.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard board.generation == generation, targetIsCurrent(), now() < deadline else { finish(.failure(CopySessionError.changed)); return }
            guard let backup, board.restore(backup, ifGeneration: generation) else { finish(.failure(CopySessionError.changed)); return }
            finish(.success(text))
        } else {
            schedule(0.02) { self.poll() }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        let callback = completion
        completion = nil; backup = nil
        callback?(result)
    }
}
