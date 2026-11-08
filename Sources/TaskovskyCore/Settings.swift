import Foundation

public enum SmartListKey: String, Codable, CaseIterable, Sendable { case all, today, tomorrow, week, inbox, summary, tags, filters, completed, wontDo, trash }
public enum SmartListVisibility: String, Codable, CaseIterable, Sendable { case show, hidden, showIfNotEmpty }
public enum DefaultDate: String, Codable, CaseIterable, Sendable { case none, today, tomorrow, dayAfterTomorrow, nextWeek }
public enum DueReminder: String, Codable, CaseIterable, Sendable { case none, onTime, fiveMinutesBefore, fifteenMinutesBefore, thirtyMinutesBefore, oneHourBefore, oneDayBefore
    public var offset: TimeInterval? { switch self { case .none: nil; case .onTime: 0; case .fiveMinutesBefore: -300; case .fifteenMinutesBefore: -900; case .thirtyMinutesBefore: -1800; case .oneHourBefore: -3600; case .oneDayBefore: -86400 } }
}
public enum AllDayReminder: String, Codable, CaseIterable, Sendable { case none, onDay9, dayBefore9, twoDaysBefore9, threeDaysBefore9, weekBefore9 }
public enum TaskPosition: String, Codable, CaseIterable, Sendable { case top, bottom }

