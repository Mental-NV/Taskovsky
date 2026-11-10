import Foundation

public enum WorkspaceBootstrapError: Error { case incompleteFileSet }

public enum WorkspaceBootstrap {
    /// Caller supplies a platform-owned directory. Never repairs or reseeds an
    /// existing/partial pair. A failed first install retains its staged files.
    public static func prepare(directory: URL, initial: ReadOnlyWorkspaceSnapshot) throws {
        let manager = FileManager.default
        let workspace = directory.appendingPathComponent("workspace.json")
        let settings = directory.appendingPathComponent("settings.json")
        let hasWorkspace = manager.fileExists(atPath: workspace.path)
        let hasSettings = manager.fileExists(atPath: settings.path)
        if hasWorkspace && hasSettings { return }
        guard !hasWorkspace && !hasSettings else { throw WorkspaceBootstrapError.incompleteFileSet }
        if manager.fileExists(atPath: directory.path) {
            let children = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            guard !children.contains(where: { $0.lastPathComponent.hasPrefix(".initialization-") }) else {
                throw WorkspaceBootstrapError.incompleteFileSet
            }
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(".initialization-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        let stagedSettings = staging.appendingPathComponent("settings.json")
        let stagedWorkspace = staging.appendingPathComponent("workspace.json")
        try initial.settingsBytes.write(to: stagedSettings, options: localFileWriteOptions)
        try initial.workspaceBytes.write(to: stagedWorkspace, options: localFileWriteOptions)
        // moveItem refuses replacement. A crash between moves leaves a partial
        // pair that the next launch preserves and blocks instead of reseeding.
        try manager.moveItem(at: stagedSettings, to: settings)
        try manager.moveItem(at: stagedWorkspace, to: workspace)
        try manager.removeItem(at: staging) // Empty after both successful moves.
    }
}

@usableFromInline
var localFileWriteOptions: Data.WritingOptions {
    var value: Data.WritingOptions = [.atomic]
    #if os(iOS)
    value.insert(.completeFileProtectionUntilFirstUserAuthentication)
    #endif
    return value
}
