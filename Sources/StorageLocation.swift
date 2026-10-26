import Foundation

enum StorageLocation {
    static func directory(home: URL) -> URL {
        return home.appendingPathComponent("GABUGABU", isDirectory: true).appendingPathComponent("Archive", isDirectory: true)
    }

    // Move whole directories so old Markdown bytes and filenames remain unchanged.
    // If both locations exist, retain the old folder as a separate import instead of merging dates.
    static func prepare(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let fm = FileManager.default
        let parent = home.appendingPathComponent("GABUGABU", isDirectory: true)
        let destination = directory(home: home)
        let legacy = home.appendingPathComponent("PromptArchive", isDirectory: true)
        func exists(_ url: URL) throws -> Bool {
            do {
                let attributes = try fm.attributesOfItem(atPath: url.path)
                guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw ArchiveError.unsafePath }
                return true
            } catch let error as NSError where error.domain == NSCocoaErrorDomain
                && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
                return false
            }
        }
        if try !exists(parent) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let hasDestination = try exists(destination)
        if try exists(legacy) {
            let target = hasDestination
                ? destination.appendingPathComponent("Imported-PromptArchive-" + UUID().uuidString, isDirectory: true)
                : destination
            try fm.moveItem(at: legacy, to: target)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: target.path)
        } else if !hasDestination {
            try fm.createDirectory(at: destination, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination.path)
        return destination
    }
}