public struct AppSettings: Codable, Equatable, Sendable {
    public var smartListVisibility: [SmartListKey: SmartListVisibility] = [.all: .hidden, .today: .show, .tomorrow: .hidden, .week: .show, .inbox: .show, .summary: .hidden, .tags: .show, .filters: .show, .completed: .show, .wontDo: .showIfNotEmpty, .trash: .show]
    /// Persisted deterministic smart-list order. Nil denotes legacy files and
    /// decodes to the default order; normalization appends missing keys in
    /// default order and drops duplicates/unknown values. Hidden keys keep
    /// their slots so showing them later restores their position; only the
    /// filtered visible order is shown, never a resaved scramble of hidden keys.
    public var smartListOrder: [SmartListKey]? = nil
    public var startWeekOn = 2
    public var showWeekNumbers = false
    public var enableTimeZone = false
    public var dateRecognition = true
    public var removeDateText = false
    public var removeTagText = true
    public var urlParsing = true
    public var defaultDate: DefaultDate = .none
    public var defaultReminder: DueReminder = .onTime
    public var allDayReminder: AllDayReminder = .none
    public var timedReminderDefaults: [DueReminder]? = nil
    public var allDayReminderDefaults: [AllDayReminder]? = nil
    public var effectiveTimedReminderDefaults: [DueReminder] { (timedReminderDefaults ?? [defaultReminder]).filter { $0 != .none } }
    public var effectiveAllDayReminderDefaults: [AllDayReminder] { (allDayReminderDefaults ?? [allDayReminder]).filter { $0 != .none } }
    public var defaultPriority: TaskPriority = .none
    public var defaultTagID: UUID? = nil
    public var defaultListID: UUID? = nil
    public var defaultAddTo: TaskPosition = .top
    public var overduePosition: TaskPosition = .top
    public var completionSound = true
    /// Default timed duration (minutes) for newly created dated tasks with a
    /// time; 0 means none. Applies only to timed dues — all-day dates never
    /// gain times silently. Capped to one week on read.
    public var defaultDurationMinutes = 0
    public var hasInstalledBuiltInTemplates = false
    public init() {}
    private enum CodingKeys: String, CodingKey { case smartListVisibility, smartListOrder, startWeekOn, showWeekNumbers, enableTimeZone, dateRecognition, removeDateText, removeTagText, urlParsing, defaultDate, defaultReminder, allDayReminder, timedReminderDefaults, allDayReminderDefaults, defaultPriority, defaultTagID, defaultListID, defaultAddTo, overduePosition, completionSound, hasInstalledBuiltInTemplates, defaultDurationMinutes }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        if let values = try c.decodeIfPresent([SmartListKey: SmartListVisibility].self, forKey: .smartListVisibility) { smartListVisibility.merge(values) { _, new in new } }
        smartListOrder = try c.decodeIfPresent([SmartListKey].self, forKey: .smartListOrder)
        startWeekOn = try c.decodeIfPresent(Int.self, forKey: .startWeekOn) ?? startWeekOn
        showWeekNumbers = try c.decodeIfPresent(Bool.self, forKey: .showWeekNumbers) ?? showWeekNumbers
        enableTimeZone = try c.decodeIfPresent(Bool.self, forKey: .enableTimeZone) ?? enableTimeZone
        dateRecognition = try c.decodeIfPresent(Bool.self, forKey: .dateRecognition) ?? dateRecognition
        removeDateText = try c.decodeIfPresent(Bool.self, forKey: .removeDateText) ?? removeDateText
        removeTagText = try c.decodeIfPresent(Bool.self, forKey: .removeTagText) ?? removeTagText
        urlParsing = try c.decodeIfPresent(Bool.self, forKey: .urlParsing) ?? urlParsing
        defaultDate = try c.decodeIfPresent(DefaultDate.self, forKey: .defaultDate) ?? defaultDate
        defaultReminder = try c.decodeIfPresent(DueReminder.self, forKey: .defaultReminder) ?? defaultReminder
        allDayReminder = try c.decodeIfPresent(AllDayReminder.self, forKey: .allDayReminder) ?? allDayReminder
        timedReminderDefaults = try c.decodeIfPresent([DueReminder].self, forKey: .timedReminderDefaults)
        allDayReminderDefaults = try c.decodeIfPresent([AllDayReminder].self, forKey: .allDayReminderDefaults)
        defaultPriority = try c.decodeIfPresent(TaskPriority.self, forKey: .defaultPriority) ?? defaultPriority
        defaultTagID = try c.decodeIfPresent(UUID.self, forKey: .defaultTagID)
        defaultListID = try c.decodeIfPresent(UUID.self, forKey: .defaultListID)
        defaultAddTo = try c.decodeIfPresent(TaskPosition.self, forKey: .defaultAddTo) ?? defaultAddTo
        overduePosition = try c.decodeIfPresent(TaskPosition.self, forKey: .overduePosition) ?? overduePosition
        completionSound = try c.decodeIfPresent(Bool.self, forKey: .completionSound) ?? completionSound
        hasInstalledBuiltInTemplates = try c.decodeIfPresent(Bool.self, forKey: .hasInstalledBuiltInTemplates) ?? false
        defaultDurationMinutes = min(max(try c.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes) ?? defaultDurationMinutes, 0), 10_080)
    }
    public var calendar: Calendar { var calendar = Calendar.current; calendar.firstWeekday = min(7, max(1, startWeekOn)); return calendar }
}

extension AppSettings {
    /// Canonical sidebar order. Sidebar group structure (documented boundary):
    /// top destinations `[all, today, tomorrow, week, inbox, summary]` render
    /// above the Lists/Filters/Tags sections; bottom system destinations
    /// `[completed, wontDo, trash]` render below them. `tags`/`filters` keys
    /// control section visibility and are never draggable rows. Reordering is
    /// constrained within each group and can never cross the boundary.
    public static let defaultSmartListOrder: [SmartListKey] = [.all, .today, .tomorrow, .week, .inbox, .summary, .tags, .filters, .completed, .wontDo, .trash]
    public static let topSmartGroup: [SmartListKey] = [.all, .today, .tomorrow, .week, .inbox, .summary]
    public static let bottomSmartGroup: [SmartListKey] = [.completed, .wontDo, .trash]
    /// Normalized full order: stored order first (deduped), then any missing
    /// default keys appended in default order. Legacy nil decodes to default.
    public var effectiveSmartListOrder: [SmartListKey] {
        var seen = Set<SmartListKey>()
        var result: [SmartListKey] = []
        for key in smartListOrder ?? [] where seen.insert(key).inserted { result.append(key) }
        for key in Self.defaultSmartListOrder where seen.insert(key).inserted { result.append(key) }
        return result
    }
    /// Atomically reorders one smart key within its group. Cross-group moves,
    /// unknown groups (tags/filters sections), self-drops, and unknown keys
    /// abort with no mutation.
    @discardableResult public mutating func reorderSmartList(moving: SmartListKey, before target: SmartListKey, afterTarget: Bool = false) -> Bool {
        guard moving != target else { return false }
        func group(of key: SmartListKey) -> [SmartListKey]? {
            if Self.topSmartGroup.contains(key) { return Self.topSmartGroup }
            if Self.bottomSmartGroup.contains(key) { return Self.bottomSmartGroup }
            return nil
        }
        guard let movingGroup = group(of: moving), let targetGroup = group(of: target), movingGroup == targetGroup else { return false }
        var order = effectiveSmartListOrder
        guard let from = order.firstIndex(of: moving) else { return false }
        order.remove(at: from)
        // The target survives the removal (moving != target is checked above).
        guard let targetIndex = order.firstIndex(of: target) else { return false }
        order.insert(moving, at: afterTarget ? targetIndex + 1 : targetIndex)
        smartListOrder = order
        return true
    }
}

