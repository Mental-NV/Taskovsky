import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace
import UniformTypeIdentifiers

private enum PhoneQACase: String { case known, batchPostpone = "batch-postpone", taskSort = "task-sort", createdGrouping = "created-grouping", lifecycle, arrange, shortCalendarMove = "short-calendar-move", occurrence, skipOccurrence = "skip-occurrence", skipOccurrenceSaveFailure = "skip-occurrence-save-failure", agenda, foldedHours = "folded-hours", allDaySpans = "all-day-spans", monthSpans = "month-spans", monthBrowse = "month-browse", organization, savedFilter = "saved-filter", tagOrganization = "tag-organization", board, timeline, timelineArrange = "timeline-arrange", summary, summaryFields = "summary-fields", summarySaveFailure = "summary-save-failure", calendarOptions = "calendar-options", calendarCompletion = "calendar-completion", richPreview = "rich-preview", richPlainPaste = "rich-plain-paste", richMarkdownPaste = "rich-markdown-paste", richForeignPaste = "rich-foreign-paste", richForeignHTMLBlocks = "rich-foreign-html-blocks", richForeignRTFPaste = "rich-foreign-rtf-paste", richCodePaste = "rich-code-paste", richHighlightColors = "rich-highlight-colors", richChecklistToggle = "rich-checklist-toggle", taskMetadata = "task-metadata", malformedRich = "malformed-rich", captureEmpty = "capture-empty", captureTemplate = "capture-template", afterWrite = "capture-after-write", saveFailure = "save-failure", staleSave = "stale-save", unknownWorkspace = "unknown-workspace", unknownDraft = "unknown-draft" }

enum PhoneScheduleSurface: Hashable { case tasks, calendar }

@MainActor
final class PhoneWorkspaceModel: ObservableObject {
    @Published private(set) var document: WorkspaceDocument?
    @Published private(set) var failure: String?
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var taskTimestampSort: TaskTimestampSort?
    @Published private(set) var taskCountdownEnabled = false
    @Published private(set) var groupsByCreationDate = false
    @Published private(set) var activeDraft: TaskFieldDraft?
    @Published private(set) var recoveredDraft: TaskFieldDraft?
    @Published private(set) var protectedDraft = false
    @Published private(set) var isBusy = false
    @Published private(set) var editorError: String?
    @Published private(set) var recoveryStatus = ""
    @Published private(set) var captureDraft: TaskCaptureDraft?
    @Published private(set) var recoveredCapture: TaskCaptureDraft?
    @Published private(set) var protectedCapture = false
    @Published private(set) var captureError: String?
    @Published private(set) var captureRecoveryStatus = ""
    @Published private(set) var createdTaskID: UUID?
    @Published private(set) var creationNotice: String?
    @Published private(set) var lifecycleNotice: String?
    private struct ScheduleFeedback {
        let message: String
        let undo: WorkspaceCalendarUndo?
    }

