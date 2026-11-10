import Foundation

public enum TaskCalendarMode: String, Codable, CaseIterable, Sendable {
    case day, week, month, year, agenda, multiDay, multiWeek
    public var title: String {
        switch self {
        case .day: "Day"; case .week: "Week"; case .month: "Month"; case .year: "Year"
        case .agenda: "Agenda"; case .multiDay: "Multi-Day"; case .multiWeek: "Multi-Week"
        }
    }
    public var isHourly: Bool { self == .day || self == .week || self == .multiDay }
}
public enum CalendarColorMode: String, Codable, CaseIterable, Sendable { case list, tag, priority }
public enum CalendarItemStyle: String, Codable, CaseIterable, Sendable { case filled, outline }
public enum CalendarYearStyle: String, Codable, CaseIterable, Sendable { case standard, heatmap }

/// Local Calendar scope is independent of smart-list inclusion. Archived
/// lists stay hidden. Missing settings decode to the local defaults.
public struct TaskCalendarOptions: Codable, Equatable, Sendable {
    public var mode: TaskCalendarMode = .week
    public var multiDayCount = 5
    public var multiWeekCount = 2
    public var showSidebar = true
    public var showCompleted = true
    public var showRepeatCycles = true
    public var showChecklistItems = false
    public var colorBy: CalendarColorMode = .list
    public var itemStyle: CalendarItemStyle = .filled
    public var yearStyle: CalendarYearStyle = .heatmap
    public var showItemIcons = true
    public static let allDayRowRange = 1...12
    private var allDayRowsOverride: Int?
    /// Nil sizes the all-day area automatically.
    public var allDayRows: Int? {
        get { allDayRowsOverride }
        set { allDayRowsOverride = newValue.map { min(Self.allDayRowRange.upperBound, max(Self.allDayRowRange.lowerBound, $0)) } }
    }
    private var foldedHoursOverride: CalendarFoldedHours?
    public var foldedHours: CalendarFoldedHours {
        get { foldedHoursOverride ?? .init() }
        set { if newValue != foldedHours { foldedHoursOverride = newValue == .init() ? nil : newValue } }
    }
    // Missing per-kind preferences keep legacy files on the existing master switch.
    private var taskIconsOverride: Bool?
    private var noteIconsOverride: Bool?
    public var showTaskIcons: Bool {
        get { taskIconsOverride ?? true }
        set { if newValue != showTaskIcons { taskIconsOverride = newValue ? nil : false } }
    }
    public var showNoteIcons: Bool {
        get { noteIconsOverride ?? true }
        set { if newValue != showNoteIcons { noteIconsOverride = newValue ? nil : false } }
    }
    public func showsIcon(for entry: CalendarEntry) -> Bool {
        showItemIcons && (entry.isNote ? showNoteIcons : showTaskIcons)
    }
    public var showAdditionalTimeZones = false
    public var additionalTimeZones: [CalendarTimeZone] = []
    /// Compatibility with the original single-ruler setting. New callers should
    /// configure the collection and visibility independently.
    public var additionalTimeZoneID: String? {
        get { showAdditionalTimeZones ? CalendarTimeZone.normalized(additionalTimeZones).first?.identifier : nil }
        set {
            additionalTimeZones = CalendarTimeZone.normalized(newValue.map { [CalendarTimeZone(identifier: $0)] } ?? [])
            showAdditionalTimeZones = !additionalTimeZones.isEmpty
        }
    }
    public func visibleTimeZones(primary: TimeZone) -> [CalendarTimeZone] {
        guard showAdditionalTimeZones else { return [] }
        return CalendarTimeZone.normalized(additionalTimeZones).filter { $0.identifier != primary.identifier }
    }
    /// Nil = every active list; [] = none. Inbox is controlled separately.
    public var listIDs: [UUID]? = nil
    public var includeInbox = true
    /// Empty = no restriction; selected parent tags include descendants.
    public var tagIDs: [UUID] = []
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case mode, multiDayCount, multiWeekCount, showSidebar, showCompleted, showRepeatCycles,
             showChecklistItems, colorBy, itemStyle, additionalTimeZoneID, listIDs, includeInbox, tagIDs,
             yearStyle, showItemIcons, showTaskIcons, showNoteIcons, showAdditionalTimeZones, additionalTimeZones,
             foldedHours, allDayRows
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? c.decode(TaskCalendarMode.self, forKey: .mode)) ?? mode
        multiDayCount = min(14, max(2, try c.decodeIfPresent(Int.self, forKey: .multiDayCount) ?? multiDayCount))
        multiWeekCount = min(6, max(2, try c.decodeIfPresent(Int.self, forKey: .multiWeekCount) ?? multiWeekCount))
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? showSidebar
        showCompleted = try c.decodeIfPresent(Bool.self, forKey: .showCompleted) ?? showCompleted
        showRepeatCycles = try c.decodeIfPresent(Bool.self, forKey: .showRepeatCycles) ?? showRepeatCycles
        showChecklistItems = try c.decodeIfPresent(Bool.self, forKey: .showChecklistItems) ?? showChecklistItems
        colorBy = (try? c.decode(CalendarColorMode.self, forKey: .colorBy)) ?? colorBy
        itemStyle = (try? c.decode(CalendarItemStyle.self, forKey: .itemStyle)) ?? itemStyle
        yearStyle = (try? c.decode(CalendarYearStyle.self, forKey: .yearStyle)) ?? yearStyle
        showItemIcons = try c.decodeIfPresent(Bool.self, forKey: .showItemIcons) ?? showItemIcons
        taskIconsOverride = try c.decodeIfPresent(Bool.self, forKey: .showTaskIcons)
        noteIconsOverride = try c.decodeIfPresent(Bool.self, forKey: .showNoteIcons)
        foldedHoursOverride = try? c.decode(CalendarFoldedHours.self, forKey: .foldedHours)
        allDayRows = try? c.decode(Int.self, forKey: .allDayRows)
        if c.contains(.additionalTimeZones) {
            additionalTimeZones = CalendarTimeZone.normalized((try? c.decode([CalendarTimeZone].self, forKey: .additionalTimeZones)) ?? [])
            showAdditionalTimeZones = try c.decodeIfPresent(Bool.self, forKey: .showAdditionalTimeZones) ?? !additionalTimeZones.isEmpty
        } else {
            additionalTimeZoneID = try c.decodeIfPresent(String.self, forKey: .additionalTimeZoneID)
        }
        listIDs = try c.decodeIfPresent([UUID].self, forKey: .listIDs)
        includeInbox = try c.decodeIfPresent(Bool.self, forKey: .includeInbox) ?? includeInbox
        tagIDs = try c.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mode, forKey: .mode)
        try c.encode(multiDayCount, forKey: .multiDayCount)
        try c.encode(multiWeekCount, forKey: .multiWeekCount)
        try c.encode(showSidebar, forKey: .showSidebar)
        try c.encode(showCompleted, forKey: .showCompleted)
        try c.encode(showRepeatCycles, forKey: .showRepeatCycles)
        try c.encode(showChecklistItems, forKey: .showChecklistItems)
        try c.encode(colorBy, forKey: .colorBy)
        try c.encode(itemStyle, forKey: .itemStyle)
        try c.encode(yearStyle, forKey: .yearStyle)
        try c.encode(showItemIcons, forKey: .showItemIcons)
        try c.encodeIfPresent(taskIconsOverride, forKey: .showTaskIcons)
        try c.encodeIfPresent(noteIconsOverride, forKey: .showNoteIcons)
        try c.encodeIfPresent(foldedHoursOverride, forKey: .foldedHours)
        try c.encodeIfPresent(allDayRows, forKey: .allDayRows)
        try c.encode(showAdditionalTimeZones, forKey: .showAdditionalTimeZones)
        try c.encode(CalendarTimeZone.normalized(additionalTimeZones), forKey: .additionalTimeZones)
        try c.encodeIfPresent(additionalTimeZoneID, forKey: .additionalTimeZoneID)
        try c.encodeIfPresent(listIDs, forKey: .listIDs)
        try c.encode(includeInbox, forKey: .includeInbox)
        try c.encode(tagIDs, forKey: .tagIDs)
    }
    public func includes(_ task: TaskItem, data: WorkspaceData) -> Bool {
        guard task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: data.lists) else { return false }
        return matchesCalendarSources(task, data: data)
    }
}

