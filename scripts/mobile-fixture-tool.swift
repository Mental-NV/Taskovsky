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
                                       "verify-lifecycle-complete": 10, "verify-lifecycle-purge": 7, "verify-rich-preview": 8,
                                       "verify-hierarchy-create": 9, "verify-hierarchy-move": 8, "verify-hierarchy-detach": 8,
                                       "verify-organization-copy": 11, "verify-organization-folder": 8,
                                       "verify-organization-archive": 8, "verify-smart-lists": 8,
                                       "verify-saved-filter-advanced": 8, "verify-saved-filter-rename": 8,
                                       "verify-tag-merge": 8, "verify-tag-delete": 8,
                                       "verify-board-archive": 8, "verify-board-mode": 8,
                                       "verify-board-undo": 8, "verify-board-drop": 8, "verify-summary-note": 9, "verify-search-filter": 8, "verify-template-application": 8, "verify-local-settings": 8][args[1]] {
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
            #if DEBUG
            if args[1] == "verify-rich-preview" {
                let expected = MobilePreviewFixture.styledDescription
                guard let task = store.data.tasks.first, task.title == "Review the project outline with formatting",
                      RichBody.sameCodeUnits(task.body, expected.text), task.richBody == expected,
                      let rich = task.richBody, RichDescriptionPreview(body: task.body, rich: rich) != nil else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
            #endif
            if args[1].hasPrefix("verify-hierarchy-") {
                let tasks = store.data.tasks
                guard let root = tasks.first(where: { $0.title == "Review the project outline" }),
                      let child = tasks.first(where: { $0.title == "Arrange the studio" }),
                      let target = tasks.first(where: { $0.title == "Prepare the weekly plan" }),
                      root.checklist.count == 2, root.richBody != nil, root.completedAt == nil else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let valid = switch args[1] {
                case "verify-hierarchy-create":
                    child.parentID == root.id && tasks.contains { $0.title == "Gather a folder" && $0.parentID == root.id && $0.completedAt != nil }
                case "verify-hierarchy-move":
                    root.parentID == target.id && child.parentID == root.id && root.listID == target.listID && child.listID == target.listID
                default: child.parentID == nil && child.listID == root.listID
                }
                guard valid else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1].hasPrefix("verify-organization-") {
                let data = store.data
                let valid: Bool
                switch args[1] {
                case "verify-organization-copy":
                    guard let copy = data.lists.first(where: { $0.name == "Work copy" }),
                          let root = data.tasks.first(where: { $0.listID == copy.id && $0.title == "Review the project outline" }),
                          let child = data.tasks.first(where: { $0.listID == copy.id && $0.title == "Prepare the weekly plan" }),
                          let filter = data.filters.first(where: { $0.name == "Original Work only" }) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    valid = root.richBody != nil && root.checklist.first?.isCompleted == true && child.parentID == root.id &&
                        filter.listIDs.count == 1 && !data.lists.contains { filter.listIDs.contains($0.id) }
                case "verify-organization-folder":
                    valid = data.folders.map(\.name) == ["Studio folder"] &&
                        data.lists.contains { $0.name == "Work renamed" && ListPlacement($0) == .aboveFolders } &&
                        data.lists.contains { $0.name == "Studio list" && ListPlacement($0) == .aboveFolders }
                default:
                    valid = data.lists.contains { $0.name == "Work" && !$0.isArchived && !$0.showsInSmartLists }
                }
                guard valid else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1] == "verify-smart-lists" {
                let preferences = store.settings
                guard preferences.isSmartListVisible(.all, count: 0), !preferences.isSmartListVisible(.today, count: 9),
                      !preferences.isSmartListVisible(.tomorrow, count: 0), preferences.isSmartListVisible(.tomorrow, count: 1),
                      preferences.effectiveSmartListOrder.prefix(5) == [.all, .today, .tomorrow, .inbox, .week]
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1].hasPrefix("verify-saved-filter-") {
                let created = args[1] == "verify-saved-filter-advanced"
                guard let filter = store.data.filters.first(where: { $0.name == (created ? "Work words" : "Retained rule") }),
                      filter.ruleRoot != nil else { throw CocoaError(.fileReadCorruptFile) }
                let matches = TaskDestination.filter(filter.id).matchingTasks(in: store.data, now: MobilePreviewFixture.now,
                                                                              calendar: store.settings.calendar)
                let expected = created ? ["Prepare the weekly plan", "Write meeting notes"] : []
                guard matches.map(\.title) == expected else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1].hasPrefix("verify-tag-") {
                let merged = args[1] == "verify-tag-merge"
                guard let sprint = store.data.tags.first(where: { $0.name == "Sprint" }),
                      let filter = store.data.filters.first(where: { $0.name == "Tagged review" }),
                      store.settings.defaultTagID == (merged ? sprint.id : nil) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let matches = TaskDestination.filter(filter.id).matchingTasks(in: store.data)
                guard matches.map(\.title) == (merged ? ["Review the project outline", "Prepare the weekly plan"] : [])
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1].hasPrefix("verify-board-") {
                let data = store.data
                let modes = data.lists.map(\.viewMode)
                let expectedMode: TaskListViewMode = args[1] == "verify-board-archive" ? .list : .board
                guard modes == [expectedMode, .list, .board], data.lists[2].isArchived else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let archive = BoardProjection.split(BoardProjection.tasks(forList: data.lists[2].id, in: data))
                let work = BoardProjection.split(BoardProjection.tasks(forList: data.lists[0].id, in: data))
                let completed = args[1] == "verify-board-drop" ? ["Write meeting notes"] : []
                guard archive.open.isEmpty, archive.completed.map(\.title) == ["Read a chapter"], archive.wontDo.isEmpty,
                      work.open.contains(where: { $0.title == "Collect design references" && $0.kind == .note }),
                      work.completed.map(\.title) == completed,
                      work.wontDo.map(\.title) == ["Prepare the weekly plan"]
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1] == "verify-search-filter" {
                guard let archived = store.data.lists.first(where: { $0.name == "Personal" }), archived.isArchived,
                      let filter = store.data.filters.first(where: { $0.name == "Archived chapter" }),
                      filter.listIDs == [archived.id], filter.keyword == "chapter", filter.status == .all,
                      TaskDestination.filter(filter.id).matchingTasks(in: store.data).map(\.title) == ["Read a chapter"]
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1] == "verify-template-application" {
                let data = store.data
                guard let template = data.templates.first, data.templates.count == 1, let parent = data.tasks.first,
                      let child = data.tasks.first(where: { $0.parentID == parent.id }),
                      template.name == parent.title, child.title == template.title,
                      let rich = parent.richBody, template.richBody == rich, child.richBody == rich,
                      RichBody.sameCodeUnits(parent.body, template.body), RichBody.sameCodeUnits(child.body, template.body),
                      Set(child.checklist.map(\.id)).isDisjoint(with: template.checklist.map(\.id)),
                      child.checklist.map(\.title) == template.checklist.map(\.title)
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1] == "verify-local-settings" {
                guard let work = store.data.lists.first(where: { $0.name == "Work" }),
                      store.settings.startWeekOn == 1, store.settings.calendar.firstWeekday == 1,
                      store.settings.defaultListID == work.id, store.settings.defaultPriority == .high
                else { throw CocoaError(.fileReadCorruptFile) }
            }
            if args[1] == "verify-summary-note" {
                guard let note = store.data.tasks.first, note.title.hasPrefix("Summary "), note.body.contains("Edited locally"),
                      note.kind == .note, note.listID == nil, note.dueDate == nil, note.reminderDates.isEmpty,
                      note.tagIDs.isEmpty, note.priority == .none else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
            guard try Data(contentsOf: workspace) == bytes, try Data(contentsOf: settings) == originalSettings else { throw CocoaError(.fileWriteUnknown) }
            print("Mac TaskStore reloaded \(expectedCount) QA tasks without writes")
        } else { throw CocoaError(.fileReadInvalidFileName) }
    }
}
