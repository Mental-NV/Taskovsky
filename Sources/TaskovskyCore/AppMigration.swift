import Foundation

/// Compatibility with releases that used the original misspelled app name.
public enum AppMigration {
    static let legacyName = "Taskvovsky"
    static let legacyBundleIdentifier = "local.taskvovsky.mac"

    static func workspaceURL(in applicationSupport: URL) throws -> URL {
        let current = applicationSupport.appendingPathComponent("Taskovsky", isDirectory: true)
        let legacy = applicationSupport.appendingPathComponent(legacyName, isDirectory: true)
        let files = FileManager.default
        // Move the whole directory so settings, recovery backups, and future files stay together.
        // An existing renamed workspace always takes precedence and is never overwritten.
        if !files.fileExists(atPath: current.path), files.fileExists(atPath: legacy.path) {
            try files.moveItem(at: legacy, to: current)
        }
        return current.appendingPathComponent("workspace.json")
    }

    public static func migratePreferences(defaults: UserDefaults = .standard,
                                          destinationDomain: String = "local.taskovsky.mac",
                                          legacyDomain: String? = nil) {
        let marker = "Taskovsky.didMigrateLegacyPreferences"
        var current = defaults.persistentDomain(forName: destinationDomain) ?? [:]
        guard current[marker] as? Bool != true else { return }
        for (key, value) in defaults.persistentDomain(forName: legacyDomain ?? legacyBundleIdentifier) ?? [:] {
            let renamed = key.replacingOccurrences(of: legacyName, with: "Taskovsky")
            if current[renamed] == nil { current[renamed] = value }
        }
        current[marker] = true
        defaults.setPersistentDomain(current, forName: destinationDomain)
    }
}