/// Manual-sort (None, including legacy "Manual") grouping: every active
/// task/note shares one group regardless of due date or priority, so items
/// with different dates reorder freely without rewriting those fields.
/// Completed/Won't-Do history and Trash stay separate. The Reminders
/// destination keeps its semantic Due/Upcoming split (documented scope).
public enum ManualGroupPolicy {
    public enum Bucket: Equatable { case deleted, history, active }
    public static func bucket(completedAt: Date?, wontDoAt: Date?, deletedAt: Date?) -> Bucket {
        if deletedAt != nil { return .deleted }
        if completedAt != nil || wontDoAt != nil { return .history }
        return .active
    }
    public static let activeGroupTitle = "Tasks"
}

/// Persisted task-sort values. Legacy installs stored `"Manual"`; the picker
/// now shows `"None"` (manual order) for both. `"Date"` and every other stored
/// value is preserved untouched.
public enum TaskSortPolicy {
    public static let manualLegacyRaw = "Manual"
    public static let manualRaw = "None"
    public static let reorderDisabledMessage = "Manual drag and drop is not supported while sorting is enabled. Choose None in Sort to reorder tasks."
    public static func normalized(_ raw: String) -> String { raw == manualLegacyRaw ? manualRaw : raw }
    public static func isManual(_ raw: String) -> Bool { normalized(raw) == manualRaw }
    public static func canReorder(_ raw: String) -> Bool { isManual(raw) }
}

