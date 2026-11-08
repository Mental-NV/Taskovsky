import SwiftUI
import TaskovskyCore

enum CalendarDrag {
    static func payload(_ id: UUID) -> String { "taskovsky-calendar:\(id.uuidString)" }
    static func id(_ value: String) -> UUID? {
        guard value.hasPrefix("taskovsky-calendar:") else { return nil }
        return UUID(uuidString: String(value.dropFirst("taskovsky-calendar:".count)))
    }
}
extension View {
    @ViewBuilder func calendarDraggable(_ entry: CalendarEntry) -> some View {
        if entry.canSchedule { self.draggable(CalendarDrag.payload(entry.taskID)) } else { self }
    }
}

struct CalendarEntryView: View {
    var entry: CalendarEntry
    var style: CalendarItemStyle
    var calendar: Calendar
    var compact = false
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var edit: (CalendarEntry) -> Void
    private var tint: Color { Color(hex: entry.color) }
    private var time: String {
        if entry.isAllDay { return "All day" }
        if entry.hasDuration { return CalendarText.time(entry.start, calendar: calendar) + " – " + CalendarText.time(entry.due, calendar: calendar) }
        return CalendarText.time(entry.due, calendar: calendar)
    }
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            if entry.isProjected {
                Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(tint)
                    .accessibilityLabel("Future repeat preview")
            } else if entry.isNote {
                Image(systemName: "doc.text").font(.system(size: 10)).foregroundStyle(tint)
            } else if entry.checklistID != nil {
                Image(systemName: entry.isCompleted ? "checkmark.square" : "square").font(.system(size: 10)).foregroundStyle(tint)
            } else {
                Button { complete(entry.taskID) } label: {
                    Image(systemName: entry.isCompleted ? "checkmark.square.fill" : "square").font(.system(size: 10))
                }.buttonStyle(.plain).foregroundStyle(tint)
                    .accessibilityLabel((entry.isCompleted ? "Reopen " : "Complete ") + entry.title)
            }
            Button { open(entry.taskID) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).lineLimit(compact ? 1 : 2)
                        .strikethrough(entry.isCompleted).frame(maxWidth: .infinity, alignment: .leading)
                    if !compact { Text(time).font(.system(size: 10)).foregroundStyle(.secondary) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel((entry.isProjected ? "Preview: " : "") + entry.title + ", " + time)
        }
        .font(.system(size: compact ? 11 : 12))
        .padding(.horizontal, 5).padding(.vertical, compact ? 3 : 5)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
        .background(style == .filled ? tint.opacity(entry.isCompleted ? 0.06 : 0.15) : Color.clear)
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
        .overlay { if style == .outline { RoundedRectangle(cornerRadius: 3).stroke(tint.opacity(0.5), lineWidth: 0.7) } }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .opacity(entry.isProjected ? 0.7 : entry.isCompleted ? 0.6 : 1)
        .help((entry.isProjected ? "Future repeat preview. Open the repeating task.\n" : "") + entry.title + "\n" + time)
        .contextMenu {
            Button(entry.isProjected ? "Open repeating task" : "Open task") { open(entry.taskID) }
            if entry.canSchedule { Button("Schedule…") { edit(entry) } }
        }
    }
}

