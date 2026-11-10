import Foundation

public enum TaskPriority: String, Codable, CaseIterable, Sendable { case none, low, medium, high }
public enum RepeatRule: String, Codable, CaseIterable, Sendable { case none, daily, weekdays, weekly, monthly, yearly }
public enum TaskKind: String, Codable, CaseIterable, Sendable { case task, note }

/// The series schedule beneath a rescheduled current occurrence. The task
/// itself continues to carry the visible schedule for all ordinary readers.
public struct OccurrenceSchedule: Codable, Equatable, Sendable {
    public let due: Date
    let timed: Bool
    let window: TaskDurationRange?
    let reminder: Date?
    let additionalReminders: [Date]?
    let followsSchedule: Bool?
    let reminderAtEnd: Bool?

    init?(task: TaskItem) {
        guard let due = task.dueDate else { return nil }
        self.due = due; timed = task.hasDueTime; window = task.scheduledDuration
        reminder = task.reminderDate; additionalReminders = task.additionalReminderDates
        followsSchedule = task.reminderFollowsSchedule
        reminderAtEnd = task.endReminderEnabled ? true : nil
    }

    func restoring(on task: TaskItem) -> TaskItem {
        var task = task
        task.dueDate = due; task.hasDueTime = timed; task.scheduledDuration = window
        task.reminderDate = reminder; task.additionalReminderDates = additionalReminders
        task.reminderFollowsSchedule = followsSchedule
        task.endReminderEnabled = reminderAtEnd == true
        task.originalOccurrenceSchedule = nil
        return task
    }
}

public struct ChecklistItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
    }
}