/// Temporary Agenda browsing state. Extending the view leaves the start
/// and the workspace untouched. The end is an exclusive local day boundary.
public struct CalendarAgendaWindow: Sendable {
    static let initialDayCount = 30
    private var extensions = 0

    public init() {}

    public var canExtend: Bool { extensions < 4 }

    public mutating func extend() {
        if canExtend { extensions += 1 }
    }

    func days(focus: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: focus)
        guard extensions > 0,
              let initialEnd = calendar.date(byAdding: .day, value: Self.initialDayCount, to: start),
              let end = calendar.date(byAdding: .month, value: extensions * 6, to: initialEnd),
              let length = calendar.dateComponents([.day], from: start, to: end).day else {
            return CalendarDates.days(from: start, count: Self.initialDayCount, calendar: calendar)
        }
        return CalendarDates.days(from: start, count: length, calendar: calendar)
    }
}

public enum CalendarHourBand: String, CaseIterable, Hashable, Sendable {
    case early, late

    public var title: String { self == .early ? "Early hours" : "Late hours" }
    public var cutoffTitle: String { self == .early ? "Early hours end" : "Late hours start" }
}

/// The civil-hour boundaries of the two folds. Each band and the middle
/// timeline retain at least one hour, so the handles can never cross.
public struct CalendarFoldedHours: Codable, Equatable, Sendable {
    public let earlyEnd: Int
    public let lateStart: Int

