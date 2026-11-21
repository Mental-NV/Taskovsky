import Foundation
import TaskovskyDomain
import TaskovskyWorkspace

/// Neutral development-only content. Never reads the desktop workspace.
enum MobilePreviewFixture {
    static var now: Date {
        #if DEBUG
        ISO8601DateFormatter().date(from: "2026-11-09T09:00:00Z")!
        #else
        Date()
        #endif
    }
    #if DEBUG
    static var styledDescription: RichBody {
        let lines = ["Launch plan", "Check e\u{301} 🧩 with care", "Draft the outline", "Review the checklist",
                     "Keep decisions together", "Collect references", "Bring notes", "", "Reference link"]
        let text = lines.joined(separator: "\n")
        let string = text as NSString
        func inline(_ phrase: String, style: (inout RichInlineRun) -> Void) -> RichInlineRun {
            let range = string.range(of: phrase)
            var run = RichInlineRun(location: range.location, length: range.length)
            style(&run)
            return run
        }
        func block(_ phrase: String, style: (inout RichBlockRun) -> Void) -> RichBlockRun {
            let range = string.paragraphRange(for: string.range(of: phrase))
            var run = RichBlockRun(location: range.location, length: range.length)
            style(&run)
            return run
        }
        let rule = string.range(of: "\n\n").location + 1
        return RichBody(text: text, runs: [
            inline("Check") { $0.bold = true; $0.underline = true },
            inline("e\u{301} 🧩") { $0.italic = true; $0.highlight = true },
            inline("with care") { $0.code = true; $0.strikethrough = true },
            inline("Reference link") { $0.link = "https://example.invalid/reference" },
        ], blocks: [
            block(lines[0]) { $0.heading = 1 },
            block(lines[2]) { $0.list = .numbered },
            block(lines[3]) { $0.list = .numbered },
            block(lines[4]) { $0.quote = true },
            block(lines[5]) { $0.list = .bullet },
            block(lines[6]) { $0.list = .checklist; $0.checked = true },
            RichBlockRun(location: rule, length: 1, rule: true),
        ])
    }
    #endif

    static var day: Date { now }
    private static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }
    static func session(samples: Bool = false, unknownData: Bool = false) throws -> ReadOnlyWorkspaceSnapshot {
        guard samples else { return try generatedSession() }
        guard let workspaceURL = Bundle.main.url(forResource: "MobileQAWorkspace", withExtension: "json"),
              let settingsURL = Bundle.main.url(forResource: "MobileQASettings", withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        var workspace = try Data(contentsOf: workspaceURL)
        if unknownData {
            var object = try JSONSerialization.jsonObject(with: workspace) as! [String: Any]
            var tasks = object["tasks"] as! [[String: Any]]
            tasks[tasks.count - 1]["futurePayload"] = ["version": 99, "retained": true]
            object["tasks"] = tasks
            workspace = try JSONSerialization.data(withJSONObject: object)
        }
        return try ReadOnlyWorkspaceSnapshot(workspaceBytes: workspace, settingsBytes: Data(contentsOf: settingsURL))
    }
    static func generatedSession(samples: Bool = false, unknownData: Bool = false) throws -> ReadOnlyWorkspaceSnapshot {
        var data = WorkspaceData(); var settings = AppSettings()
        #if DEBUG
        if samples {
        let work = TaskList(id: id(100), name: "Work", color: "#4670FA")
        let home = TaskList(id: id(101), name: "Personal", color: "#30A77A")
        let area = TaskTag(id: id(200), name: "Planning", color: "#E6A53A")
        data.lists = [work, home]; data.tags = [area]
        let titles = ["Review the project outline", "Prepare the weekly plan", "Read a chapter", "Arrange the studio", "Collect design references", "Write meeting notes", "Book time for a walk", "Review the draft"]
        for (index, title) in titles.enumerated() {
            var task = TaskItem(id: id(index + 1), title: title, body: index == 0 ? "Project overview\nKeep the key decisions together.\nA composed e\u{301} and an emoji 🧩 remain unchanged." : "A neutral sample description.", listID: index % 3 == 0 ? nil : index % 2 == 0 ? home.id : work.id, dueDate: now.addingTimeInterval(Double(index - 2) * 3_600))
            task.createdAt = now.addingTimeInterval(-86_400); task.updatedAt = task.createdAt
            if index == 0 { task.richBody = RichBody(text: task.body, runs: [.init(location: 0, length: 16, bold: true)]) }
            if index == 1 { task.tagIDs = [area.id]; task.scheduledDuration = TaskDurationRange(start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200), isAllDay: false); task.dueDate = task.scheduledDuration?.end; task.hasDueTime = true }
            if index == 2 { task.dueDate = nil }
            data.tasks.append(task)
        }
        data.filters = [TaskFilter(id: id(300), name: "Planning", tagIDs: [area.id])]
        settings.calendarOptions.additionalTimeZones = [.init(identifier: "America/New_York"), .init(identifier: "Asia/Tokyo"), .init(identifier: "Europe/London"), .init(identifier: "Europe/Paris")]
        // Keep the narrow default grid readable; values remain retained.
        settings.calendarOptions.showAdditionalTimeZones = false
        }
        #endif
        let encoder = JSONEncoder()
        var workspace = try encoder.encode(data)
        #if DEBUG
        if samples && unknownData {
            var object = try JSONSerialization.jsonObject(with: workspace) as! [String: Any]
            var tasks = object["tasks"] as! [[String: Any]]
            tasks[tasks.count - 1]["futurePayload"] = ["version": 99, "retained": true]
            object["tasks"] = tasks
            workspace = try JSONSerialization.data(withJSONObject: object)
        }
        #endif
        return try ReadOnlyWorkspaceSnapshot(workspaceBytes: workspace, settingsBytes: encoder.encode(settings))
    }
}
