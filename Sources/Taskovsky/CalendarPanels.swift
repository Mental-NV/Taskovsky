import SwiftUI
import TaskovskyCore

enum CalendarDrag {
    static func id(_ payloads: [TaskDragPayload]) -> UUID? {
        guard payloads.count == 1, let ids = payloads.first?.ids, ids.count == 1 else { return nil }
        return ids.first
    }
}
extension View {
    @ViewBuilder func calendarDraggable(_ entry: CalendarEntry) -> some View {
        if entry.canSchedule { self.draggable(TaskDragPayload(ids: [entry.taskID])) } else { self }
    }
}

extension EnvironmentValues {
    @Entry var calendarTemporarilyShowsIcons = false
}

struct CalendarEntryView: View {
    @Environment(\.calendarTemporarilyShowsIcons) private var temporarilyShowsIcons
    var entry: CalendarEntry
    var style: CalendarItemStyle
    var calendar: Calendar
    var showItemIcons = true
    var compact = false
    var trailingInset: CGFloat = 0
    // Timed cards paint their whole allocated duration, including compact cards.
    var fillsAllocatedHeight = false
    var open: (UUID) -> Void
    var complete: (CalendarEntry) -> Void
    var edit: (CalendarEntry) -> Void
    private var tint: Color { Color(hex: entry.color) }
    private var completionAction: String {
        (entry.isCompleted ? "Reopen " : "Complete ") + (entry.checklistID == nil ? "task" : "checklist item")
    }
    private var time: String {
        if entry.isAllDay { return "All day" }
        if entry.hasDuration { return CalendarText.time(entry.start, calendar: calendar) + " – " + CalendarText.time(entry.due, calendar: calendar) }
        return CalendarText.time(entry.due, calendar: calendar)
    }
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            if showItemIcons || temporarilyShowsIcons {
                if entry.isProjected {
                    Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(tint)
                        .accessibilityLabel("Future repeat preview")
                } else if entry.isNote {
                    Image(systemName: "doc.text").font(.system(size: 10)).foregroundStyle(tint)
                } else if entry.canChangeCompletion {
                    Button { complete(entry) } label: {
                        Image(systemName: entry.isCompleted ? "checkmark.square.fill" : "square").font(.system(size: 10))
                    }.buttonStyle(.plain).foregroundStyle(tint)
                        .accessibilityLabel((entry.isCompleted ? "Reopen " : "Complete ") + entry.title)
                }
            }
            Button { open(entry.taskID) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).lineLimit(1)
                        .strikethrough(entry.isCompleted).frame(maxWidth: .infinity, alignment: .leading)
                    if !compact { Text(time).font(.system(size: 10)).lineLimit(1).foregroundStyle(.secondary) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel((entry.isProjected ? "Preview: " : "") + entry.title + ", " + time)
                .accessibilityActions {
                    if entry.canChangeCompletion { Button(completionAction) { complete(entry) } }
                }
        }
        .font(.system(size: compact ? 11 : 12))
        .padding(.horizontal, 4).padding(.vertical, compact ? 1 : 4)
        .padding(.trailing, trailingInset)
        .frame(maxWidth: .infinity, maxHeight: compact && !fillsAllocatedHeight ? nil : .infinity, alignment: .topLeading)
        .background(style == .filled ? tint.opacity(entry.isCompleted ? 0.06 : 0.15) : Color.clear)
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
        .overlay { if style == .outline { RoundedRectangle(cornerRadius: 3).stroke(tint.opacity(0.5), lineWidth: 0.7) } }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .opacity(entry.isProjected ? 0.7 : entry.isCompleted ? 0.6 : 1)
        .help((entry.isProjected ? "Future repeat preview. Open the repeating task.\n" : "") + entry.title + "\n" + time)
        .contextMenu {
            Button(entry.isProjected ? "Open repeating task" : "Open task") { open(entry.taskID) }
            if entry.canChangeCompletion { Button(completionAction) { complete(entry) } }
            if entry.canSchedule { Button("Schedule…") { edit(entry) } }
        }
    }
}