public struct TaskItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var listID: UUID? {
        didSet { if listID != oldValue { sectionID = nil } }
    }
    /// A root's explicit assignment within its regular list.
    public package(set) var sectionID: UUID? = nil
    public var tagIDs: [UUID]
    public var kind: TaskKind
    public var dueDate: Date?
    public var hasDueTime: Bool
    public var reminderDate: Date?
    public var additionalReminderDates: [Date]?
    public var reminderDates: [Date] {
        get { Array(Set(([reminderDate].compactMap { $0 }) + (additionalReminderDates ?? []))).sorted() }
        set {
            let dates = Array(Set(newValue)).sorted()
            reminderDate = dates.first
            additionalReminderDates = dates.count > 1 ? Array(dates.dropFirst()) : nil
        }
    }
    /// Whether the reminder follows the configured schedule default; nil denotes legacy data.
    public var reminderFollowsSchedule: Bool?
    private var reminderAtEnd: Bool? = nil
    public var endReminderEnabled: Bool {
        get { reminderAtEnd == true }
        set { reminderAtEnd = newValue ? true : nil }
    }
    public var endReminderDate: Date? {
        guard endReminderEnabled, hasDueTime, let window = scheduledDuration, !window.isAllDay,
              dueDate == window.end, window.start <= window.end,
              window.start.timeIntervalSinceReferenceDate.isFinite, window.end.timeIntervalSinceReferenceDate.isFinite else { return nil }
        return window.end
    }
    /// The visible reminders include the derived endpoint without adding it to the stored manual/default dates.
    public var effectiveReminderDates: [Date] {
        let dates = reminderDates
        guard let end = endReminderDate, !dates.contains(end) else { return dates }
        return (dates + [end]).sorted()
    }
    public var priority: TaskPriority
    public var recurrence: RepeatRule
    public var checklist: [ChecklistItem]
    public package(set) var manualProgress: Int? = nil
    public var progressPercent: Int {
        guard !checklist.isEmpty else { return manualProgress ?? 0 }
        return checklist.lazy.filter(\.isCompleted).count * 100 / checklist.count
    }
    public var canEditManualProgress: Bool {
        kind == .task && checklist.isEmpty && completedAt == nil && wontDoAt == nil && deletedAt == nil
    }
    public var completedAt: Date?
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    /// The original day of month for a repeating schedule, retained across short months.
    public var recurrenceAnchorDay: Int?
    /// The original month for a yearly schedule, retained across leap years.
    public var recurrenceAnchorMonth: Int?
    /// Inclusive final calendar day for this repeating schedule; nil means no end.
    public var recurrenceEndDate: Date?
    public var recurrenceSourceID: UUID?
    /// Independent custom-recurrence rule (Every N weeks on Mon/Wed, monthly
    /// on the third Friday, specific dates, …). When valid it takes
    /// precedence over the legacy `recurrence` enum; the editor keeps the two
    /// mutually exclusive. Nil denotes legacy-only data.
    public var customRecurrence: CustomRecurrence?
    /// 1-based position in a custom series: the series start carries 1 and
    /// each generated successor increments it, so `maxOccurrences` counting
    /// survives reloads. New series always start at 1.
    public var occurrenceIndex: Int
    /// Unadjusted nominal occurrence for the current due date in a custom
    /// weekend-rolling series: the pure-cadence date before any
    /// skip-weekends roll is applied. Interval alignment is computed from
    /// this date, never reconstructed from the displayed adjusted due, so
    /// a roll across a month boundary cannot redefine an every-N-month
    /// series. Nil for legacy records (falls back to the due date for one
    /// transition) and for series that carry no nominal (completion anchor,
    /// no custom rule).
    public var recurrenceNominalDate: Date?
    public var originalOccurrenceSchedule: OccurrenceSchedule? = nil

    /// Use this only for series progression, including read-only forecasts.
    var recurrenceSchedule: TaskItem { originalOccurrenceSchedule?.restoring(on: self) ?? self }

    /// Copies start from their own displayed schedule. They do not inherit
    /// a temporary exception or the original's hidden cadence anchors.
    public mutating func discardOccurrenceBaselineForCopy() {
        guard originalOccurrenceSchedule != nil else { return }
        originalOccurrenceSchedule = nil
        recurrenceNominalDate = isCustomRepeating ? dueDate : nil
        recurrenceAnchorDay = nil
        recurrenceAnchorMonth = nil
    }
    /// Parent task for subtask nesting. Nil denotes a top-level task; unknown
    /// parents clear to top level on load and cycles are refused by the store,
    /// so orphaned subtasks always render as roots instead of vanishing.
    public var parentID: UUID? {
        didSet { if parentID != nil { sectionID = nil } }
    }
    /// Optional scheduled window (start/end, timed or all-day). The due date
    /// IS the window end and the shape decides `hasDueTime`; recurring
    /// successors carry it forward end-anchored at the next due date and
    /// templates carry its shape. Nil denotes no planned block.
    public var scheduledDuration: TaskDurationRange?
    public var wontDoAt: Date?
    public var timeZoneID: String?
    /// Optional rich-text companion to `body`. Nil denotes legacy plain text.
    /// `body` stays authoritative: `RichBody.valid(for:)` gates every read,
    /// and `TaskStore.updateTask` clears stale styles when the body changes.
    public var richBody: RichBody?
    /// Pinned tasks render in a Pinned group above normal active groups while
    /// active; completed, Won't Do, and trashed records never render pinned.
    public var isPinned: Bool

    /// True when a valid custom rule is set (repeating regardless of the
    /// legacy enum, which a custom rule supersedes).
    public var isCustomRepeating: Bool { customRecurrence?.isValid == true }
    /// True when the task repeats under either system: the legacy enum or a
    /// valid custom rule. Badges, filters, and counts use this so custom
    /// series behave exactly like legacy ones downstream.
    public var isRepeating: Bool { recurrence != .none || isCustomRepeating }

    /// Badge/editor text for the repeat state: the custom rule's short label
    /// when custom-repeating, otherwise the legacy enum label.
    public func repeatLabel(calendar: Calendar = .current) -> String {
        if let rule = customRecurrence, rule.isValid { return rule.shortLabel(calendar: calendar) }
        return recurrence == .none ? "Does not repeat" : recurrence.rawValue.capitalized
    }

    package func converted(to kind: TaskKind) -> TaskItem? {
        guard self.kind != kind else { return nil }
        var converted = self
        converted.kind = kind
        converted.completedAt = nil
        converted.wontDoAt = nil
        return converted
    }

    /// Restarts the custom series after a rule change: the position returns
    /// to 1 and the nominal occurrence returns to the current due date (the
    /// new series start). Clearing the rule drops the nominal. A no-op when
    /// the rule is unchanged. Call after assigning `customRecurrence`.
    public mutating func restartCustomSeries(ruleChangedFrom old: CustomRecurrence?) {
        guard customRecurrence != old else { return }
        occurrenceIndex = 1
        recurrenceNominalDate = customRecurrence == nil ? nil : dueDate
    }

    /// Reconciles the custom-series position when a save changes the
    /// schedule outside completion (the store boundary, not just the
    /// schedule editor). A changed rule — including clear and replace —
    /// restarts the series at the new due date. A changed due date under an
    /// unchanged rule rebases the nominal to the new due: the count is
    /// preserved, and the next completion advances forward from the
    /// manually chosen occurrence instead of behind it. Anything else —
    /// including a no-op save of a rolled task — leaves the position
    /// untouched, so stored nominals are never clobbered. Call after
    /// schedule coherence settles the final due date.
    public mutating func normalizeSeriesPosition(old: TaskItem) {
        if customRecurrence != old.customRecurrence {
            restartCustomSeries(ruleChangedFrom: old.customRecurrence)
            return
        }
        guard isCustomRepeating, dueDate != old.dueDate, let due = dueDate else { return }
        recurrenceNominalDate = due
    }

    public init(id: UUID = UUID(), title: String, body: String = "", listID: UUID? = nil,
                tagIDs: [UUID] = [], kind: TaskKind = .task, dueDate: Date? = nil,
                hasDueTime: Bool = false, reminderDate: Date? = nil, priority: TaskPriority = .none,
                recurrence: RepeatRule = .none, checklist: [ChecklistItem] = [],
                completedAt: Date? = nil, deletedAt: Date? = nil, createdAt: Date = Date(),
                updatedAt: Date = Date(), recurrenceAnchorDay: Int? = nil, recurrenceAnchorMonth: Int? = nil,
                recurrenceSourceID: UUID? = nil, recurrenceEndDate: Date? = nil, additionalReminderDates: [Date]? = nil, reminderFollowsSchedule: Bool? = nil, wontDoAt: Date? = nil, timeZoneID: String? = nil,
                customRecurrence: CustomRecurrence? = nil, occurrenceIndex: Int = 1, parentID: UUID? = nil,
                scheduledDuration: TaskDurationRange? = nil,
                richBody: RichBody? = nil, isPinned: Bool = false, recurrenceNominalDate: Date? = nil) {
        self.id = id; self.title = title; self.body = body; self.listID = listID; self.tagIDs = tagIDs
        self.kind = kind; self.dueDate = dueDate; self.hasDueTime = hasDueTime; self.reminderDate = reminderDate
        self.priority = priority; self.recurrence = recurrence; self.checklist = checklist
        self.completedAt = completedAt; self.deletedAt = deletedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.recurrenceAnchorDay = recurrenceAnchorDay; self.recurrenceAnchorMonth = recurrenceAnchorMonth
        self.recurrenceSourceID = recurrenceSourceID; self.recurrenceEndDate = recurrenceEndDate; self.additionalReminderDates = additionalReminderDates; self.reminderFollowsSchedule = reminderFollowsSchedule; self.wontDoAt = wontDoAt; self.timeZoneID = timeZoneID
        self.customRecurrence = customRecurrence; self.occurrenceIndex = max(1, occurrenceIndex)
        self.recurrenceNominalDate = recurrenceNominalDate
        self.parentID = parentID
        self.scheduledDuration = scheduledDuration
        self.richBody = richBody; self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, listID, tagIDs, kind, dueDate, hasDueTime, reminderDate,
             additionalReminderDates, reminderFollowsSchedule, priority, recurrence, checklist,
             completedAt, deletedAt, createdAt, updatedAt, recurrenceAnchorDay, recurrenceAnchorMonth,
             recurrenceSourceID, recurrenceEndDate, wontDoAt, timeZoneID, customRecurrence, occurrenceIndex, parentID, scheduledDuration,
             richBody, isPinned, recurrenceNominalDate, originalOccurrenceSchedule, sectionID, manualProgress, reminderAtEnd
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        listID = try c.decodeIfPresent(UUID.self, forKey: .listID)
        sectionID = try c.decodeIfPresent(UUID.self, forKey: .sectionID)
        tagIDs = try c.decode([UUID].self, forKey: .tagIDs)
        kind = try c.decode(TaskKind.self, forKey: .kind)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        hasDueTime = try c.decode(Bool.self, forKey: .hasDueTime)
        reminderDate = try c.decodeIfPresent(Date.self, forKey: .reminderDate)
        additionalReminderDates = try c.decodeIfPresent([Date].self, forKey: .additionalReminderDates)
        reminderFollowsSchedule = try c.decodeIfPresent(Bool.self, forKey: .reminderFollowsSchedule)
        reminderAtEnd = try c.decodeIfPresent(Bool.self, forKey: .reminderAtEnd)
        priority = try c.decode(TaskPriority.self, forKey: .priority)
        recurrence = try c.decode(RepeatRule.self, forKey: .recurrence)
        checklist = try c.decode([ChecklistItem].self, forKey: .checklist)
        manualProgress = try c.decodeIfPresent(Int.self, forKey: .manualProgress)
        if let manualProgress, !(1...100).contains(manualProgress) {
            throw DecodingError.dataCorruptedError(forKey: .manualProgress, in: c,
                                                   debugDescription: "Invalid stored task progress.")
        }
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        recurrenceAnchorDay = try c.decodeIfPresent(Int.self, forKey: .recurrenceAnchorDay)
        recurrenceAnchorMonth = try c.decodeIfPresent(Int.self, forKey: .recurrenceAnchorMonth)
        recurrenceSourceID = try c.decodeIfPresent(UUID.self, forKey: .recurrenceSourceID)
        recurrenceEndDate = try c.decodeIfPresent(Date.self, forKey: .recurrenceEndDate)
        wontDoAt = try c.decodeIfPresent(Date.self, forKey: .wontDoAt)
        timeZoneID = try c.decodeIfPresent(String.self, forKey: .timeZoneID)
        // Explicit legacy decoding: pre-custom-recurrence files omit the rule
        // (legacy-only series) and the index defaults to the series start.
        customRecurrence = try c.decodeIfPresent(CustomRecurrence.self, forKey: .customRecurrence)
        occurrenceIndex = max(1, try c.decodeIfPresent(Int.self, forKey: .occurrenceIndex) ?? 1)
        // Pre-nominal files omit the anchor: nil falls back to the due date.
        recurrenceNominalDate = try c.decodeIfPresent(Date.self, forKey: .recurrenceNominalDate)
        originalOccurrenceSchedule = try c.decodeIfPresent(OccurrenceSchedule.self, forKey: .originalOccurrenceSchedule)
        // Pre-hierarchy files omit the parent link; subtasks decode as roots.
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        // Pre-duration files omit the window; no planned block.
        scheduledDuration = try c.decodeIfPresent(TaskDurationRange.self, forKey: .scheduledDuration)
        // Explicit legacy decoding: pre-rich-text and pre-pin files omit
        // these keys and decode to plain, unpinned tasks with every other
        // field untouched.
        richBody = try c.decodeIfPresent(RichBody.self, forKey: .richBody)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

public struct ListFolder: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Pinned folders render a shortcut in the Pinned sidebar section.
    public var isPinned: Bool
    public init(id: UUID = UUID(), name: String, isPinned: Bool = false) {
        self.id = id; self.name = name; self.isPinned = isPinned
    }
    private enum CodingKeys: String, CodingKey { case id, name, isPinned }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
    // id and name stay required: a folder record missing either is malformed
    // and fails the whole workspace decode, which the existing unreadable-file
    // protection preserves — never silently minted with a random UUID or
    // placeholder name that would drop memberships.
}