    public init(earlyEnd: Int = 7, lateStart: Int = 21) {
        self.lateStart = min(23, max(2, lateStart))
        self.earlyEnd = min(self.lateStart - 1, max(1, earlyEnd))
    }

    private enum CodingKeys: String, CodingKey { case earlyEnd, lateStart }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(earlyEnd: try values.decode(Int.self, forKey: .earlyEnd),
                  lateStart: try values.decode(Int.self, forKey: .lateStart))
    }

    public func cutoff(_ band: CalendarHourBand) -> Int { band == .early ? earlyEnd : lateStart }
    public func range(for band: CalendarHourBand) -> ClosedRange<Int> {
        band == .early ? 1...(lateStart - 1) : (earlyEnd + 1)...23
    }
    public func moving(_ band: CalendarHourBand, to hour: Int) -> Self {
        let allowed = range(for: band)
        let value = min(allowed.upperBound, max(allowed.lowerBound, hour))
        return band == .early ? .init(earlyEnd: value, lateStart: lateStart) : .init(earlyEnd: earlyEnd, lateStart: value)
    }
    public func moving(_ band: CalendarHourBand, by offset: Double) -> Self {
        guard offset.isFinite else { return self }
        let delta = Int(min(24, max(-24, offset.rounded())))
        return moving(band, to: cutoff(band) + delta)
    }
}

/// The folded bands only change the visible timeline. Task schedules and
/// wall-clock calculations still use the full local day.
public struct CalendarHourlyWindow: Equatable, Sendable {
    public static let full = Self(earlyExpanded: true, lateExpanded: true)
    private var earlyExpanded: Bool
    private var lateExpanded: Bool
    private var foldedHours: CalendarFoldedHours

    public init(earlyExpanded: Bool = false, lateExpanded: Bool = false, foldedHours: CalendarFoldedHours = .init()) {
        self.earlyExpanded = earlyExpanded
        self.lateExpanded = lateExpanded
        self.foldedHours = foldedHours
    }

    public func using(_ foldedHours: CalendarFoldedHours) -> Self {
        Self(earlyExpanded: earlyExpanded, lateExpanded: lateExpanded, foldedHours: foldedHours)
    }
    public var canAdjustFolds: Bool { earlyExpanded && lateExpanded }
    public var hours: Range<Int> { (earlyExpanded ? 0 : foldedHours.earlyEnd)..<(lateExpanded ? 24 : foldedHours.lateStart) }
    public var firstMinute: Int { hours.lowerBound * 60 }
    public var endMinute: Int { hours.upperBound * 60 }

    public func isExpanded(_ band: CalendarHourBand) -> Bool {
        band == .early ? earlyExpanded : lateExpanded
    }

    public mutating func toggle(_ band: CalendarHourBand) {
        switch band {
        case .early: earlyExpanded.toggle()
        case .late: lateExpanded.toggle()
        }
    }

    public func minute(atOffset offset: Double) -> Int {
        snappedMinute(Double(firstMinute) + offset)
    }