struct CalendarMiniMonth: View {
    var month: Date
    var selected: Date?
    var range: DateInterval?
    var counts: [Date: Int] = [:]
    var calendar: Calendar
    var select: (Date) -> Void
    private var days: [Date] {
        CalendarDates.days(from: CalendarDates.weekStart(CalendarDates.monthStart(month, calendar: calendar), calendar: calendar), count: 42, calendar: calendar)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + offset) % 7])
                        .font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }.frame(height: 36)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let picked = selected.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let today = calendar.isDateInToday(day)
                    let count = counts[day, default: 0]
                    let within = range.map { day >= $0.start && day < $0.end } ?? false
                    Button { select(day) } label: {
                        ZStack {
                            if within { Rectangle().fill(Color.primary.opacity(0.055)).frame(height: 28) }
                            if picked { Circle().fill(CalendarAppearance.accent).frame(width: 28, height: 28) }
                            else if today { Circle().fill(CalendarAppearance.accent.opacity(0.1)).frame(width: 28, height: 28) }
                            Text("\(calendar.component(.day, from: day))").font(.system(size: 12))
                                .foregroundStyle(picked ? Color.white : today ? CalendarAppearance.accent : calendar.isDate(day, equalTo: month, toGranularity: .month) ? Color.primary : Color.secondary.opacity(0.5))
                            if count > 0 && !picked {
                                Circle().fill(CalendarAppearance.accent).frame(width: 3, height: 3).offset(y: 13)
                            }
                        }.frame(maxWidth: .infinity).frame(height: 34).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(CalendarText.date(day, "EEEE d MMMM y", calendar: calendar) + ", \(count) items")
                }
            }
        }
    }
}