/// Per-list center view. Stored on the list (legacy default List) so each
/// list remembers its own mode across rename, edit, duplicate, and reload.
/// The view mode is independent of the list's section definitions.
public enum TaskListViewMode: String, Codable, CaseIterable, Sendable {
    case list, board, timeline
    public var label: String { rawValue.capitalized }
}

public struct TaskList: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    public var kind: TaskKind
    public var symbol: String?
    /// Per-list center view mode (List default). Preserved by rename/edit
    /// (callers carry the record), duplicate, and reload.
    public var viewMode: TaskListViewMode
    private var sectionRecords: [TaskSection]?
    public package(set) var sections: [TaskSection] {
        get { sectionRecords ?? [] }
        set { sectionRecords = newValue.isEmpty ? nil : newValue }
    }
    public var folderID: UUID?
    /// Trailing root placement: ungrouped lists with `true` render below all
    /// folders instead of above them. Defaults to false so legacy files keep
    /// their prior top root order; unknown folders still clear to top root.
    public var belowFolders: Bool
    /// Archived lists render in Archived Lists and read read-only: their
    /// tasks hide from smart destinations and stop firing reminders.
    public var isArchived: Bool
    /// Smart-list inclusion ("Show in Smart List"): `false` hides the list's
    /// tasks from smart destinations while reminders keep firing (reference:
    /// "If enabled, tasks within this list won't be shown ... but still
    /// receive reminders"). Distinct from archive, which also suppresses
    /// reminders.
    public var showsInSmartLists: Bool
    /// Pinned lists render a shortcut in the Pinned sidebar section.
    public var isPinned: Bool
    public init(id: UUID = UUID(), name: String, color: String, kind: TaskKind = .task, symbol: String? = nil, viewMode: TaskListViewMode = .list, folderID: UUID? = nil, belowFolders: Bool = false, isArchived: Bool = false, showsInSmartLists: Bool = true, isPinned: Bool = false) {
        self.id = id; self.name = name; self.color = color; self.kind = kind; self.symbol = symbol; self.viewMode = viewMode; self.folderID = folderID; self.belowFolders = belowFolders
        self.isArchived = isArchived; self.showsInSmartLists = showsInSmartLists; self.isPinned = isPinned
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, color, kind, symbol, viewMode, folderID, belowFolders, isArchived, showsInSmartLists, isPinned
        case sectionRecords = "sections"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        kind = try c.decodeIfPresent(TaskKind.self, forKey: .kind) ?? .task
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        // Pre-view-mode files decode as List.
        viewMode = try c.decodeIfPresent(TaskListViewMode.self, forKey: .viewMode) ?? .list
        let decodedSections = try c.decodeIfPresent([TaskSection].self, forKey: .sectionRecords) ?? []
        sectionRecords = decodedSections.isEmpty ? nil : decodedSections
        guard Set(decodedSections.map(\.id)).count == decodedSections.count else {
            throw DecodingError.dataCorruptedError(forKey: .sectionRecords, in: c, debugDescription: "Duplicate task section identifiers.")
        }
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        belowFolders = try c.decodeIfPresent(Bool.self, forKey: .belowFolders) ?? false
        // Explicit legacy decoding: pre-archive files show everywhere.
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        showsInSmartLists = try c.decodeIfPresent(Bool.self, forKey: .showsInSmartLists) ?? true
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

public struct TaskTag: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    /// Optional parent for a single-level-or-deeper tag hierarchy. Nil is a
    /// top-level tag; unknown parents clear to nil on load (never hidden).
    public var parentID: UUID?
    /// Persisted sidebar collapse for parents.
    public var isCollapsed: Bool
    /// Pinned tags render a shortcut in the Pinned sidebar section.
    public var isPinned: Bool
    public init(id: UUID = UUID(), name: String, color: String, parentID: UUID? = nil, isCollapsed: Bool = false, isPinned: Bool = false) {
        self.id = id; self.name = name; self.color = color
        self.parentID = parentID; self.isCollapsed = isCollapsed; self.isPinned = isPinned
    }
    private enum CodingKeys: String, CodingKey { case id, name, color, parentID, isCollapsed, isPinned }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        isCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

/// Persisted completion-cascade ledger: completing a parent completes its
/// active descendants in the same instant and records each cascaded child's
/// ID with the exact timestamp it was stamped. Undo reopens only children
/// whose current `completedAt` still equals the recorded stamp, so
/// independent prior completions and later user changes are never touched.
/// The entry is consumed on undo; reload-safe by construction.
public struct TaskCompletionCascade: Codable, Equatable, Sendable {
    public struct ChildCompletion: Codable, Equatable, Sendable {
        public var id: UUID
        public var completedAt: Date
        public init(id: UUID, completedAt: Date) { self.id = id; self.completedAt = completedAt }
    }
    public var parentID: UUID
    public var completedAt: Date
    public var children: [ChildCompletion]
    public init(parentID: UUID, completedAt: Date, children: [ChildCompletion] = []) {
        self.parentID = parentID; self.completedAt = completedAt; self.children = children
    }
}

/// Persisted trash-cascade ledger: trashing a parent trashes its non-trashed
/// descendants in the same instant. Restore revives only children whose
/// current `deletedAt` still equals the recorded stamp, so separately
/// trashed children (different stamps) stay in Trash. Consumed on restore.
public struct TaskTrashCascade: Codable, Equatable, Sendable {
    public struct ChildTrash: Codable, Equatable, Sendable {
        public var id: UUID
        public var deletedAt: Date
        public init(id: UUID, deletedAt: Date) { self.id = id; self.deletedAt = deletedAt }
    }
    public var parentID: UUID
    public var deletedAt: Date
    public var children: [ChildTrash]
    public init(parentID: UUID, deletedAt: Date, children: [ChildTrash] = []) {
        self.parentID = parentID; self.deletedAt = deletedAt; self.children = children
    }
}

public struct WorkspaceData: Codable, Equatable, Sendable {
    public var tasks: [TaskItem]
    public var lists: [TaskList]
    public var tags: [TaskTag]
    public var filters: [TaskFilter]
    public var templates: [TaskTemplate]
    public var folders: [ListFolder]
    /// Completion/trash cascade ledgers (see those types). Absent in legacy
    /// files and decode to empty.
    public var completionCascades: [TaskCompletionCascade]
    public var trashCascades: [TaskTrashCascade]
    public init(tasks: [TaskItem] = [], lists: [TaskList] = [], tags: [TaskTag] = [], filters: [TaskFilter] = [], templates: [TaskTemplate] = [], folders: [ListFolder] = [], completionCascades: [TaskCompletionCascade] = [], trashCascades: [TaskTrashCascade] = []) {
        self.tasks = tasks; self.lists = lists; self.tags = tags; self.filters = filters; self.templates = templates; self.folders = folders
        self.completionCascades = completionCascades; self.trashCascades = trashCascades
    }
    private enum CodingKeys: String, CodingKey { case tasks, lists, tags, filters, templates, folders, completionCascades, trashCascades }
    // Older writers require an array or a recognized envelope before saving.
    private struct ProtectedTaskRecords: Codable {
        enum Format: String, Codable { case occurrenceSchedulesV1, listSectionsV1, richCodeBlocksV1, richHighlightColorsV1, taskProgressV1, endRemindersV1 }
        let format: Format
        let records: [TaskItem]
    }
    private var protectedTaskFormat: ProtectedTaskRecords.Format? {
        if tasks.contains(where: { $0.endReminderEnabled || $0.originalOccurrenceSchedule?.reminderAtEnd == true }) { return .endRemindersV1 }
        if tasks.contains(where: { $0.manualProgress != nil }) { return .taskProgressV1 }
        if tasks.contains(where: { $0.richBody?.hasCustomHighlightColors == true }) ||
            templates.contains(where: { $0.richBody?.hasCustomHighlightColors == true }) {
            return .richHighlightColorsV1
        }
        if tasks.contains(where: { $0.richBody?.hasCodeBlocks == true }) ||
            templates.contains(where: { $0.richBody?.hasCodeBlocks == true }) {
            return .richCodeBlocksV1
        }
        if lists.contains(where: { !$0.sections.isEmpty }) || tasks.contains(where: { $0.sectionID != nil }) {
            return .listSectionsV1
        }
        return tasks.contains(where: { $0.originalOccurrenceSchedule != nil }) ? .occurrenceSchedulesV1 : nil
    }
    package var requiresProtectedTaskCollection: Bool { protectedTaskFormat != nil }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedFormat: ProtectedTaskRecords.Format?
        if (try? c.superDecoder(forKey: .tasks).unkeyedContainer()) != nil {
            tasks = try c.decode([TaskItem].self, forKey: .tasks)
            storedFormat = nil
        } else {
            let envelope = try c.decode(ProtectedTaskRecords.self, forKey: .tasks)
            tasks = envelope.records
            storedFormat = envelope.format
        }
        lists = try c.decode([TaskList].self, forKey: .lists); tags = try c.decode([TaskTag].self, forKey: .tags)
        filters = try c.decodeIfPresent([TaskFilter].self, forKey: .filters) ?? []; templates = try c.decodeIfPresent([TaskTemplate].self, forKey: .templates) ?? TaskTemplate.builtIns
        completionCascades = try c.decodeIfPresent([TaskCompletionCascade].self, forKey: .completionCascades) ?? []
        trashCascades = try c.decodeIfPresent([TaskTrashCascade].self, forKey: .trashCascades) ?? []
        // Only these two keys tolerate absence: a missing `folders` array means
        // a pre-folders file (defaults to empty), and a missing `folderID`
        // means an ungrouped list (defaults to nil, handled in TaskList).
        folders = try c.decodeIfPresent([ListFolder].self, forKey: .folders) ?? []
        guard storedFormat == protectedTaskFormat else {
            throw DecodingError.dataCorruptedError(forKey: .tasks, in: c, debugDescription: "Task data and its protection format disagree.")
        }
        // Drop folder memberships that reference unknown folders (legacy or
        // hand-edited files): lists stay, tasks stay, membership clears.
        let known = Set(folders.map(\.id))
        if lists.contains(where: { $0.folderID != nil }) {
            lists = lists.map { var l = $0; if let f = l.folderID, !known.contains(f) { l.folderID = nil }; return l }
        }
        // Defend malformed tag hierarchies without hiding entities: unknown
        // parents clear to top level, and parent cycles break (each cycle
        // member becomes top-level) so no traversal can loop forever.
        tags = Self.sanitizedTagParents(tags)
        // Same policy for subtask links: unknown parents (trashed or
        // hand-edited) clear to top level and cycles break, so orphaned
        // subtasks render as roots instead of vanishing.
        tasks = Self.sanitizedTaskParents(tasks)
        let sectionsByList = Dictionary(lists.map { ($0.id, Set($0.sections.map(\.id))) },
                                        uniquingKeysWith: { first, _ in first })
        for index in tasks.indices {
            guard let section = tasks[index].sectionID else { continue }
            if tasks[index].parentID != nil || tasks[index].listID.flatMap({ sectionsByList[$0] })?.contains(section) != true {
                tasks[index].sectionID = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let format = protectedTaskFormat {
            try c.encode(ProtectedTaskRecords(format: format, records: tasks), forKey: .tasks)
        } else {
            try c.encode(tasks, forKey: .tasks)
        }
        try c.encode(lists, forKey: .lists)
        try c.encode(tags, forKey: .tags)
        try c.encode(filters, forKey: .filters)
        try c.encode(templates, forKey: .templates)
        try c.encode(folders, forKey: .folders)
        try c.encode(completionCascades, forKey: .completionCascades)
        try c.encode(trashCascades, forKey: .trashCascades)
    }

    /// Clears unknown tag parents and breaks parent cycles. Pure so the
    /// workspace decoder and the store share one policy.
    public static func sanitizedTagParents(_ tags: [TaskTag]) -> [TaskTag] {
        let known = Set(tags.map(\.id))
        var result = tags.map { tag -> TaskTag in
            var tag = tag
            if let parent = tag.parentID, (!known.contains(parent) || parent == tag.id) {
                tag.parentID = nil
            }
            return tag
        }
        // Break every remaining cycle: re-read fresh state per tag so one
        // cleared link is visible to the next walk and loops lose exactly
        // one membership instead of being flattened.
        // Last-wins on duplicate IDs: malformed duplicates never trap
        // (uniqueKeysWithValues would fatalError) and no record is dropped.
        var byID: [UUID: TaskTag] = [:]
        for tag in result { byID[tag.id] = tag }
        for i in result.indices {
            var seen = Set<UUID>([result[i].id])
            var cursor = result[i].parentID
            while let current = cursor, let node = byID[current] {
                if !seen.insert(current).inserted {
                    if let index = result.firstIndex(where: { $0.parentID == current && seen.contains($0.id) }) {
                        result[index].parentID = nil
                        byID[result[index].id] = result[index]
                    }
                    break
                }
                cursor = node.parentID
            }
        }
        return result
    }

    /// Clears unknown task parents and breaks parent cycles. Pure so the
    /// workspace decoder and the store share one policy. Trashing does not
    /// cascade (children keep their link), so a trashed parent orphans its
    /// subtasks into top-level rows via the unknown-parent rule on load.
    public static func sanitizedTaskParents(_ tasks: [TaskItem]) -> [TaskItem] {
        let known = Set(tasks.map(\.id))
        var result = tasks.map { task -> TaskItem in
            var task = task
            if let parent = task.parentID, (!known.contains(parent) || parent == task.id) {
                task.parentID = nil
            }
            return task
        }
        var byID: [UUID: TaskItem] = [:]
        for task in result { byID[task.id] = task }
        for i in result.indices {
            var seen = Set<UUID>([result[i].id])
            var cursor = result[i].parentID
            while let current = cursor, let node = byID[current] {
                if !seen.insert(current).inserted {
                    if let index = result.firstIndex(where: { $0.parentID == current && seen.contains($0.id) }) {
                        result[index].parentID = nil
                        byID[result[index].id] = result[index]
                    }
                    break
                }
                cursor = node.parentID
            }
        }
        return result
    }
}
