import Foundation

final class FakeBoard: CopyBoard {
    var generation = 1
    var items: ClipboardSnapshot = [["public.utf8-plain-text": Data("old clipboard".utf8), "public.rtf": Data("old rich text".utf8)]]
    var text: String? = "old clipboard"
    var snapshotFails = false
    var raceOnRestore = false
    var restores = 0
    func snapshot() throws -> ClipboardSnapshot {
        if snapshotFails { throw CopySessionError.snapshot }
        return items
    }
    func restore(_ snapshot: ClipboardSnapshot, ifGeneration expected: Int) -> Bool {
        if raceOnRestore { generation += 1; text = "new user copy" }
        guard generation == expected else { return false }
        items = snapshot; generation += 1; restores += 1
        return true
    }
}
func require(_ value: Bool, _ message: String) { if !value { fputs("FAIL: \(message)\n", stderr); exit(1) } }
for scenario in ["success", "delayed", "unchanged", "nontext", "switch", "race", "snapshot", "late", "invisible"] {
    let board = FakeBoard()
    let original = board.items
    board.snapshotFails = scenario == "snapshot"
    board.raceOnRestore = scenario == "race"
    var clock: TimeInterval = 0
    var jobs: [() -> Void] = []
    var active = true
    var sent = 0
    var result: Result<String, Error>?
    let session = CopySession(board: board, targetIsCurrent: { active }, sendCopy: {
        sent += 1
        if scenario != "unchanged" && scenario != "delayed" {
            board.generation += 1
            board.text = scenario == "nontext" ? nil : "new selected text"
            if scenario == "invisible" { board.text = "\u{200B}\u{200B}" }
        }
        if scenario == "switch" { active = false }
        if scenario == "late" { clock = 3 }
    }, now: { clock }, schedule: { delay, action in
        jobs.append {
            clock += delay
            if scenario == "delayed", clock >= 1.1, board.generation == 1 {
                board.generation += 1; board.text = "new selected text"
            }
            action()
        }
    })
    session.start { result = $0 }
    for _ in 0..<200 {
        guard !jobs.isEmpty else { break }
        jobs.removeFirst()()
    }
    require(result != nil, "\(scenario) completes")
    if scenario == "success" || scenario == "delayed" {
        require((try? result!.get()) == "new selected text", "Save only freshly copied text")
        require(board.items == original && board.restores == 1, "Restore every original clipboard format")
    } else {
        require((try? result!.get()) == nil, "\(scenario) must not save stale or uncertain text")
    }
    if scenario == "unchanged" { require(board.restores == 0, "Do not touch unchanged clipboard") }
    if scenario == "nontext" { require(board.restores == 1, "Restore nontext copy before failing") }
    if scenario == "switch" { require(board.restores == 0, "Do not overwrite clipboard after target switch") }
    if scenario == "race" { require(board.text == "new user copy" && board.restores == 0, "Never clobber newer user copy") }
    if scenario == "snapshot" { require(sent == 0, "Do not send copy without complete backup") }
    require(sent <= 1, "Send copy at most once")
}
print("PASS: fresh copy only, rich clipboard restore, timeout, nontext, target switch, concurrent change, failed backup")