    @Published private var scheduleFeedback: [PhoneScheduleSurface: ScheduleFeedback] = [:]
    @Published private var lifecycleUndo: WorkspaceLifecycleUndo?
    @Published var captureIsComposing = false
    @Published var confirmCaptureDiscard = false
    @Published var captureRecoveryPrompt = false
    private var captures: CaptureDraftStore?
    private var pendingCaptureScratch: Task<Void, Never>?
    @Published var isComposing = false
    @Published var confirmDiscard = false
    @Published var recoveryPrompt = false
    private var repository: WorkspaceFileRepository?
    private var drafts: FieldDraftStore?
    private var pendingScratch: Task<Void, Never>?
    private var opened = false
    private var readTicket = UUID()
    private let qaCase: PhoneQACase
    private var injectedStale = false
    let directory: URL?
    let isQA: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TaskovskyMobile", isDirectory: true)
        let flags = arguments.indices.filter { arguments[$0] == "--qa-session" }
        let caseFlags = arguments.indices.filter { arguments[$0] == "--qa-case" }
        let chosenCase = caseFlags.first.flatMap { $0 + 1 < arguments.count ? PhoneQACase(rawValue: arguments[$0 + 1]) : nil }
        qaCase = chosenCase ?? .known
        if caseFlags.count > 1 || (!caseFlags.isEmpty && (flags.count != 1 || chosenCase == nil)) {
            directory = nil; isQA = false; return
        }
        if arguments.contains(where: { $0 == "--workspace" || $0 == "--settings" || ($0.hasPrefix("--qa-") && $0 != "--qa-session" && $0 != "--qa-case") || $0.hasPrefix("--workspace=") || $0.hasPrefix("--settings=") }) || flags.count > 1 {
            directory = nil; isQA = false
        } else if let index = flags.first {
            #if DEBUG
            if index + 1 < arguments.count, let id = UUID(uuidString: arguments[index + 1]) {
                directory = support.appendingPathComponent("QA", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
                isQA = true
            } else { directory = nil; isQA = true }
            #else
            directory = nil; isQA = false
            #endif
        } else { directory = support.appendingPathComponent("Local", isDirectory: true); isQA = false }
    }
    var now: Date { isQA ? MobilePreviewFixture.now : Date() }
    var calendar: Calendar {
        var value = document?.snapshot.settings.calendar ?? .current
        if isQA { value.timeZone = TimeZone(identifier: "Europe/Moscow")! }
        return value
    }
    var canBeginEditing: Bool {
        document?.allowsKnownFieldWrites == true && activeDraft == nil && recoveredDraft == nil && !protectedDraft && captureDraft == nil && recoveredCapture == nil && !protectedCapture && !isBusy
    }
    var staleDraft: Bool {
        guard let activeDraft, let document else { return activeDraft != nil }
        return activeDraft.baseRevision != document.revision
    }
    var canSave: Bool {
        guard let draft = activeDraft, let document else { return false }
        return document.allowsKnownFieldWrites && !isBusy && !isComposing && !staleDraft &&
            (draft.field != .title || !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    private var searchHistoryKey: String? {
        guard let directory else { return nil }
        return isQA ? "TaskovskyMobile.qaSearches." + directory.lastPathComponent : "TaskovskyMobile.recentSearches"
    }

    private var taskTimestampSortKey: String? {
        guard let directory else { return nil }
        return isQA ? "TaskovskyMobile.qaTaskSort." + directory.lastPathComponent : "TaskovskyMobile.taskSort"
    }

    private var taskCountdownKey: String? {
        guard let directory else { return nil }
        return isQA ? "TaskovskyMobile.qaTaskCountdown." + directory.lastPathComponent : "TaskovskyMobile.taskCountdown"
    }

    func setTaskCountdownEnabled(_ enabled: Bool) {
        guard let key = taskCountdownKey, enabled != taskCountdownEnabled else { return }
        taskCountdownEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: key)
    }

    func setTaskTimestampSort(_ value: TaskTimestampSort?) {
        guard let key = taskTimestampSortKey, value != taskTimestampSort else { return }
        taskTimestampSort = value
        UserDefaults.standard.set(value?.rawValue, forKey: key)
    }

    private var taskCreatedGroupingKey: String? {
        guard let directory else { return nil }
        return isQA ? "TaskovskyMobile.qaCreatedGrouping." + directory.lastPathComponent : "TaskovskyMobile.taskGroupByCreated"
    }

    func setTaskCreatedGrouping(_ enabled: Bool) {
        guard let key = taskCreatedGroupingKey, enabled != groupsByCreationDate else { return }
        groupsByCreationDate = enabled
        UserDefaults.standard.set(enabled, forKey: key)
    }

    func rememberSearch(_ query: String) {
        guard let key = searchHistoryKey, !query.isEmpty else { return }
        recentSearches.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        recentSearches.insert(query, at: 0)
        recentSearches = Array(recentSearches.prefix(10))
        UserDefaults.standard.set(recentSearches, forKey: key)
    }

    func clearSearchHistory() {
        guard let key = searchHistoryKey else { return }
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    func open() async {
        guard !opened else { return }; opened = true
        guard let directory else { failure = "The requested test workspace is invalid. No local files were opened."; return }
        if let key = searchHistoryKey { recentSearches = UserDefaults.standard.stringArray(forKey: key) ?? [] }
        if let key = taskTimestampSortKey, let raw = UserDefaults.standard.string(forKey: key) {
            taskTimestampSort = TaskTimestampSort(rawValue: raw)
        }
        if let key = taskCountdownKey { taskCountdownEnabled = UserDefaults.standard.bool(forKey: key) }
        if let key = taskCreatedGroupingKey { groupsByCreationDate = UserDefaults.standard.bool(forKey: key) }
        readTicket = UUID(); isBusy = true
        do {
            var initial = try MobilePreviewFixture.session(samples: isQA && qaCase != .captureEmpty, unknownData: qaCase == .unknownWorkspace)
            if isQA && (qaCase == .taskSort || qaCase == .createdGrouping) {
                var data = initial.workspace
                guard data.tasks.count == 8, let work = data.lists.first else { throw CocoaError(.fileReadCorruptFile) }
                let stamp = MobilePreviewFixture.now.addingTimeInterval(-86_400)
                data.tasks[0].listID = work.id
                data.tasks[0].createdAt = stamp.addingTimeInterval(-7200)
                data.tasks[0].updatedAt = stamp.addingTimeInterval(7200)
                data.tasks[1].createdAt = stamp.addingTimeInterval(1800)
                data.tasks[1].updatedAt = stamp.addingTimeInterval(1800)
                data.tasks[7].createdAt = stamp.addingTimeInterval(-3600)
                data.tasks[7].updatedAt = stamp.addingTimeInterval(3600)
                data.tasks[5].isPinned = true
                if qaCase == .createdGrouping {
                    data.tasks[0].createdAt = stamp.addingTimeInterval(-86_400)
                    let section = TaskSection(name: "Review section")
                    let create = TaskSectionChange(listID: work.id, operation: .create(section))
                    let assign = TaskSectionChange(listID: work.id, operation: .assign(taskID: data.tasks[0].id, sectionID: section.id))
                    guard create.apply(to: &data, now: stamp) == true,
                          assign.apply(to: &data, now: stamp) == true else { throw CocoaError(.fileReadCorruptFile) }
                }
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .captureTemplate {
                var data = initial.workspace; let source = data.tasks[0]
                data.templates = [TaskTemplate(name: "Styled project", title: "Template project", body: source.body,
                                               checklist: [.init(title: "Review the plan", isCompleted: true)], priority: .high,
                                               richBody: source.richBody, customRecurrence: CustomRecurrence(),
                                               scheduledDuration: data.tasks[1].scheduledDuration)]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .lifecycle {
                var data = initial.workspace
                guard data.tasks.count == 8, data.lists.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
                let rootID = data.tasks[0].id
                data.tasks[0].recurrence = .daily
                data.tasks[1].parentID = rootID
                data.tasks[1].listID = nil
                data.tasks[3].parentID = rootID
                data.tasks[3].completedAt = MobilePreviewFixture.now.addingTimeInterval(-7_200)
                data.tasks[4].parentID = rootID
                data.tasks[4].listID = nil
                data.tasks[4].deletedAt = MobilePreviewFixture.now.addingTimeInterval(-3_600)
                data.tasks[6].kind = .note
                data.lists[1].isArchived = true
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .arrange {
                var data = initial.workspace
                guard data.tasks.count == 8 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[2].priority = .high
                data.tasks[3].dueDate = MobilePreviewFixture.now.addingTimeInterval(-86_400)
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && (qaCase == .occurrence || qaCase == .skipOccurrence || qaCase == .skipOccurrenceSaveFailure) {
                var data = initial.workspace
                guard !data.tasks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[0].recurrence = .weekly
                var settingsBytes = initial.settingsBytes
                if qaCase == .skipOccurrence || qaCase == .skipOccurrenceSaveFailure {
                    guard let due = data.tasks[0].dueDate else { throw CocoaError(.fileReadCorruptFile) }
                    data.tasks[0].recurrenceEndDate = due.addingTimeInterval(7 * 86_400)
                    data.tasks[0].reminderDates = [due - 3_600]
                    data.tasks[0].reminderFollowsSchedule = false
                    var settings = initial.settings
                    settings.calendarOptions.mode = .month
                    settingsBytes = try JSONEncoder().encode(settings)
                }
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: settingsBytes)
            }
            if isQA && qaCase == .agenda {
                var data = initial.workspace
                guard data.tasks.count > 2 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[2].dueDate = MobilePreviewFixture.now.addingTimeInterval(60 * 86_400)
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .allDaySpans {
                var data = initial.workspace
                var calendar = initial.settings.calendar
                calendar.timeZone = self.calendar.timeZone
                let firstDay = CalendarDates.weekStart(MobilePreviewFixture.now, calendar: calendar)
                let days = CalendarDates.days(from: firstDay, count: 3, calendar: calendar)
                guard days.count == 3, let work = data.lists.first else { throw CocoaError(.fileReadCorruptFile) }
                let ranges = [("Three-day workshop", days[0]), ("Two-day review", days[1])]
                data.tasks = ranges.map { title, start in
                    TaskItem(title: title, listID: work.id, dueDate: days[2],
                             scheduledDuration: TaskDurationRange(start: start, end: days[2], isAllDay: true))
                }
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .monthBrowse {
                var data = initial.workspace
                var settings = initial.settings
                let calendar = self.calendar
                let month = CalendarDates.monthStart(MobilePreviewFixture.now, calendar: calendar)
                let samples = [(-1, 12, "October review"), (0, 8, "November plan"), (1, 13, "December plan"),
                               (2, 10, "January review"), (4, 8, "March planning")]
                data.tasks = try samples.map { months, days, title in
                    guard let date = calendar.date(byAdding: DateComponents(month: months, day: days), to: month) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    return TaskItem(title: title, dueDate: date)
                }
                settings.calendarOptions.mode = .month
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data),
                                                        settingsBytes: JSONEncoder().encode(settings))
            }
            if isQA && qaCase == .monthSpans {
                var data = initial.workspace
                var calendar = initial.settings.calendar
                calendar.timeZone = self.calendar.timeZone
                let firstDay = CalendarDates.weekStart(MobilePreviewFixture.now, calendar: calendar)
                let days = CalendarDates.days(from: firstDay, count: 9, calendar: calendar)
                guard days.count == 9, let work = data.lists.first else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks = [TaskItem(title: "Weekend retreat", listID: work.id, dueDate: days[8],
                                      scheduledDuration: .init(start: days[4], end: days[8], isAllDay: true)),
                              TaskItem(title: "Weekend review", listID: work.id, dueDate: days[7],
                                      scheduledDuration: .init(start: days[5], end: days[7], isAllDay: true)),
                              TaskItem(title: "Weekend call", listID: work.id, dueDate: days[5])]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .foldedHours {
                var data = initial.workspace
                guard data.tasks.count > 3 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[2].dueDate = MobilePreviewFixture.now.addingTimeInterval(-19_800)
                data.tasks[2].hasDueTime = true
                data.tasks[3].dueDate = MobilePreviewFixture.now.addingTimeInterval(36_000)
                data.tasks[3].hasDueTime = true
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && (qaCase == .summary || qaCase == .summaryFields || qaCase == .summarySaveFailure) {
                var settings = initial.settings
                settings.smartListVisibility[.summary] = .show
                settings.defaultListID = initial.workspace.lists.first?.id
                settings.defaultTagID = initial.workspace.tags.first?.id
                settings.defaultDate = .today
                settings.defaultPriority = .high
                var data = initial.workspace
                if qaCase == .summaryFields {
                    guard data.tasks.count >= 4, let parent = data.tags.first else { throw CocoaError(.fileReadCorruptFile) }
                    let nested = TaskTag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000209")!,
                                         name: "Nested planning", color: "#445566", parentID: parent.id)
                    data.tags.append(nested)
                    data.tasks[0] = try TaskMetadataChange.progress(40).applying(to: data.tasks[0], availableTags: data.tags) ?? data.tasks[0]
                    data.tasks[0].completedAt = MobilePreviewFixture.now
                    data.tasks[0].priority = .high
                    data.tasks[0].tagIDs = [nested.id]
                    data.tasks[1].checklist = (1...4).map { ChecklistItem(title: "Step \($0)", isCompleted: $0 == 1) }
                    data.tasks[1].priority = .high
                    data.tasks[1].tagIDs = [parent.id]
                    data.tasks[2].dueDate = MobilePreviewFixture.now
                    data.tasks[2].priority = .medium
                    data.tasks[2].tagIDs = [parent.id]
                    data.tasks[3].priority = .high
                    data.tasks[3].tagIDs = []
                }
                let bytes = qaCase == .summaryFields ? try JSONEncoder().encode(data) : initial.workspaceBytes
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: bytes, settingsBytes: JSONEncoder().encode(settings))
            }
            if isQA && qaCase == .board {
                var data = initial.workspace
                guard data.tasks.count == 8, data.lists.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
                let archive = TaskList(id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
                                       name: "Reference Board", color: "#4E64D8", viewMode: .board, isArchived: true)
                data.lists.append(archive)
                data.tasks[1].recurrence = .daily
                data.tasks[1].wontDoAt = MobilePreviewFixture.now.addingTimeInterval(-7_200)
                data.tasks[2].listID = archive.id
                data.tasks[2].completedAt = MobilePreviewFixture.now.addingTimeInterval(-3_600)
                data.tasks[4].listID = data.lists[0].id
                data.tasks[4].kind = .note
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && (qaCase == .timeline || qaCase == .timelineArrange) {
                var data = initial.workspace
                guard data.lists.count == 2, data.tasks.count == 8 else { throw CocoaError(.fileReadCorruptFile) }
                let folder = ListFolder(name: "Launch projects")
                let archive = TaskList(name: "Old projects", color: "#4E64D8", folderID: folder.id, isArchived: true)
                data.folders.append(folder)
                data.lists[0].folderID = folder.id
                if qaCase == .timeline {
                    let build = TaskSection(name: "Build")
                    let review = TaskSection(name: "Review")
                    let work = data.lists[0].id
                    data.tasks[0].listID = work
                    let operations: [TaskSectionChange.Operation] = [
                        .create(build), .create(review), .assign(taskID: data.tasks[0].id, sectionID: build.id),
                        .assign(taskID: data.tasks[1].id, sectionID: review.id)
                    ]
                    for operation in operations {
                        guard TaskSectionChange(listID: work, operation: operation).apply(to: &data, now: now) == true else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                    }
                }
                data.lists.append(archive)
                data.tasks[4].listID = archive.id
                data.tasks[5].listID = data.lists[1].id
                data.tasks[7].dueDate = nil
                data.filters = [TaskFilter(name: "Work and Personal", listIDs: [data.lists[0].id, data.lists[1].id, archive.id])]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .tagOrganization {
                var data = initial.workspace
                var settings = initial.settings
                guard let source = data.tags.first, !data.tasks.isEmpty, !data.filters.isEmpty else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let target = TaskTag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                                     name: "Sprint", color: "#4E64D8", parentID: source.id)
                let sibling = TaskTag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                                      name: "Review group", color: "#4E64D8", parentID: source.id)
                data.tags += [target, sibling]
                data.tasks[0].tagIDs = [source.id, target.id]
                data.templates = [TaskTemplate(name: "Tagged example", title: "Review notes", tagIDs: [source.id, target.id])]
                data.filters[0].name = "Tagged review"
                data.filters[0].tagIDs = [source.id, target.id]
                data.filters[0].ruleRoot = .and([.condition(.init(kind: .tag, tagID: source.id)),
                                                 .condition(.init(kind: .tag, tagID: target.id))])
                settings.defaultTagID = source.id
                let encoder = JSONEncoder()
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: encoder.encode(data), settingsBytes: encoder.encode(settings))
            }
            if isQA && qaCase == .savedFilter {
                var data = initial.workspace
                guard !data.filters.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                let missingList = UUID(uuidString: "00000000-0000-0000-0000-000000000598")!
                let missingTag = UUID(uuidString: "00000000-0000-0000-0000-000000000599")!
                data.filters[0].name = "Unavailable work"
                data.filters[0].listIDs = [missingList]
                data.filters[0].tagIDs = [missingTag]
                data.filters[0].ruleRoot = .and([.condition(.init(kind: .list, listID: missingList)),
                                                 .not(.condition(.init(kind: .tag, tagID: missingTag)))])
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .organization {
                var data = initial.workspace
                guard data.tasks.count == 8, let work = data.lists.first?.id, !data.filters.isEmpty else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                data.tasks[0].listID = work
                data.tasks[0].checklist = [ChecklistItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
                                                         title: "Review the first step", isCompleted: true)]
                data.tasks[1].parentID = data.tasks[0].id
                data.tasks[7].deletedAt = MobilePreviewFixture.now.addingTimeInterval(-3_600)
                data.filters[0].name = "Original Work only"
                data.filters[0].listIDs = [work]
                data.filters[0].tagIDs = []
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && (qaCase == .calendarOptions || qaCase == .calendarCompletion) {
                var data = initial.workspace
                var settings = initial.settings
                guard data.tasks.count == 8 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[0].recurrence = .daily
                data.tasks[0].checklist = [ChecklistItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!, title: "Review the first step")]
                data.tasks[3].completedAt = MobilePreviewFixture.now
                settings.calendarOptions.additionalTimeZones = Array(settings.calendarOptions.additionalTimeZones.prefix(2))
                if qaCase == .calendarCompletion {
                    data.tasks[0].checklist.append(ChecklistItem(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
                        title: "Keep the second step"))
                    data.tasks[7].kind = .note
                    settings.calendarOptions.mode = .agenda
                    settings.calendarOptions.showChecklistItems = true
                    settings.calendarOptions.showCompleted = true
                    settings.calendarOptions.showRepeatCycles = true
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: encoder.encode(data), settingsBytes: encoder.encode(settings))
            }
            if isQA && qaCase == .batchPostpone {
                var data = initial.workspace
                var settings = initial.settings
                guard data.tasks.count == 8, let work = data.lists.first(where: { $0.name == "Work" }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let now = MobilePreviewFixture.now
                data.tasks[1].reminderDates = [now + 6_600]
                data.tasks[1].reminderFollowsSchedule = false
                data.tasks[4].hasDueTime = true
                data.tasks[5].dueDate = now + 86_400 + 1_800
                data.tasks[5].hasDueTime = true
                data.tasks[5].recurrence = .weekly
                settings.calendarOptions.selectOnlyList(work.id)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: encoder.encode(data), settingsBytes: encoder.encode(settings))
            }
            if isQA && qaCase == .taskMetadata {
                var data = initial.workspace
                guard data.tasks.count == 8 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[0].tagIDs = [UUID(uuidString: "00000000-0000-0000-0000-000000000599")!]
                data.tasks[0].checklist = [
                    ChecklistItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!, title: "First step"),
                    ChecklistItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!, title: "Second step")
                ]
                data.tasks[3].parentID = data.tasks[0].id
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            #if DEBUG
            if isQA && qaCase == .shortCalendarMove {
                var data = initial.workspace
                guard !data.tasks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                let start = MobilePreviewFixture.now.addingTimeInterval(-8_100)
                let end = start.addingTimeInterval(323)
                data.tasks[0].scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: false)
                data.tasks[0].dueDate = end
                data.tasks[0].hasDueTime = true
                data.tasks[0].reminderDate = start.addingTimeInterval(-600)
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            #endif
            #if DEBUG
            if isQA && (qaCase == .richPreview || qaCase == .malformedRich) {
                var data = initial.workspace
                guard !data.tasks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                if qaCase == .richPreview {
                    let rich = MobilePreviewFixture.styledDescription
                    data.tasks[0].body = rich.text
                    data.tasks[0].richBody = rich
                } else {
                    guard var rich = data.tasks[0].richBody, !rich.runs.isEmpty else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    rich.runs[0].length = Int.max
                    data.tasks[0].richBody = rich
                }
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .richPlainPaste {
                var data = initial.workspace
                guard let task = data.tasks.first, let word = task.body.split(separator: " ").first,
                      let pasteboard = RichEditorTextView.pasteboard(for: directory.lastPathComponent) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                data.tasks[0].richBody = RichBody(text: task.body, runs: [.init(location: 0, length: word.utf16.count, bold: true)])
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
                pasteboard.string = String(word)
            }
            if isQA && (qaCase == .richForeignPaste || qaCase == .richForeignHTMLBlocks || qaCase == .richForeignRTFPaste) {
                var data = initial.workspace
                guard data.tasks.count > 1,
                      let pasteboard = RichEditorTextView.pasteboard(for: directory.lastPathComponent) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                for index in 0...1 {
                    data.tasks[index].body = "Prior"
                    data.tasks[index].richBody = nil
                }
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
                let item: [String: Any]
                if qaCase == .richForeignPaste {
                    let plain = "Bold 🧩 italic e\u{301}\nReview safe **literal**"
                    let html = """
                    <p><strong>Bold 🧩 <em>italic e&#769;</em></strong></p>
                    <p><a href="https://example.test/review">Review</a>
                      <a href="file:///taskovsky-fixture.txt">safe</a> **literal**</p>
                    """
                    item = [UTType.utf8PlainText.identifier: plain, UTType.html.identifier: Data(html.utf8)]
                } else if qaCase == .richForeignHTMLBlocks {
                    let plain = "Review 🧩\nA quoted e\u{301}\nOne bullet\nFirst number\n  let value = 1\n\n  print(value)\nPlain end"
                    let html = "<h2>Review 🧩</h2><blockquote>A <em>quoted</em> e&#769;</blockquote>" +
                        "<ul><li>One bullet</li></ul><ol><li>First number</li></ol>" +
                        "<pre><code>  let value = 1\n\n  print(value)</code></pre><p>Plain end</p>"
                    item = [UTType.utf8PlainText.identifier: plain, UTType.html.identifier: Data(html.utf8)]
                } else {
                    let rtf = #"{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\f0\fs24\b Bold\b0  \i italic\i0}"#
                    item = [UTType.rtf.identifier: Data(rtf.utf8)]
                }
                pasteboard.setItems([item], options: [.localOnly: true])
            }
            if isQA && (qaCase == .richMarkdownPaste || qaCase == .richCodePaste) {
                var data = initial.workspace
                guard data.tasks.count > 1,
                      let pasteboard = RichEditorTextView.pasteboard(for: directory.lastPathComponent) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                data.tasks[0].body = "Prior"
                data.tasks[0].richBody = nil
                data.tasks[1].body = "Prior"
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
                pasteboard.string = qaCase == .richCodePaste
                    ? "```\n  let value = **e\u{301} 🧩**\nprint(value)\n```"
                    : "## Plan **e\u{301} 🧩**\n- First\n1. Open\n2. Review\n> Reference\nhttps://example.test/task *literal*"
            }
            if isQA && qaCase == .richHighlightColors {
                var data = initial.workspace
                guard data.tasks.count > 1 else { throw CocoaError(.fileReadCorruptFile) }
                data.tasks[0].body = "Alpha Beta"
                data.tasks[0].richBody = RichBody(text: data.tasks[0].body, runs: [
                    .init(location: 0, length: 5, bold: true), .init(location: 6, length: 4, highlight: true),
                ])
                data.tasks[1].body = "Prior"
                data.tasks[1].richBody = nil
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .richChecklistToggle {
                var data = initial.workspace
                guard !data.tasks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                let first = "First 🧩\n", second = "Second e\u{301}\n", plain = "Ordinary text\n", bullet = "Bullet"
                let text = first + second + plain + bullet
                data.tasks[0].body = text
                data.tasks[0].richBody = RichBody(text: text, runs: [.init(location: 0, length: 5, bold: true)], blocks: [
                    .init(location: 0, length: first.utf16.count, list: .checklist),
                    .init(location: first.utf16.count, length: second.utf16.count, list: .checklist, checked: true),
                    .init(location: (first + second + plain).utf16.count, length: bullet.utf16.count, list: .bullet),
                ])
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            #endif
            let wasNew = !FileManager.default.fileExists(atPath: directory.appendingPathComponent("workspace.json").path) &&
                !FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.json").path)
            let bootstrap = initial
            try await Task.detached { try WorkspaceBootstrap.prepare(directory: directory, initial: bootstrap) }.value
            let repo: WorkspaceFileRepository
            if isQA && (qaCase == .saveFailure || qaCase == .summarySaveFailure || qaCase == .skipOccurrenceSaveFailure) {
                repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"), write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
            } else if isQA && qaCase == .afterWrite {
                repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"), write: { bytes, url in
                    try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); throw CocoaError(.fileWriteUnknown)
                })
            } else { repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json")) }
            if isQA && wasNew && qaCase == .unknownDraft {
                try Data(#"{"version":99,"opaque":"Retain original"}"#.utf8).write(to: directory.appendingPathComponent("field-draft.json"), options: .atomic)
            }
            if isQA && wasNew {
                try initial.workspaceBytes.write(to: directory.appendingPathComponent("initial-workspace.json"), options: .atomic)
                try initial.settingsBytes.write(to: directory.appendingPathComponent("initial-settings.json"), options: .atomic)
            }
            repository = repo; drafts = FieldDraftStore(fileURL: directory.appendingPathComponent("field-draft.json"))
            captures = CaptureDraftStore(fileURL: directory.appendingPathComponent("capture-draft.json"))
            document = try await repo.load(); failure = nil
            await readRecovery(); await readCaptureRecovery()
            recoveryPrompt = recoveredDraft != nil
            captureRecoveryPrompt = recoveredDraft == nil && recoveredCapture != nil
        } catch { document = nil; failure = "The workspace could not be opened. Existing files have been kept. Retry when storage is available." }
        isBusy = false
    }
    func retryOpen() async { guard !isBusy else { return }; opened = false; await open() }
    func refresh() async {
        guard let repository, !isBusy else { return }
        let ticket = UUID(); readTicket = ticket
        do {
            let value = try await repository.load()
            guard ticket == readTicket, !isBusy else { return }
            document = value; failure = nil
        } catch {
            guard ticket == readTicket, !isBusy else { return }
            document = nil; failure = "The workspace could not be read. Your files and any open edit have been kept."
        }
    }

    func saveCalendarOptions(_ options: TaskCalendarOptions, expected: WorkspaceRevision) async -> String? {
        guard !isBusy, let repository else { return "The workspace is busy. Try again." }
        guard activeDraft == nil, recoveredDraft == nil, !protectedDraft,
              captureDraft == nil, recoveredCapture == nil, !protectedCapture else {
            return "Resolve the pending task edit before saving Calendar preferences."
        }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.saveCalendarOptions(options, expected: expected) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .stale:
            if let latest = try? await repository.load() { document = latest }
            return "Saved preferences changed. Open this editor again to review them."
        case .incompatible: return "This build cannot safely replace the saved Calendar preferences."
        case .invalid: return "Review the Calendar ranges and time zones before saving."
        case .persistenceFailed: return "Could not confirm the Calendar preference save. You can retry."
        }
    }

    func saveSmartLists(_ draft: AppSettings, expected: WorkspaceRevision) async -> String? {
        guard !isBusy, let repository else { return "The workspace is busy. Try again." }
        guard activeDraft == nil, recoveredDraft == nil, !protectedDraft,
              captureDraft == nil, recoveredCapture == nil, !protectedCapture else {
            return "Resolve the pending task edit before saving Smart Lists."
        }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.saveSmartLists(draft, expected: expected) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .stale:
            if let latest = try? await repository.load() { document = latest }
            return "Saved preferences changed. Open this editor again to review them."
        case .incompatible: return "This build cannot safely edit these saved Smart List preferences."
        case .invalid: return "Review the Smart List choices before saving."
        case .persistenceFailed: return "Could not save Smart Lists. You can retry."
        }
    }

    func saveLocalPreferences(_ draft: LocalWorkspacePreferences, expected: WorkspaceRevision) async -> String? {
        guard !isBusy, let repository else { return "The workspace is busy. Try again." }
        guard activeDraft == nil, recoveredDraft == nil, !protectedDraft,
              captureDraft == nil, recoveredCapture == nil, !protectedCapture else {
            return "Resolve the pending task edit before saving local settings."
        }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.saveLocalPreferences(draft, expected: expected) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .stale:
            if let latest = try? await repository.load() { document = latest }
            return "Saved preferences changed. Open this editor again to review them."
        case .incompatible: return "This build cannot safely edit these saved local settings."
        case .invalid: return "Review the local settings choices before saving."
        case .persistenceFailed: return "Could not save local settings. You can retry."
        }
    }

    func saveTaskMetadata(_ command: TaskMetadataChange, taskID: UUID,
                          expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(.metadata(command), to: taskID, expected: expected, now: now) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen this editor to review the current task."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused(.metadata(.emptyChecklistTitle)):
            return "Enter a title for each changed checklist item."
        case .refused(.metadata(.unavailableTag)):
            return "Select available tags before saving."
        case .refused(.metadata(.unavailableProgress)):
            return "This task no longer supports manual progress."
        case .refused(.metadata(.invalidProgress)):
            return "Choose a percentage from 0 to 100."
        case .refused(.metadata(.ambiguousChecklist)):
            return "This checklist contains ambiguous item identities."
        case .refused(.metadata(.missingChecklistItem)), .refused(.missing), .refused(.readOnlyRecord):
            return "This task or checklist item is no longer editable."
        case .refused(.emptyTitle), .refused(.styledBody), .refused(.richBody), .refused(.batch):
            return "The task edit could not be applied."
        case .persistenceFailed:
            return "Could not save the task change. You can retry."
        }
    }

    func saveBatch(_ edit: TaskBatchEdit, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(edit, expected: expected, now: now, calendar: calendar) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Close this sheet and select tasks again."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused(.batch(let reason)): return reason.batchMessage
        case .refused: return "The selected tasks could not be changed."
        case .persistenceFailed: return "Could not save the batch change. You can retry."
        }
    }