struct CalendarNavigationSidebar: View {
    @ObservedObject var store: TaskStore
    @Binding var focus: Date
    var range: DateInterval
    @State private var month = Date()
    @State private var listsExpanded = false
    @State private var tagsExpanded = false
    private var calendar: Calendar { store.settings.calendar }
    private var activeLists: [TaskList] { store.data.lists.filter { !$0.isArchived } }
    private var highlightRange: DateInterval? {
        switch store.settings.calendarOptions.mode {
        case .year, .agenda: return nil
        case .month:
            return CalendarDates.interval(for: CalendarDates.days(from: CalendarDates.weekStart(focus, calendar: calendar), count: 7, calendar: calendar), calendar: calendar)
        default: return range
        }
    }
    var body: some View {
        let miniDays = CalendarDates.days(from: CalendarDates.weekStart(CalendarDates.monthStart(month, calendar: calendar), calendar: calendar), count: 42, calendar: calendar)
        let miniRange = CalendarDates.interval(for: miniDays, calendar: calendar) ?? range
        let entries = TaskCalendarProjection.project(data: store.data, range: miniRange, options: store.settings.calendarOptions, calendar: calendar).entries
        let counts = CalendarDayCounts.count(entries, days: miniDays, calendar: calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text(CalendarText.date(month, "MMMM y", calendar: calendar)).font(.system(size: 13)).lineLimit(1)
                    Spacer(minLength: 0)
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Calendar sidebar previous month")
                    Button { month = CalendarDates.monthStart(Date(), calendar: calendar); focus = Date() } label: { Image(systemName: "circle").font(.system(size: 8)) }
                        .accessibilityLabel("Calendar sidebar Today")
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Calendar sidebar next month")
                }.font(.system(size: 9)).foregroundStyle(.primary).buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.top, 10).frame(height: 54)
                CalendarMiniMonth(month: month, selected: [.day, .agenda].contains(store.settings.calendarOptions.mode) ? focus : nil, range: highlightRange, counts: counts, calendar: calendar) { focus = $0 }
                    .padding(.horizontal, 10).padding(.bottom, 20)
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    Button { updateSources { $0.selectAllSources() } } label: {
                        HStack {
                            Text("All"); Spacer(minLength: 4)
                            CalendarScopeIndicator(mark: store.settings.calendarOptions.isAllSources ? .on : .off, circular: true)
                        }.frame(height: 30).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .foregroundStyle(store.settings.calendarOptions.isAllSources ? CalendarAppearance.accent : Color.primary)
                        .accessibilityLabel("All Calendar sources")
                        .accessibilityValue(store.settings.calendarOptions.isAllSources ? "Selected" : "Not selected")
                        .help("Show all active lists and Inbox; clear selected tags")
                    sourceGroup("Lists", expanded: $listsExpanded, mark: store.settings.calendarOptions.listSelectionState(in: store.data)) {
                        let selected = store.settings.calendarOptions.listSelectionState(in: store.data) != .on
                        updateSources { $0.setListsSelected(selected, data: store.data) }
                    }
                    if listsExpanded {
                        CalendarScopeCheckbox(title: "Inbox", accessibilityTitle: "Calendar list Inbox", symbol: "tray", value: Binding(get: {
                            store.settings.calendarOptions.isInboxSelected
                        }, set: { selected in updateSources { $0.setInboxSelected(selected, data: store.data) } })).padding(.leading, 12)
                        ForEach(activeLists) { list in
                            CalendarScopeCheckbox(title: list.name, accessibilityTitle: "Calendar list " + list.name, color: list.color, value: Binding(get: {
                                store.settings.calendarOptions.selectedListIDs(in: store.data).contains(list.id)
                            }, set: { selected in updateSources { $0.setListSelected(list.id, selected, data: store.data) } })).padding(.leading, 12)
                                .contextMenu { Button("Show only this list") { updateSources { $0.selectOnlyList(list.id) } } }
                        }
                    }
                    sourceGroup("Tags", expanded: $tagsExpanded, mark: store.settings.calendarOptions.tagSelectionState(in: store.data),
                                disabled: store.data.tags.isEmpty && store.settings.calendarOptions.tagIDs.isEmpty) {
                        let selected = store.settings.calendarOptions.tagSelectionState(in: store.data) != .on
                        updateSources { $0.setTagsSelected(selected, data: store.data) }
                    }
                        if tagsExpanded {
                            if store.data.tags.isEmpty { Text("No tags").font(.system(size: 11)).foregroundStyle(.secondary).frame(height: 30) }
                            ForEach(store.data.tags) { tag in
                                CalendarScopeCheckbox(title: tag.name, accessibilityTitle: "Calendar tag " + tag.name, symbol: "tag", value: Binding(get: {
                                    !store.settings.calendarOptions.isAllSources && store.settings.calendarOptions.tagIDs.contains(tag.id)
                                }, set: { selected in updateSources { $0.setTagSelected(tag.id, selected, data: store.data) } })).padding(.leading, 12)
                            }
                        }
                    if hasUnavailableSources {
                        Text("Some selected sources are unavailable.").font(.system(size: 10)).foregroundStyle(.secondary)
                        Button("Clear unavailable sources") { updateSources { $0.clearUnavailableSources(data: store.data) } }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(CalendarAppearance.accent).padding(.vertical, 6)
                    } else if !store.settings.calendarOptions.isAllSources && store.settings.calendarOptions.listIDs?.isEmpty == true &&
                                !store.settings.calendarOptions.includeInbox && store.settings.calendarOptions.tagIDs.isEmpty {
                        Text("No Calendar sources selected. Choose All or a source.").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.font(.system(size: 13)).padding(.horizontal, 16).padding(.top, 18)
            }
        }.background(Color(nsColor: .textBackgroundColor))
            .onAppear { month = CalendarDates.monthStart(focus, calendar: calendar) }
            .onChange(of: focus) { _, value in month = CalendarDates.monthStart(value, calendar: calendar) }
    }
    private func shiftMonth(_ amount: Int) {
        month = calendar.date(byAdding: .month, value: amount, to: CalendarDates.monthStart(month, calendar: calendar)) ?? month
    }
    private var hasUnavailableSources: Bool {
        let lists = Set(activeLists.map(\.id)), tags = Set(store.data.tags.map(\.id))
        return store.settings.calendarOptions.listIDs?.contains(where: { !lists.contains($0) }) == true ||
            store.settings.calendarOptions.tagIDs.contains(where: { !tags.contains($0) })
    }
    private func updateSources(_ change: (inout TaskCalendarOptions) -> Void) {
        var options = store.settings.calendarOptions; change(&options); store.settings.calendarOptions = options
    }
    private func sourceGroup(_ title: String, expanded: Binding<Bool>, mark: CalendarFilterMark,
                             disabled: Bool = false, select: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button { expanded.wrappedValue.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8)).foregroundStyle(.secondary).frame(width: 4)
                    Text(title); Spacer(minLength: 4)
                }.frame(height: 30).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel((expanded.wrappedValue ? "Collapse Calendar " : "Expand Calendar ") + title.lowercased())
                .foregroundStyle(mark == .off ? Color.primary : CalendarAppearance.accent)
            Button(action: select) {
                CalendarScopeIndicator(mark: mark).frame(width: 20, height: 30, alignment: .trailing).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .disabled(disabled).accessibilityLabel("Calendar " + title.lowercased() + " group")
                .accessibilityValue(mark == .mixed ? "Partially selected" : mark == .on ? "All selected" : "None selected")
                .help(mark == .on ? "Clear selected " + title.lowercased() : "Select all " + title.lowercased())
        }.padding(.leading, -6)
    }
}