public enum FilterDateRule: String, Codable, CaseIterable, Sendable {
    case all, today, tomorrow, next7, overdue, noDate
    case thisWeek, nextWeek, lastWeek, thisMonth, nextMonth, lastMonth, repeating, custom
    public var label: String {
        switch self {
        case .all: return "Any date"; case .today: return "Today"; case .tomorrow: return "Tomorrow"
        case .next7: return "Next 7 days"; case .overdue: return "Overdue"; case .noDate: return "No date"
        case .thisWeek: return "This week"; case .nextWeek: return "Next week"; case .lastWeek: return "Last week"
        case .thisMonth: return "This month"; case .nextMonth: return "Next month"; case .lastMonth: return "Last month"
        case .repeating: return "Repeating"; case .custom: return "Custom range"
        }
    }
}
public enum FilterStatus: String, Codable, CaseIterable, Sendable { case active, completed, wontDo, all }
/// Tag matching across the selected tag IDs. `.any` is the legacy behavior
/// (a task matching any selected tag passes; empty selection passes).
public enum FilterTagMode: String, Codable, CaseIterable, Sendable {
    case any, all, none, anyTagged
    public var label: String {
        switch self {
        case .any: return "Any selected"; case .all: return "All selected"
        case .none: return "No tags"; case .anyTagged: return "Any tag"
        }
    }
}
public enum FilterConditionKind: String, Codable, CaseIterable, Sendable {
    case list, tag, noTags, priority, date, kind, status, keyword, repeating
    public var label: String {
        switch self {
        case .list: return "List"; case .tag: return "Tag"; case .noTags: return "No tags"
        case .priority: return "Priority"; case .date: return "Date"; case .kind: return "Type"
        case .status: return "Status"; case .keyword: return "Keyword"; case .repeating: return "Repeating"
        }
    }
}
public struct FilterCondition: Codable, Equatable, Sendable {
    public var kind: FilterConditionKind
    public var listID: UUID?
    public var tagID: UUID?
    public var priority: TaskPriority?
    public var dateRule: FilterDateRule?
    public var taskKind: TaskKind?
    public var status: FilterStatus?
    public var keyword: String?
    public init(kind: FilterConditionKind, listID: UUID? = nil, tagID: UUID? = nil, priority: TaskPriority? = nil, dateRule: FilterDateRule? = nil, taskKind: TaskKind? = nil, status: FilterStatus? = nil, keyword: String? = nil) {
        self.kind = kind; self.listID = listID; self.tagID = tagID; self.priority = priority
        self.dateRule = dateRule; self.taskKind = taskKind; self.status = status; self.keyword = keyword
    }
}
/// Tag repointing across a rule tree (merge support). Returns a tree with
/// every `.tag` condition on `source` moved to `target`, deduplicated within
/// each AND/OR group; every other node is shared untouched.
public enum FilterRuleRewrite {
    public static func repointingTag(from source: UUID, to target: UUID, in rule: FilterRule) -> FilterRule {
        switch rule {
        case .and(let children): return .and(deduped(children.map { repointingTag(from: source, to: target, in: $0) }))
        case .or(let children): return .or(deduped(children.map { repointingTag(from: source, to: target, in: $0) }))
        case .not(let child): return .not(repointingTag(from: source, to: target, in: child))
        case .condition(var condition):
            if condition.kind == .tag, condition.tagID == source { condition.tagID = target }
            return .condition(condition)
        }
    }

    private static func deduped(_ children: [FilterRule]) -> [FilterRule] {
        var seen = Set<String>()
        return children.filter { child in
            // Conditions dedupe on kind+value; groups never dedupe (structure).
            guard case .condition(let condition) = child else { return true }
            let key = "\(condition.kind)-\(condition.listID?.uuidString ?? "")-\(condition.tagID?.uuidString ?? "")-\(condition.priority?.rawValue ?? "")-\(condition.dateRule?.rawValue ?? "")-\(condition.taskKind?.rawValue ?? "")-\(condition.status?.rawValue ?? "")-\(condition.keyword ?? "")"
            return seen.insert(key).inserted
        }
    }
}
/// Nested logic rules. Empty AND and empty OR both match everything (static
/// control-flow evidence from the reference framework); NOT inverts its
/// single child, so an empty NOT matches nothing. No arbitrary code: only
/// these predicates evaluate.
///
/// The document format is explicit (`{"type":"and","children":[...]}`) rather
/// than compiler-synthesized, so persisted rules stay stable. An unknown
/// `type` fails decoding (fail-closed, matching unknown enum values
/// elsewhere) — the workspace is preserved, never silently reinterpreted.
public indirect enum FilterRule: Equatable, Sendable {
    case and([FilterRule])
    case or([FilterRule])
    case not(FilterRule)
    case condition(FilterCondition)
}