    public func snappedMinute(_ minute: Double) -> Int {
        min(endMinute, max(firstMinute, CalendarDates.snappedMinute(minute)))
    }

    public func itemCount(in band: CalendarHourBand, entries: [CalendarEntry], days: [Date], calendar: Calendar) -> Int {
        let bandHours = band == .early ? 0..<foldedHours.earlyEnd : foldedHours.lateStart..<24
        let intervals = days.map { day in
            (CalendarDates.instant(on: day, minute: bandHours.lowerBound * 60, calendar: calendar),
             CalendarDates.instant(on: day, minute: bandHours.upperBound * 60, calendar: calendar))
        }
        return entries.filter { entry in
            !entry.isAllDay && intervals.contains { entry.start < $0.1 && entry.end > $0.0 }
        }.count
    }
}

/// The phone's Month display scale. Zoomed ranges start on the focused
/// week and can cross a month boundary while browsing.
public struct CalendarTimelineScale: Equatable, Sendable {
    public static let standard = Self(pointsPerHour: 52)
    private static let limits: ClosedRange<Double> = 32...104
    public let pointsPerHour: Double

    private init(pointsPerHour: Double) {
        self.pointsPerHour = pointsPerHour
    }

    public var percentage: Int { Int((pointsPerHour / Self.standard.pointsPerHour * 100).rounded()) }
    public var canZoomIn: Bool { pointsPerHour < Self.limits.upperBound }
    public var canZoomOut: Bool { pointsPerHour > Self.limits.lowerBound }

    public func stepped(zoomingIn: Bool) -> Self {
        bounded(pointsPerHour + (zoomingIn ? 8 : -8))
    }

    public func scaled(by factor: Double) -> Self {
        guard factor.isFinite, factor > 0 else { return self }
        return bounded(pointsPerHour * factor)
    }

    public func hour(at offset: Double) -> Double { offset / pointsPerHour }
    public func offset(at hour: Double) -> Double { hour * pointsPerHour }

    private func bounded(_ height: Double) -> Self {
        Self(pointsPerHour: min(Self.limits.upperBound, max(Self.limits.lowerBound, height)))
    }
}

public enum CalendarMonthZoom: Int, CaseIterable, Sendable {
    case full, threeWeeks, twoWeeks, oneWeek

    public var weekCount: Int? {
        switch self {
        case .full: nil
        case .threeWeeks: 3
        case .twoWeeks: 2
        case .oneWeek: 1
        }
    }
    public var itemLimit: Int {
        switch self {
        case .full: 2
        case .threeWeeks: 4
        case .twoWeeks: 6
        case .oneWeek: 8
        }
    }
    public var title: String {
        guard let weekCount else { return "Full Month" }
        return weekCount == 1 ? "1 Week" : "\(weekCount) Weeks"
    }
    public func adjusted(zoomingIn: Bool) -> Self {
        Self(rawValue: rawValue + (zoomingIn ? 1 : -1)) ?? self
    }
    public func adjusted(magnification: Double) -> Self {
        guard magnification.isFinite else { return self }
        if magnification >= 1.2 { return adjusted(zoomingIn: true) }
        if magnification <= 0.8 { return adjusted(zoomingIn: false) }
        return self
    }
}