private struct CalendarScopeIndicator: View {
    var mark: CalendarFilterMark
    var circular = false
    var body: some View {
        Image(systemName: circular ? (mark == .on ? "checkmark.circle.fill" : "circle") :
                mark == .on ? "checkmark.square.fill" : mark == .mixed ? "minus.square.fill" : "square")
            .font(.system(size: 14)).foregroundStyle(mark == .off ? Color.secondary.opacity(0.6) : CalendarAppearance.accent)
            .frame(width: 14, height: 14).accessibilityHidden(true)
    }
}

private struct CalendarScopeCheckbox: View {
    var title: String
    var accessibilityTitle: String
    var color: String?
    var symbol: String?
    @Binding var value: Bool
    var body: some View {
        Button { value.toggle() } label: { HStack(spacing: 6) {
            if let color { Circle().fill(Color(hex: color)).frame(width: 7, height: 7) }
            if let symbol { Image(systemName: symbol).font(.system(size: 12)).frame(width: 14) }
            Text(title).lineLimit(1)
            Spacer(minLength: 4)
            CalendarScopeIndicator(mark: value ? .on : .off)
        }.frame(height: 30).contentShape(Rectangle()) }
            .buttonStyle(.plain).foregroundStyle(value ? CalendarAppearance.accent : Color.primary)
            .accessibilityRepresentation { Toggle(accessibilityTitle, isOn: $value) }
    }
}

enum CalendarDayCounts {
    static func count(_ entries: [CalendarEntry], days: [Date], calendar: Calendar) -> [Date: Int] {
        Dictionary(uniqueKeysWithValues: days.map { day in
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            return (day, entries.filter { $0.start < end && $0.end > day }.count)
        })
    }
}

struct CalendarArrangePanel: View {
    @ObservedObject var store: TaskStore
    var focus: Date
    var calendar: Calendar
    var close: () -> Void
    var open: (UUID) -> Void
    var schedule: (TaskItem) -> Void
    @State private var grouping = CalendarColorMode.list
    @State private var list = "all"
    @State private var overdue = false
    private var tasks: [TaskItem] {
        let selection: CalendarArrangeSelection
        if list == "inbox" { selection = .inbox }
        else if let id = UUID(uuidString: list) { selection = .list(id) }
        else { selection = .calendar }
        return TaskCalendarProjection.arrangementTasks(data: store.data, options: store.settings.calendarOptions,
            overdue: overdue, calendar: calendar, selection: selection)
    }
    private var groups: [(String, [TaskItem])] {
        TaskCalendarProjection.arrangementGroups(tasks, data: store.data, grouping: grouping)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Arrange tasks").font(.system(size: 13, weight: .semibold)); Spacer()
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Close Arrange tasks")
            }
            Picker("Group tasks", selection: $grouping) {
                ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Lists", selection: $list) {
                Text("All Lists").tag("all"); Text("Inbox").tag("inbox")
                ForEach(store.data.lists.filter { !$0.isArchived }) { Text($0.name).tag($0.id.uuidString) }
            }.labelsHidden()
            Toggle("Include overdue", isOn: $overdue).toggleStyle(.checkbox)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if tasks.isEmpty { Text("No unscheduled tasks").foregroundStyle(.secondary).padding(.vertical, 20) }
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(group.0) · \(group.1.count)").foregroundStyle(.secondary)
                            ForEach(group.1) { task in
                                HStack(spacing: 5) {
                                    Image(systemName: "line.3.horizontal")
                                        .frame(width: 12, height: 22).contentShape(Rectangle())
                                        .draggable(TaskDragPayload(ids: [task.id]))
                                        .foregroundStyle(.secondary).help("Drag to schedule")
                                        .accessibilityLabel("Drag " + task.title + " to schedule")
                                    Button { open(task.id) } label: {
                                        Label(task.title, systemImage: task.kind == .note ? "doc.text" : "square")
                                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain)
                                    Button { schedule(task) } label: { Image(systemName: "calendar.badge.plus") }
                                        .buttonStyle(.plain).accessibilityLabel("Schedule " + task.title)
                                }.padding(6)
                                    .background(Color(hex: TaskCalendarProjection.color(for: task, data: store.data, by: grouping)).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                                    .contentShape(Rectangle())
                                    .contextMenu { Button("Schedule…") { schedule(task) }; Button("Open task") { open(task.id) } }
                                    .draggable(TaskDragPayload(ids: [task.id]))
                            }
                        }
                    }
                }
            }
            Text("Drag onto a day or time, or use the schedule button.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.font(.system(size: 11)).padding(14).background(Color(nsColor: .windowBackgroundColor))
    }
}