struct CalendarMiniMonth: View {
    var month: Date
    var selected: Date?
    var range: DateInterval?
    var counts: [Date: Int] = [:]
    var heatmap = false
    var calendar: Calendar
    var select: (Date) -> Void
    private var days: [Date] { CalendarDates.visibleDays(focus: month, mode: .month, options: .init(), calendar: calendar) }
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + offset) % 7])
                        .font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                ForEach(days, id: \.self) { day in
                    let picked = selected.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let count = counts[day, default: 0]
                    let within = range.map { day >= $0.start && day < $0.end } ?? false
                    Button { select(day) } label: {
                        VStack(spacing: 1) {
                            Text("\(calendar.component(.day, from: day))").font(.system(size: 11))
                            Circle().fill(count > 0 && !heatmap ? Color.accentColor : Color.clear).frame(width: 3, height: 3)
                        }.frame(maxWidth: .infinity).frame(height: 24)
                            .foregroundStyle(picked ? Color.white : calendar.isDate(day, equalTo: month, toGranularity: .month) ? Color.primary : Color.secondary.opacity(0.45))
                            .background {
                                if picked { RoundedRectangle(cornerRadius: 12).fill(Color.accentColor) }
                                else if heatmap && count > 0 { RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(min(0.7, 0.1 + Double(count) * 0.1))) }
                                else if within { RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.1)) }
                            }
                            .overlay { if calendar.isDateInToday(day) && !picked { Circle().stroke(Color.accentColor, lineWidth: 1).frame(width: 23, height: 23) } }
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
    private var calendar: Calendar { store.settings.calendar }
    private var activeLists: [TaskList] { store.data.lists.filter { !$0.isArchived } }
    var body: some View {
        let miniDays = CalendarDates.visibleDays(focus: month, mode: .month, options: .init(), calendar: calendar)
        let miniRange = CalendarDates.interval(for: miniDays, calendar: calendar) ?? range
        let entries = TaskCalendarProjection.project(data: store.data, range: miniRange, options: store.settings.calendarOptions, calendar: calendar).entries
        let counts = CalendarDayCounts.count(entries, days: miniDays, calendar: calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { month = calendar.date(byAdding: .month, value: -1, to: CalendarDates.monthStart(month, calendar: calendar)) ?? month } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Calendar sidebar previous month")
                    Spacer()
                    Text(CalendarText.date(month, "MMMM y", calendar: calendar)).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button { month = calendar.date(byAdding: .month, value: 1, to: CalendarDates.monthStart(month, calendar: calendar)) ?? month } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Calendar sidebar next month")
                }.buttonStyle(.plain)
                CalendarMiniMonth(month: month, selected: focus, range: range, counts: counts, calendar: calendar) { focus = $0 }
                Divider()
                Toggle("All lists", isOn: Binding(get: {
                    store.settings.calendarOptions.listIDs == nil && store.settings.calendarOptions.includeInbox
                }, set: { enabled in
                    store.settings.calendarOptions.listIDs = enabled ? nil : []
                    store.settings.calendarOptions.includeInbox = enabled
                }))
                Toggle("Inbox", isOn: $store.settings.calendarOptions.includeInbox).accessibilityLabel("Calendar list Inbox")
                ForEach(activeLists) { list in
                    Toggle(isOn: Binding(get: {
                        store.settings.calendarOptions.listIDs?.contains(list.id) ?? true
                    }, set: { enabled in
                        var ids = store.settings.calendarOptions.listIDs ?? activeLists.map(\.id)
                        if enabled { if !ids.contains(list.id) { ids.append(list.id) } } else { ids.removeAll { $0 == list.id } }
                        store.settings.calendarOptions.listIDs = ids
                    })) {
                        HStack(spacing: 6) { Circle().fill(Color(hex: list.color)).frame(width: 7, height: 7); Text(list.name).lineLimit(2) }
                    }.accessibilityLabel("Calendar list " + list.name)
                        .contextMenu { Button("Show only this list") { store.settings.calendarOptions.listIDs = [list.id]; store.settings.calendarOptions.includeInbox = false } }
                }
                if !store.data.tags.isEmpty || !store.settings.calendarOptions.tagIDs.isEmpty {
                    Divider()
                    HStack {
                        Text("Tags").foregroundStyle(.secondary)
                        Spacer()
                        if !store.settings.calendarOptions.tagIDs.isEmpty { Button("Clear") { store.settings.calendarOptions.tagIDs = [] }.buttonStyle(.borderless) }
                    }
                    ForEach(store.data.tags) { tag in
                        Toggle(tag.name, isOn: Binding(get: { store.settings.calendarOptions.tagIDs.contains(tag.id) }, set: { enabled in
                            if enabled { store.settings.calendarOptions.tagIDs.append(tag.id) }
                            else { store.settings.calendarOptions.tagIDs.removeAll { $0 == tag.id } }
                        })).accessibilityLabel("Calendar tag " + tag.name)
                    }
                    if store.settings.calendarOptions.tagIDs.contains(where: { id in !store.data.tags.contains { $0.id == id } }) {
                        Text("A selected tag is unavailable. Clear removes the tag filter.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Text("Selected tags narrow the visible tasks. Parent tags include their children.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.font(.system(size: 12)).toggleStyle(.checkbox).padding(16)
        }.background(Color(nsColor: .windowBackgroundColor))
            .onAppear { month = CalendarDates.monthStart(focus, calendar: calendar) }
            .onChange(of: focus) { _, value in month = CalendarDates.monthStart(value, calendar: calendar) }
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
        var scope = store.settings.calendarOptions
        if list == "inbox" { scope.listIDs = []; scope.includeInbox = true }
        else if let id = UUID(uuidString: list) { scope.listIDs = [id]; scope.includeInbox = false }
        return TaskCalendarProjection.arrangementTasks(data: store.data, options: scope, overdue: overdue, calendar: calendar)
    }
    private var groups: [(String, [TaskItem])] {
        var result: [String: [TaskItem]] = [:]
        for task in tasks {
            let key: String
            switch grouping {
            case .list: key = task.listID.flatMap { id in store.data.lists.first { $0.id == id }?.name } ?? "Inbox"
            case .tag: key = task.tagIDs.first.flatMap { id in store.data.tags.first { $0.id == id }?.name } ?? "No Tags"
            case .priority: key = task.priority.rawValue.capitalized
            }
            result[key, default: []].append(task)
        }
        return result.keys.sorted().map { ($0, result[$0] ?? []) }
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
                                        .draggable(CalendarDrag.payload(task.id))
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
                                    .draggable(CalendarDrag.payload(task.id))
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