extension FilterRule: Codable {
    private enum Kind: String, Codable { case and, or, not, condition }
    private enum CodingKeys: String, CodingKey { case type, children, child, condition }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .and: self = .and(try c.decodeIfPresent([FilterRule].self, forKey: .children) ?? [])
        case .or: self = .or(try c.decodeIfPresent([FilterRule].self, forKey: .children) ?? [])
        case .not: self = .not(try c.decode(FilterRule.self, forKey: .child))
        case .condition: self = .condition(try c.decode(FilterCondition.self, forKey: .condition))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .and(let children): try c.encode(Kind.and, forKey: .type); try c.encode(children, forKey: .children)
        case .or(let children): try c.encode(Kind.or, forKey: .type); try c.encode(children, forKey: .children)
        case .not(let child): try c.encode(Kind.not, forKey: .type); try c.encode(child, forKey: .child)
        case .condition(let condition): try c.encode(Kind.condition, forKey: .type); try c.encode(condition, forKey: .condition)
        }
    }
}
public struct TaskFilter: Codable, Identifiable, Equatable, Sendable {
    /// Reserved selection identifier for tasks whose listID is nil (Inbox).
    public static let inboxListID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    public var id: UUID; public var name: String; public var listIDs: [UUID]; public var tagIDs: [UUID]
    public var priorities: [TaskPriority]
    public var dateRules: [FilterDateRule]
    public var status: FilterStatus; public var keyword: String
    /// Task/note type selection. Empty means both types (legacy behavior).
    public var kinds: [TaskKind]
    public var tagMode: FilterTagMode
    /// Day-inclusive custom date range bounds for `.custom` date rules.
    public var customDateFrom: Date?
    public var customDateTo: Date?
    public var isPinned: Bool
    /// Advanced mode root. When non-nil it REPLACES criteria matching (except
    /// the deleted-task guard); when nil the Normal criteria below apply.
    public var ruleRoot: FilterRule?
    public init(id: UUID = UUID(), name: String, listIDs: [UUID] = [], tagIDs: [UUID] = [], priority: TaskPriority? = nil, priorities: [TaskPriority]? = nil, dateRule: FilterDateRule = .all, dateRules: [FilterDateRule]? = nil, status: FilterStatus = .active, keyword: String = "", kinds: [TaskKind] = [], tagMode: FilterTagMode = .any, customDateFrom: Date? = nil, customDateTo: Date? = nil, isPinned: Bool = false, ruleRoot: FilterRule? = nil) {
        self.id = id; self.name = name; self.listIDs = listIDs; self.tagIDs = tagIDs
        self.priorities = priorities ?? priority.map { [$0] } ?? []
        self.dateRules = dateRules ?? (dateRule == .all ? [] : [dateRule])
        self.status = status; self.keyword = keyword
        self.kinds = kinds; self.tagMode = tagMode
        self.customDateFrom = customDateFrom; self.customDateTo = customDateTo
        self.isPinned = isPinned; self.ruleRoot = ruleRoot
    }
    private enum CodingKeys: String, CodingKey { case id, name, listIDs, tagIDs, priority, priorities, dateRule, dateRules, status, keyword, kinds, tagMode, customDateFrom, customDateTo, isPinned, ruleRoot }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        listIDs = try c.decodeIfPresent([UUID].self, forKey: .listIDs) ?? []; tagIDs = try c.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        // Legacy-safe: explicit arrays win; a single legacy value maps to one
        // element; absence means no constraint (same as legacy `.all`/nil).
        // Legacy meanings are unchanged: one priority, one date rule.
        let legacyPriority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority)
        priorities = try c.decodeIfPresent([TaskPriority].self, forKey: .priorities) ?? legacyPriority.map { [$0] } ?? []
        let legacyDate = try c.decodeIfPresent(FilterDateRule.self, forKey: .dateRule)
        dateRules = try c.decodeIfPresent([FilterDateRule].self, forKey: .dateRules) ?? legacyDate.map { $0 == .all ? [] : [$0] } ?? []
        status = try c.decodeIfPresent(FilterStatus.self, forKey: .status) ?? .active
        keyword = try c.decodeIfPresent(String.self, forKey: .keyword) ?? ""
        kinds = try c.decodeIfPresent([TaskKind].self, forKey: .kinds) ?? []
        tagMode = try c.decodeIfPresent(FilterTagMode.self, forKey: .tagMode) ?? .any
        customDateFrom = try c.decodeIfPresent(Date.self, forKey: .customDateFrom)
        customDateTo = try c.decodeIfPresent(Date.self, forKey: .customDateTo)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        ruleRoot = try c.decodeIfPresent(FilterRule.self, forKey: .ruleRoot)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
        try c.encode(listIDs, forKey: .listIDs); try c.encode(tagIDs, forKey: .tagIDs)
        // Legacy mirrors for older readers (single selections only); the
        // arrays stay authoritative when both are present.
        try c.encode(priorities.count == 1 ? priorities[0] : nil, forKey: .priority)
        try c.encode(priorities, forKey: .priorities)
        try c.encode(dateRules.count == 1 ? dateRules[0] : FilterDateRule.all, forKey: .dateRule)
        try c.encode(dateRules, forKey: .dateRules)
        try c.encode(status, forKey: .status); try c.encode(keyword, forKey: .keyword)
        try c.encode(kinds, forKey: .kinds); try c.encode(tagMode, forKey: .tagMode)
        try c.encodeIfPresent(customDateFrom, forKey: .customDateFrom)
        try c.encodeIfPresent(customDateTo, forKey: .customDateTo)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encodeIfPresent(ruleRoot, forKey: .ruleRoot)
    }

    /// Positive list IDs the rule tree references (for explicit-selection
    /// archive overrides in rule mode). References under a NOT are
    /// negated, not selected: NOT(list A) must never grant A's tasks an
    /// archive/exclusion override. Double negation counts as positive.
    public var ruleListIDs: Set<UUID> {
        guard let ruleRoot else { return [] }
        var ids = Set<UUID>()
        func walk(_ rule: FilterRule, negated: Bool) {
            switch rule {
            case .and(let children), .or(let children): children.forEach { walk($0, negated: negated) }
            case .not(let child): walk(child, negated: !negated)
            case .condition(let condition):
                if !negated, condition.kind == .list, let id = condition.listID { ids.insert(id) }
            }
        }
        walk(ruleRoot, negated: false)
        return ids
    }

    public func matches(_ task: TaskItem, lists: [TaskList] = [], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard task.deletedAt == nil else { return false }
        if let ruleRoot {
            // Advanced mode: the rule replaces criteria entirely (including
            // the criteria keyword — keywords only match via conditions).
            // Archived/excluded lists hide the task unless the rule
            // explicitly names its list.
            if SmartListEligibility.isExcludedFromSmart(task, lists: lists),
               !ruleListIDs.contains(task.listID ?? Self.inboxListID) { return false }
            return Self.evaluate(ruleRoot, task: task, filter: self, lists: lists, now: now, calendar: calendar)
        }
        guard TaskSearch.matches(task, query: keyword) else { return false }
        // Explicit list selection overrides archive/exclusion: choosing an
        // archived or opted-out list shows its content on purpose.
        if SmartListEligibility.isExcludedFromSmart(task, lists: lists),
           !listIDs.contains(task.listID ?? Self.inboxListID) { return false }
        guard (listIDs.isEmpty || listIDs.contains(task.listID ?? Self.inboxListID)) else { return false }
        switch tagMode {
        case .any: guard tagIDs.isEmpty || !Set(tagIDs).isDisjoint(with: task.tagIDs) else { return false }
        case .all: guard Set(tagIDs).isSubset(of: Set(task.tagIDs)) else { return false }
        case .none: guard task.tagIDs.isEmpty else { return false }
        case .anyTagged: guard !task.tagIDs.isEmpty else { return false }
        }
        guard priorities.isEmpty || priorities.contains(task.priority) else { return false }
        guard kinds.isEmpty || kinds.contains(task.kind) else { return false }
        switch status { case .active: if task.completedAt != nil || task.wontDoAt != nil { return false }; case .completed: if task.completedAt == nil { return false }; case .wontDo: if task.wontDoAt == nil { return false }; case .all: break }
        guard dateRules.isEmpty || dateRules.contains(where: { Self.dateRuleMatches($0, task: task, customFrom: customDateFrom, customTo: customDateTo, now: now, calendar: calendar) }) else { return false }
        return true
    }

    /// Single date-rule predicate. Weeks and months follow the passed
    /// calendar (week start, time zone); custom bounds are day-inclusive.
    /// Legacy rules keep their exact legacy meaning.
    public static func dateRuleMatches(_ rule: FilterDateRule, task: TaskItem, customFrom: Date? = nil, customTo: Date? = nil, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: now)
        switch rule {
        case .all: return true
        case .noDate: return task.dueDate == nil
        case .today: return task.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        case .tomorrow: return task.dueDate.map { due in calendar.date(byAdding: .day, value: 1, to: now).map { calendar.isDate(due, inSameDayAs: $0) } ?? false } ?? false
        case .next7: guard let due = task.dueDate, let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }; return due >= start && due < end
        case .overdue: guard let due = task.dueDate else { return false }; return task.hasDueTime ? due < now : due < start
        case .thisWeek: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }; return due >= interval.start && due < interval.end
        case .nextWeek: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .weekOfYear, for: now), let next = calendar.date(byAdding: .weekOfYear, value: 1, to: interval.start), let end = calendar.date(byAdding: .weekOfYear, value: 1, to: interval.end) else { return false }; return due >= next && due < end
        case .lastWeek: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .weekOfYear, for: now), let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { return false }; return due >= prev && due < interval.start
        case .thisMonth: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .month, for: now) else { return false }; return due >= interval.start && due < interval.end
        case .nextMonth: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .month, for: now), let next = calendar.date(byAdding: .month, value: 1, to: interval.start), let end = calendar.date(byAdding: .month, value: 1, to: interval.end) else { return false }; return due >= next && due < end
        case .lastMonth: guard let due = task.dueDate, let interval = calendar.dateInterval(of: .month, for: now), let prev = calendar.date(byAdding: .month, value: -1, to: interval.start) else { return false }; return due >= prev && due < interval.start
        case .repeating: return task.isRepeating
        case .custom:
            guard let due = task.dueDate else { return false }
            let day = calendar.startOfDay(for: due)
            if let from = customFrom, day < calendar.startOfDay(for: from) { return false }
            if let to = customTo, day > calendar.startOfDay(for: to) { return false }
            return true
        }
    }

    /// AND/OR/NOT evaluation over the rule tree. Empty AND and empty OR both
    /// match everything (reference control-flow evidence); NOT inverts its
    /// child. Deleted tasks never reach here (guarded by `matches`).
    public static func evaluate(_ rule: FilterRule, task: TaskItem, filter: TaskFilter, lists: [TaskList], now: Date, calendar: Calendar) -> Bool {
        switch rule {
        case .and(let children): return children.allSatisfy { evaluate($0, task: task, filter: filter, lists: lists, now: now, calendar: calendar) }
        case .or(let children): return children.isEmpty || children.contains { evaluate($0, task: task, filter: filter, lists: lists, now: now, calendar: calendar) }
        case .not(let child): return !evaluate(child, task: task, filter: filter, lists: lists, now: now, calendar: calendar)
        case .condition(let condition): return conditionMatches(condition, task: task, filter: filter, now: now, calendar: calendar)
        }
    }

    public static func conditionMatches(_ condition: FilterCondition, task: TaskItem, filter: TaskFilter, now: Date, calendar: Calendar) -> Bool {
        switch condition.kind {
        // Positive list IDs only: an unconfigured condition ("Choose list")
        // matches nothing instead of silently matching Inbox. Explicit Inbox
        // selection is stored as `inboxListID` and still matches.
        case .list: guard let id = condition.listID else { return false }; return (task.listID ?? Self.inboxListID) == id
        case .tag: guard let id = condition.tagID else { return false }; return task.tagIDs.contains(id)
        case .noTags: return task.tagIDs.isEmpty
        // Unset values fall back to the editor's displayed defaults (Today,
        // no priority, task type, uncompleted) so saved conditions always
        // mean what the picker shows.
        case .priority: return task.priority == (condition.priority ?? .none)
        case .date: return dateRuleMatches(condition.dateRule ?? .today, task: task, customFrom: filter.customDateFrom, customTo: filter.customDateTo, now: now, calendar: calendar)
        case .kind: return task.kind == (condition.taskKind ?? .task)
        case .status:
            switch condition.status ?? .active {
            case .active: return task.completedAt == nil && task.wontDoAt == nil
            case .completed: return task.completedAt != nil
            case .wontDo: return task.wontDoAt != nil
            case .all: return true
            }
        case .keyword: return TaskSearch.matches(task, query: condition.keyword ?? "")
        case .repeating: return task.isRepeating
        }
    }
}
public struct TaskTemplate: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID; public var name: String; public var title: String; public var body: String; public var checklist: [ChecklistItem]; public var priority: TaskPriority; public var tagIDs: [UUID]; public var kind: TaskKind
    /// Optional rich-text companion to `body`, carried through save/apply.
    /// Nil denotes legacy plain templates; stale styles clear on body edits.
    public var richBody: RichBody?
    /// Optional custom-recurrence rule, carried through save/apply/instantiate.
    /// Nil denotes legacy templates; instantiation always starts a new series.
    public var customRecurrence: CustomRecurrence?
    /// Optional scheduled window, carried through save/apply/instantiate.
    /// Instantiation onto a due date re-anchors its end at that date;
    /// without a due date the absolute window carries over (and brings its
    /// own due). Nil denotes legacy data.
    public var scheduledDuration: TaskDurationRange?
    public init(id: UUID = UUID(), name: String, title: String, body: String = "", checklist: [ChecklistItem] = [], priority: TaskPriority = .none, tagIDs: [UUID] = [], kind: TaskKind = .task, richBody: RichBody? = nil, customRecurrence: CustomRecurrence? = nil, scheduledDuration: TaskDurationRange? = nil) { self.id = id; self.name = name; self.title = title; self.body = body; self.checklist = checklist; self.priority = priority; self.tagIDs = tagIDs; self.kind = kind; self.richBody = richBody; self.customRecurrence = customRecurrence; self.scheduledDuration = scheduledDuration }
    private enum CodingKeys: String, CodingKey { case id, name, title, body, checklist, priority, tagIDs, kind, richBody, customRecurrence, scheduledDuration }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        title = try c.decode(String.self, forKey: .title); body = try c.decode(String.self, forKey: .body)
        checklist = try c.decode([ChecklistItem].self, forKey: .checklist)
        priority = try c.decode(TaskPriority.self, forKey: .priority)
        tagIDs = try c.decode([UUID].self, forKey: .tagIDs)
        kind = try c.decode(TaskKind.self, forKey: .kind)
        richBody = try c.decodeIfPresent(RichBody.self, forKey: .richBody)
        customRecurrence = try c.decodeIfPresent(CustomRecurrence.self, forKey: .customRecurrence)
        scheduledDuration = try c.decodeIfPresent(TaskDurationRange.self, forKey: .scheduledDuration)
    }
}
extension TaskTemplate {
    public static var builtIns: [TaskTemplate] {
        [
            TaskTemplate(name: "To-dos before work", title: "To-dos before work", checklist: ["Reflection on yesterday", "Check emails", "Check tasks in Inbox", "Find the 3 most important tasks"].map { ChecklistItem(title: $0) }),
            TaskTemplate(name: "Daily record", title: "Daily record", body: "What have I accomplished today?\n\nWhat's the highlight of the day?"),
            TaskTemplate(name: "Things to pack for travelling", title: "Things to pack for travelling", checklist: ["Passport", "Charger", "Umbrella", "Tote bag", "Clothes"].map { ChecklistItem(title: $0) })
        ]
    }
}
public enum TaskSearch {
    public static func matches(_ task: TaskItem, query: String) -> Bool { let q = query.trimmingCharacters(in: .whitespacesAndNewlines); return q.isEmpty || ([task.title, task.body] + task.checklist.map(\.title)).contains { $0.localizedCaseInsensitiveContains(q) } }
}