public enum CalendarDates {
    public static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
    public static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }
    public static func days(from start: Date, count: Int, calendar: Calendar) -> [Date] {
        (0..<max(0, count)).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: start)) }
    }
    public static func visibleDays(focus: Date, mode: TaskCalendarMode, options: TaskCalendarOptions, calendar: Calendar,
                                   agendaWindow: CalendarAgendaWindow = .init(), monthZoom: CalendarMonthZoom = .full) -> [Date] {
        switch mode {
        case .day: return days(from: focus, count: 1, calendar: calendar)
        case .week: return days(from: weekStart(focus, calendar: calendar), count: 7, calendar: calendar)
        case .multiDay: return days(from: focus, count: min(14, max(2, options.multiDayCount)), calendar: calendar)
        case .multiWeek: return days(from: weekStart(focus, calendar: calendar), count: min(6, max(2, options.multiWeekCount)) * 7, calendar: calendar)
        case .agenda: return agendaWindow.days(focus: focus, calendar: calendar)
        case .month:
            if let count = monthZoom.weekCount {
                return days(from: weekStart(focus, calendar: calendar), count: count * 7, calendar: calendar)
            }
            let month = monthStart(focus, calendar: calendar)
            let start = weekStart(month, calendar: calendar)
            let prefix = calendar.dateComponents([.day], from: start, to: month).day ?? 0
            let length = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
            return days(from: start, count: ((prefix + length + 6) / 7) * 7, calendar: calendar)
        case .year:
            let start = calendar.dateInterval(of: .year, for: focus)?.start ?? monthStart(focus, calendar: calendar)
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return days(from: start, count: calendar.dateComponents([.day], from: start, to: end).day ?? 365, calendar: calendar)
        }
    }
    public static func interval(for days: [Date], calendar: Calendar) -> DateInterval? {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        return DateInterval(start: first, end: end)
    }
    public static func navigate(_ date: Date, direction: Int, mode: TaskCalendarMode, options: TaskCalendarOptions, calendar: Calendar,
                                monthZoom: CalendarMonthZoom = .full) -> Date {
        if mode == .month, let count = monthZoom.weekCount {
            return calendar.date(byAdding: .day, value: (direction < 0 ? -count : count) * 7,
                                 to: weekStart(date, calendar: calendar)) ?? date
        }
        let component: Calendar.Component
        let amount: Int
        switch mode {
        case .day: component = .day; amount = 1
        case .week: component = .day; amount = 7
        case .multiDay: component = .day; amount = min(14, max(2, options.multiDayCount))
        case .multiWeek: component = .day; amount = min(6, max(2, options.multiWeekCount)) * 7
        case .agenda: component = .day; amount = CalendarAgendaWindow.initialDayCount
        case .month: component = .month; amount = 1
        case .year: component = .year; amount = 1
        }
        let base = mode == .month ? monthStart(date, calendar: calendar) : date
        return calendar.date(byAdding: component, value: (direction < 0 ? -amount : amount), to: base) ?? date
    }
    public static func snappedMinute(_ value: Double, step: Int = 15) -> Int {
        guard value.isFinite else { return 0 }
        let step = max(1, step)
        return min(1_440, max(0, Int((min(1_440, max(0, value)) / Double(step)).rounded()) * step))
    }
    /// Wall-clock positions, not seconds since midnight on 23/25-hour days.
    public static func instant(on day: Date, minute: Int, calendar: Calendar) -> Date {
        let minute = min(1_440, max(0, minute))
        if minute == 1_440 { return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? day }
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? day
    }
    /// All-day dates float by civil date between task and display zones.
    public static func civilDay(_ date: Date, from source: Calendar, to destination: Calendar) -> Date {
        destination.date(from: source.dateComponents([.era, .year, .month, .day], from: date)) ?? destination.startOfDay(for: date)
    }
}

public enum CalendarRangeEdge: Sendable { case start, end }

public struct CalendarEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var taskID: UUID
    public var checklistID: UUID? = nil
    public var title: String
    public var start: Date
    /// Exclusive display end, including all-day spans.
    public var end: Date
    public var due: Date
    public var isAllDay: Bool
    public var isProjected: Bool
    public var isCompleted: Bool
    public var isNote: Bool
    public var hasDuration: Bool = false
    public var color: String
    public var listID: UUID?
    public var canSchedule: Bool { !isProjected && checklistID == nil }
    public var canResizeAllDayRange: Bool { isAllDay && hasDuration && canSchedule }

    /// The projected end is exclusive. Gesture targets and stored all-day
    /// deadlines are inclusive civil days in their respective calendars.
    public func allDayResizeTarget(on day: Date, edge: CalendarRangeEdge = .end, calendar: Calendar) -> Date? {
        guard canResizeAllDayRange,
              let last = calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        let first = calendar.startOfDay(for: start)
        let proposed = calendar.startOfDay(for: day)
        switch edge {
        case .start:
            let target = min(last, proposed)
            return calendar.isDate(target, inSameDayAs: first) ? nil : target
        case .end:
            let target = max(first, proposed)
            return calendar.isDate(target, inSameDayAs: last) ? nil : target
        }
    }
    public func overlaps(_ interval: DateInterval) -> Bool { start < interval.end && end > interval.start }
}

public struct CalendarProjectionResult: Sendable {
    public var entries: [CalendarEntry]
    public var truncatedTaskIDs: Set<UUID>
}
