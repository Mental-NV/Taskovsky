import Foundation
import CryptoKit

/// Dedicated caller-owned recovery namespace beside one canonical workspace.
/// Checks reject links before operations; they are not a cross-process race lock.
/// Path-derived identity is stable across launches, not across file relocation.
public struct MacDescriptionRecoveryDirectory: Sendable {
    public let workspaceID: UUID
    public let root: URL
    public init(workspaceURL: URL) throws {
        let canonical = workspaceURL.standardizedFileURL.resolvingSymlinksInPath()
        guard canonical.isFileURL else { throw CocoaError(.fileReadInvalidFileName) }
        let hex = SHA256.hash(data: Data(canonical.path.utf8)).map { String(format: "%02x", $0) }.joined()
        let token = Array(hex.prefix(32))
        workspaceID = UUID(uuidString: String(token[0..<8]) + "-" + String(token[8..<12]) + "-" + String(token[12..<16]) + "-" + String(token[16..<20]) + "-" + String(token[20..<32]))!
        root = canonical.deletingLastPathComponent().appendingPathComponent(".taskovsky-description-recovery-" + hex)
    }
    public func prepare() throws {
        let parent = root.deletingLastPathComponent()
        let properties = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard properties.isDirectory == true, properties.isSymbolicLink != true else { throw CocoaError(.fileWriteInvalidFileName) }
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        }
        try validateRoot()
    }
    public func journal(taskID: UUID) throws -> MacDescriptionJournal {
        try validateRoot()
        let file = root.appendingPathComponent(taskID.uuidString + ".json")
        try validateFile(file)
        return MacDescriptionJournal(fileURL: file, workspaceID: workspaceID, taskID: taskID,
            validate: { try validateFile(file) },
            write: { bytes, url in
                try validateFile(url)
                try bytes.write(to: url, options: localFileWriteOptions)
            }, remove: { url in
                try validateFile(url)
                try FileManager.default.removeItem(at: url)
            })
    }
    public func savedTaskIDs() throws -> [UUID] {
        try validateRoot()
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]).map { file in
            try validateFile(file)
            guard file.pathExtension == "json", let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return id
        }.sorted { $0.uuidString < $1.uuidString }
    }
    private func validateRoot() throws {
        let value = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard value.isDirectory == true, value.isSymbolicLink != true else { throw CocoaError(.fileWriteInvalidFileName) }
    }
    private func validateFile(_ file: URL) throws {
        try validateRoot()
        guard file.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { throw CocoaError(.fileWriteInvalidFileName) }
        do {
            let value = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            guard (attributes[.referenceCount] as? NSNumber)?.intValue == 1, value.isRegularFile == true, value.isSymbolicLink != true else { throw CocoaError(.fileWriteInvalidFileName) }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile { }
    }
}
