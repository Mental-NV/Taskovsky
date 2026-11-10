import Foundation
import TaskovskyCore
import TaskovskyWorkspace

@main struct FixtureTool {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { throw CocoaError(.fileReadInvalidFileName) }
        let root = URL(fileURLWithPath: args[2], isDirectory: true)
        if args[1] == "generate" {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let snapshot = try MobilePreviewFixture.generatedSession(samples: true)
            let workspace = root.appendingPathComponent("MobileQAWorkspace.json"), settings = root.appendingPathComponent("MobileQASettings.json")
            try snapshot.workspaceBytes.write(to: workspace)
            try snapshot.settingsBytes.write(to: settings)
            let store = TaskStore(fileURL: workspace, settingsURL: settings, seed: false)
            store.save()
            let unchanged = store.settings; store.settings = unchanged
            guard store.storageError == nil, store.data.tasks.count == 8 else { throw CocoaError(.fileWriteUnknown) }
            print("Mac TaskStore wrote eight neutral tasks and settings")
        } else if let expectedCount = ["verify": 8, "verify-capture": 9, "verify-first-capture": 1,
                                       "verify-lifecycle-complete": 10, "verify-lifecycle-purge": 7][args[1]] {
            guard UUID(uuidString: root.lastPathComponent) != nil,
                  root.deletingLastPathComponent().lastPathComponent == "QA",
                  root.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent == "TaskovskyMobile",
                  FileManager.default.fileExists(atPath: root.appendingPathComponent("initial-workspace.json").path) else {
                throw CocoaError(.fileReadInvalidFileName)
            }
            let workspace = root.appendingPathComponent("workspace.json"), settings = root.appendingPathComponent("settings.json")
            let bytes = try Data(contentsOf: workspace), originalSettings = try Data(contentsOf: settings)
            let store = TaskStore(fileURL: workspace, settingsURL: settings, seed: false)
            guard store.storageError == nil, !store.needsRecovery, store.data.tasks.count == expectedCount else { throw CocoaError(.fileReadCorruptFile) }
            guard try Data(contentsOf: workspace) == bytes, try Data(contentsOf: settings) == originalSettings else { throw CocoaError(.fileWriteUnknown) }
            print("Mac TaskStore reloaded \(expectedCount) QA tasks without writes")
        } else { throw CocoaError(.fileReadInvalidFileName) }
    }
}