    func saveOrganization(_ command: ListOrganizationCommand, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(command, expected: expected, now: now) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen this editor to review the current lists and folders."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused:
            return "The list or folder is unavailable, or the proposed change is invalid."
        case .persistenceFailed:
            return "Could not save the change. You can retry."
        }
    }

    func saveSection(_ change: TaskSectionChange) async -> String? {
        guard canBeginEditing, let repository, let revision = document?.revision
        else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(change, expected: revision, now: now) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Review the current sections and try again."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused:
            return "This section or task is no longer editable."
        case .persistenceFailed:
            return "Could not save the section change. You can retry."
        }
    }

    func saveTag(_ command: TagOrganizationCommand, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(command, expected: expected, now: now) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen this tag to review it."
        case .refused(.compatibility): return "This workspace contains data this build cannot safely rewrite."
        case .refused: return "Check the tag name and parent. The name must be unique and the parent cannot create a cycle."
        case .persistenceFailed: return "Could not confirm the tag change. Reopen the workspace to review it before retrying."
        }
    }

    func saveTemplate(_ command: TaskTemplateChange, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(command, expected: expected, now: now, calendar: calendar) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen the template action and try again."
        case .refused(.compatibility): return "This workspace contains data this build cannot safely rewrite."
        case .refused: return "Check the template fields, formatting and destination task."
        case .persistenceFailed: return "Could not save the template change. You can retry."
        }
    }

    func saveFilter(_ command: SavedFilterChange, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(command, expected: expected) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen the filter to review the current rules."
        case .refused(.compatibility): return "This workspace contains data this build cannot safely rewrite."
        case .refused: return "Check the filter name, dates, and saved record."
        case .persistenceFailed: return "Could not save the filter. You can retry."
        }
    }

    func saveSchedule(_ edit: TaskScheduleEdit, expected: WorkspaceRevision) async -> String? {
        await commitSchedule { await $0.apply(edit, expected: expected, now: now) }
    }

    func skipTaskOccurrence(taskID: UUID, expected: WorkspaceRevision) async -> String? {
        await commitSchedule(feedback: (.tasks, "Occurrence skipped")) {
            await $0.apply(.skipOccurrence, to: taskID, expected: expected, calendar: calendar, scope: .series, now: now)
        }
    }

    func saveCalendarSchedule(_ operation: CalendarScheduleOperation, taskID: UUID,
                              expected: WorkspaceRevision, scope: CalendarScheduleScope = .series) async -> String? {
        let message: String
        if case .skipOccurrence = operation { message = "Occurrence skipped" }
        else { message = scope == .currentOccurrence ? "This occurrence updated" : "Schedule updated" }
        return await commitSchedule(feedback: (.calendar, message)) {
            await $0.apply(operation, to: taskID, expected: expected, calendar: calendar, scope: scope, now: now)
        }
    }

    func scheduleNotice(in surface: PhoneScheduleSurface) -> String? {
        scheduleFeedback[surface]?.message
    }

    func canUndoSchedule(in surface: PhoneScheduleSurface) -> Bool {
        guard canBeginEditing, let undo = scheduleFeedback[surface]?.undo, let document else { return false }
        return undo.canRestore(in: document.snapshot.workspace)
    }

    func undoSchedule(in surface: PhoneScheduleSurface) async {
        guard canUndoSchedule(in: surface), let undo = scheduleFeedback[surface]?.undo else { return }
        if let error = await commitSchedule(feedback: (surface, "Schedule restored"), action: {
            await $0.undo(undo, now: now)
        }) { showScheduleError(error, in: surface) }
    }

    func dropCalendarTask(_ operation: CalendarScheduleOperation, taskID: UUID,
                          expected: WorkspaceRevision, scope: CalendarScheduleScope = .series) async {
        if let error = await saveCalendarSchedule(operation, taskID: taskID, expected: expected, scope: scope) {
            showScheduleError(error, in: .calendar)
        }
    }

    private func showScheduleError(_ message: String, in surface: PhoneScheduleSurface) {
        scheduleFeedback[surface] = ScheduleFeedback(message: message, undo: scheduleFeedback[surface]?.undo)
    }

    private func commitSchedule(feedback: (surface: PhoneScheduleSurface, message: String)? = nil,
                                action: (WorkspaceFileRepository) async -> WorkspaceScheduleOutcome) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await action(repository) {
        case .saved(let saved, let undo):
            document = saved
            if let feedback {
                scheduleFeedback[feedback.surface] = ScheduleFeedback(message: feedback.message, undo: undo)
            }
            return nil
        case .unchanged(let current):
            document = current
            return nil
        case .refused(.stale), .refused(.invalid(.changedTask)):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Open the schedule again to edit the current task."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused(.invalid(.invalidDuration)), .refused(.invalidCalendarOperation):
            return "The schedule has an invalid date or range."
        case .refused(.invalid(.invalidTimeZone)):
            return "Choose a supported time zone in the task's Schedule."
        case .refused(.invalid(.invalidRepeat)):
            return "Edit or explicitly replace the invalid repeat rule in the task's Schedule."
        case .refused(.missing), .refused(.readOnlyRecord):
            if let latest = try? await repository.load() { document = latest }
            return "Scheduling is unavailable for this task."
        case .refused(.changedSinceCalendarEdit):
            if let latest = try? await repository.load() { document = latest }
            return "The schedule or task status changed since this edit."
        case .persistenceFailed:
            return feedback == nil
                ? "Could not confirm the save. Your edits are still here."
                : "Could not confirm the save. Review the schedule before retrying."
        }
    }

    var canUndoLifecycle: Bool {
        canBeginEditing && lifecycleUndo?.revision == document?.revision && lifecycleUndo != nil
    }

    @discardableResult
    func performLifecycle(_ command: TaskLifecycleCommand, taskID: UUID,
                          expected: WorkspaceRevision, fromSubtaskRow: Bool = false) async -> Bool {
        guard canBeginEditing, let repository else { return false }
        readTicket = UUID()
        isBusy = true
        let outcome = await repository.apply(command, to: taskID, expected: expected, calendar: calendar)
        let message: String = switch command {
        case .complete, .completeFromWontDo: fromSubtaskRow ? "Subtask completed" : "Task completed"
        case .undoBoardCompletionToWontDo: "Change undone"
        case .reopen: fromSubtaskRow ? "Subtask reopened" : "Task reopened"
        case .wontDo: "Marked Won't Do"
        case .trash: "Moved to Trash"
        case .restore: "Restored"
        case .purge: "Deleted forever"
        case .setPinned(let pinned): pinned ? "Pinned" : "Unpinned"
        case .move: "Moved to list"
        case .setParent(let parentID): parentID == nil ? "Moved to top level" : "Parent task changed"
        case .addSubtask: "Subtask added"
        case .duplicate: "Duplicated"
        case .setKind(let kind): kind == .note ? "Converted to note" : "Converted to task"
        }
        return await finishLifecycle(outcome, message: message)
    }

    func undoLifecycle() async {
        guard canUndoLifecycle, let repository, let lifecycleUndo else { return }
        readTicket = UUID()
        isBusy = true
        let outcome = await repository.undo(lifecycleUndo)
        _ = await finishLifecycle(outcome, message: "Change undone")
    }

    private func finishLifecycle(_ outcome: WorkspaceLifecycleOutcome, message: String) async -> Bool {
        defer { isBusy = false }
        switch outcome {
        case .saved(let saved, let undo):
            document = saved
            creationNotice = nil
            lifecycleUndo = undo
            lifecycleNotice = message
            return true
        case .unchanged(let current):
            document = current
            return true
        case .refused(.stale):
            lifecycleUndo = nil
            lifecycleNotice = "The workspace changed. Review the current task and try again."
            if let repository, let latest = try? await repository.load() { document = latest }
        case .refused(.compatibility):
            lifecycleNotice = "This workspace contains data this build cannot safely rewrite."
        case .refused(.task(.invalidDestination)):
            lifecycleNotice = "Choose Inbox or an active list."
        case .refused(.task(.invalidParent)):
            lifecycleNotice = "Choose a parent task outside this task’s own subtree."
        case .refused(.task(.invalidChild)):
            lifecycleNotice = "Could not add this subtask. Check the title and current task."
        case .refused(.task):
            lifecycleNotice = "This action is unavailable for the current task."
        case .persistenceFailed:
            lifecycleNotice = "Could not confirm the change. Review the workspace before retrying."
            if let repository, let latest = try? await repository.load() { document = latest }
        }
        return false
    }
    func begin(taskID: UUID, field: TaskDraftField) async {
        guard canBeginEditing, let document, let drafts,
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == taskID }),
              task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: document.snapshot.workspace.lists),
              field != .plainBody || task.richBody == nil,
              field != .richBody || (try? RichBodyEdit.applying([], to: task.body, rich: task.richBody)) != nil else { return }
        readTicket = UUID(); isBusy = true; editorError = nil; isComposing = false
        let draft = TaskFieldDraft(taskID: taskID, field: field, baseRevision: document.revision,
                                   text: field == .title ? task.title : task.body, richBody: task.richBody)
        let result = await drafts.begin(draft)
        if result == .refused {
            await readRecovery(); editorError = "An existing saved edit must be handled before starting another."
        } else {
            activeDraft = draft
            recoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your edit is still open."
        }
        isBusy = false
    }
    func changeText(_ text: String, editorID: UUID) {
        guard !isBusy, var draft = activeDraft, draft.id == editorID, draft.field != .richBody else { return }
        guard !text.utf16.elementsEqual(draft.text.utf16) else { return }
        draft.replaceText(text)
        stageFieldEdit(draft)
    }

    @discardableResult
    func changeRich(_ edit: RichBodyEdit, editorID: UUID) -> Bool {
        updateRich(editorID: editorID) { try $0.applyRichEdit(edit) }
    }

    @discardableResult
    func restoreRichEdits(_ edits: [RichBodyEdit], editorID: UUID) -> Bool {
        updateRich(editorID: editorID) { try $0.replaceRichEdits(edits) }
    }

    private func updateRich(editorID: UUID, change: (inout TaskFieldDraft) throws -> Void) -> Bool {
        guard !isBusy, !isComposing, var draft = activeDraft, draft.id == editorID, draft.field == .richBody else { return false }
        let originalSequence = draft.sequence
        do {
            try change(&draft)
            editorError = nil
            if draft.sequence != originalSequence { stageFieldEdit(draft) }
            return true
        } catch {
            editorError = "This edit crosses a protected formatting boundary or uses an invalid link."
            return false
        }
    }

    private func stageFieldEdit(_ draft: TaskFieldDraft) {
        activeDraft = draft
        recoveryStatus = "Saving recovery copy…"
        pendingScratch?.cancel()
        pendingScratch = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.flushDraft()
        }
    }
    func flushDraft() async {
        guard let draft = activeDraft, let drafts else { return }
        let result = await drafts.save(draft)
        guard activeDraft?.id == draft.id, activeDraft?.sequence == draft.sequence else { return }
        recoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your edit is still open."
    }
    func requestCloseEditor() {
        guard let draft = activeDraft, !isBusy else { return }
        if draft.hasChanges || isComposing { confirmDiscard = true }
        else { Task { await discardActive() } }
    }
    func discardActive() async {
        guard let draft = activeDraft, let drafts, !isBusy else { return }
        readTicket = UUID(); isBusy = true; pendingScratch?.cancel()
        let result = await drafts.close(id: draft.id)
        if result == .saved { activeDraft = nil; editorError = nil; recoveryStatus = ""; isComposing = false }
        else { editorError = "The saved edit could not be discarded. Your text has been kept. Try again." }
        isBusy = false
        await refresh()
    }
    func save() async {
        guard canSave, let draft = activeDraft, let repository, let drafts else { return }
        readTicket = UUID(); isBusy = true; pendingScratch?.cancel(); editorError = nil
        _ = await drafts.save(draft)
        let patch: WorkspaceFieldPatch
        switch draft.field {
        case .title: patch = .title(draft.text)
        case .plainBody: patch = .plainBody(draft.text)
        case .richBody:
            guard let state = draft.richState else {
                editorError = "The rich description draft could not be verified."
                isBusy = false
                return
            }
            patch = .richBody(state.edits)
        }
        if isQA && qaCase == .staleSave && !injectedStale, let directory {
            injectedStale = true
            let independent = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"))
            if let latest = try? await independent.load() { _ = await independent.apply(.title("Changed elsewhere"), to: draft.taskID, expected: latest.revision) }
        }
        let outcome = await repository.apply(patch, to: draft.taskID, expected: draft.baseRevision)
        switch outcome {
        case .saved(let value), .unchanged(let value):
            document = value
            let cleanup = await drafts.close(id: draft.id)
            activeDraft = nil; isComposing = false; recoveryStatus = ""
            if cleanup != .saved { await readRecovery(); editorError = "Changes saved, but the recovery copy could not be cleared." }
        case .refused(.stale):
            editorError = "This task changed. Your text is kept. Discard to reload, or keep editing to copy it."
            do { document = try await repository.load() } catch { }
        case .refused(.compatibility): editorError = "This workspace contains data this build cannot safely rewrite. Your edit is kept."
        case .refused(.styledBody): editorError = "Formatting is protected. The description cannot be replaced with plain text."
        case .refused(.readOnlyRecord), .refused(.missing): editorError = "This task is no longer editable. Your text is kept."
        case .refused(.emptyTitle): editorError = "Enter a title before saving."
        case .refused(.metadata), .refused(.richBody), .refused(.batch): editorError = "This task edit could not be applied."
        case .persistenceFailed: editorError = "Could not save. Your edit is still here. Retry when storage is available."
        }
        isBusy = false
    }
    func resumeRecovery() {
        guard let recoveredDraft, !isBusy else { return }
        activeDraft = recoveredDraft; self.recoveredDraft = nil; editorError = nil; isComposing = false
        recoveryStatus = "Recovery copy saved"
    }
    func discardRecovery() async {
        guard let recoveredDraft, let drafts, !isBusy else { return }
        readTicket = UUID(); isBusy = true
        let result = await drafts.close(id: recoveredDraft.id)
        if result == .saved { self.recoveredDraft = nil; editorError = nil }
        else { editorError = "The saved edit could not be discarded. It has been kept." }
        isBusy = false
    }
    private func readRecovery() async {
        guard let drafts else { return }
        switch await drafts.load() {
        case .none: recoveredDraft = nil; protectedDraft = false
        case .available(let value) where value.isRecoverable:
            recoveredDraft = activeDraft?.id == value.id ? nil : value; protectedDraft = false
        case .available, .unavailable: recoveredDraft = nil; protectedDraft = true
        }
    }
    var canBeginCapture: Bool { canBeginEditing }
    var staleCapture: Bool { guard let draft = captureDraft, let document else { return captureDraft != nil }; return draft.baseRevision != document.revision }
    var capturePreview: TaskItem? {
        guard let draft = captureDraft, let document else { return nil }
        return draft.preparedTask ?? (try? draft.input.task(id: draft.id, now: draft.createdAt, workspace: document.snapshot.workspace, settings: document.snapshot.settings, calendar: draft.calendar, requireTitle: false))
    }
    var canCreate: Bool {
        captureDraft != nil && document?.allowsKnownFieldWrites == true && !isBusy && !captureIsComposing &&
            (captureDraft?.preparedTask != nil || (!staleCapture && capturePreview?.title.isEmpty == false))
    }
    func beginCapture(destination: TaskDestination, calendarDate: Date?, sectionID: UUID? = nil,
                      calendarRange: ClosedRange<Date>? = nil, useExactDate: Bool = false) async {
        guard canBeginCapture, let document else { return }
        var input = TaskCaptureInput.start(destination: destination, calendarDate: calendarDate, workspace: document.snapshot.workspace,
                                           settings: document.snapshot.settings, now: now, calendar: calendar)
        if let sectionID {
            guard document.snapshot.workspace.lists.contains(where: {
                $0.id == input.listID && !$0.isArchived && $0.sections.contains(where: { $0.id == sectionID })
            }) else { captureError = "The selected section is no longer available."; return }
            input.sectionID = sectionID
        }
        if let calendarRange { input.chooseCalendarRange(calendarRange, calendar: calendar) }
        else if useExactDate, let calendarDate { input.chooseDate(calendar.startOfDay(for: calendarDate)) }
        await stageCapture(input, in: document)
    }

    func saveSummaryNote(title: String, body: String) async -> Bool {
        guard canBeginCapture, let document else { return false }
        await stageCapture(.summaryNote(title: title, body: body), in: document)
        guard captureDraft != nil else { return false }
        await createCapturedTask()
        return createdTaskID != nil
    }

    private func stageCapture(_ input: TaskCaptureInput, in document: WorkspaceDocument) async {
        guard let captures else { return }
        readTicket = UUID(); isBusy = true; captureError = nil; creationNotice = nil; createdTaskID = nil; captureIsComposing = false
        let value = TaskCaptureDraft(baseRevision: document.revision, input: input, now: now, calendar: calendar)
        let result = await captures.begin(value)
        if result == .refused { await readCaptureRecovery(); captureError = "Handle the existing saved capture before creating another." }
        else { captureDraft = value; captureRecoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open." }
        isBusy = false
    }
    func changeCapture(id: UUID, _ change: (inout TaskCaptureInput) -> Void) {
        guard !isBusy, var value = captureDraft, value.id == id, value.preparedTask == nil else { return }
        let before = value.sequence; value.update(change)
        guard before != value.sequence else { return }
        captureDraft = value; captureRecoveryStatus = "Saving recovery copy…"; pendingCaptureScratch?.cancel()
        pendingCaptureScratch = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }; await self?.flushCapture()
        }
    }
    func flushCapture() async {
        guard let value = captureDraft, let captures else { return }
        let result = await captures.save(value)
        guard captureDraft?.id == value.id, captureDraft?.sequence == value.sequence else { return }
        captureRecoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open."
    }
    func requestCloseCapture() {
        guard let value = captureDraft, !isBusy else { return }
        if value.hasChanges { confirmCaptureDiscard = true } else { Task { await discardCapture() } }
    }
    func discardCapture() async {
        guard let value = captureDraft, let captures, !isBusy else { return }
        readTicket = UUID(); isBusy = true; pendingCaptureScratch?.cancel()
        if await captures.close(id: value.id) == .saved { captureDraft = nil; captureError = nil; captureRecoveryStatus = ""; captureIsComposing = false }
        else { captureError = "The saved capture could not be discarded. Your draft is kept. Try again." }
        isBusy = false; await refresh()
    }
    func createCapturedTask() async {
        guard canCreate, var value = captureDraft, let document, let captures, let repository else { return }
        readTicket = UUID(); isBusy = true; pendingCaptureScratch?.cancel(); captureError = nil
        let wasPrepared = value.preparedTask != nil
        do { try value.prepare(workspace: document.snapshot.workspace, settings: document.snapshot.settings) }
        catch { captureError = "Check the title, destination, tags and template before saving."; isBusy = false; return }
        captureDraft = value
        let durable: Bool
        if case .available(let saved) = await captures.load(), saved == value { durable = true }
        else { durable = await captures.save(value) == .saved }
        guard durable else {
            if !wasPrepared { value.confirmedNotSaved(); captureDraft = value }
            captureRecoveryStatus = "Recovery copy could not be saved. Your draft is still open."
            captureError = wasPrepared ? "The prior save still needs checking. Your submitted draft is kept." : "The recovery copy could not be saved. No task was submitted. Your draft is kept."
            isBusy = false; return
        }
        captureRecoveryStatus = "Recovery copy saved"
        if isQA && qaCase == .staleSave && !injectedStale, let directory {
            injectedStale = true
            let independent = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"))
            if let latest = try? await independent.load(), let task = latest.snapshot.workspace.tasks.first {
                _ = await independent.apply(.title("Changed elsewhere"), to: task.id, expected: latest.revision)
            }
        }
        switch await repository.create(value) {
        case .created(let saved, let id), .alreadyCreated(let saved, let id):
            self.document = saved
            let cleanup = await captures.close(id: value.id)
            captureDraft = nil; captureRecoveryStatus = ""; captureIsComposing = false
            createdTaskID = id; creationNotice = saved.snapshot.workspace.tasks.first(where: { $0.id == id })?.kind == .note ? "Note added" : "Task added"
            if cleanup != .saved { await readCaptureRecovery(); captureError = "Saved, but the recovery copy could not be cleared." }
        case .notSaved(let latest):
            self.document = latest; value.confirmedNotSaved(); captureDraft = value
            let stored = await captures.save(value)
            captureRecoveryStatus = stored == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open."
            captureError = "Could not save. Your draft is kept. Retry or keep editing."
        case .uncertain:
            captureError = "The save could not be confirmed. Your draft is kept. Retry checks the same task before creating anything."
        case .refused(let reason):
            switch reason {
            case .stale: captureError = "The workspace changed. Your draft is kept. Discard to reload; it has not been applied to the changed workspace."
            case .compatibility: captureError = "This workspace contains data this build cannot safely rewrite. Your draft is kept."
            case .commandConflict: captureError = "This capture ID already belongs to a changed task. Your draft is kept; no duplicate was created."
            case .invalidCapture, .validation: captureError = "The destination, tags, schedule or template are no longer safe to use. Your draft is kept."
            }
            if let latest = try? await repository.load() { self.document = latest }
        }
        isBusy = false
    }
    func resumeCaptureRecovery() {
        guard let recoveredCapture, !isBusy else { return }
        captureDraft = recoveredCapture; self.recoveredCapture = nil; captureError = nil; captureIsComposing = false
        captureRecoveryStatus = "Recovery copy saved"; createdTaskID = nil
    }
    func discardCaptureRecovery() async {
        guard let value = recoveredCapture, let captures, !isBusy else { return }
        readTicket = UUID(); isBusy = true
        if await captures.close(id: value.id) == .saved { recoveredCapture = nil; captureError = nil }
        else { captureError = "The saved capture could not be discarded. It has been kept." }
        isBusy = false
    }
    private func readCaptureRecovery() async {
        guard let captures else { return }
        switch await captures.load() {
        case .none: recoveredCapture = nil; protectedCapture = false
        case .available(let value): recoveredCapture = captureDraft?.id == value.id ? nil : value; protectedCapture = false
        case .unavailable: recoveredCapture = nil; protectedCapture = true
        }
    }

}
