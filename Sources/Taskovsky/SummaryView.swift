import SwiftUI
import AppKit
import TaskovskyCore

/// A local, editable plain-text report. Changing a filter regenerates the report.
struct SummaryView: View {
    @ObservedObject var store: TaskStore
    @State private var period: Period = .thisWeek
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var listIDs: Set<UUID> = []
    @State private var status: FilterStatus = .all
    @State private var grouping: Grouping = .status
    @State private var fields: Set<Field> = [.date, .list, .description]
    @State private var nextPeriod = false
    @State private var output = ""
    @State private var showOptions = false
    @State private var saved = false

    private enum Period: String, CaseIterable { case thisWeek = "This Week", lastWeek = "Last Week", thisMonth = "This Month", today = "Today", custom = "Custom" }
    private enum Grouping: String, CaseIterable { case status = "By Completion Status", list = "By List", date = "By Date" }
    private enum Field: String, CaseIterable { case date = "Date", list = "List", description = "Description", tags = "Tags", priority = "Priority" }
    private var calendar: Calendar { store.settings.calendar }
    private var interval: DateInterval {
        let now = Date()
        switch period {
        case .today: return calendar.dateInterval(of: .day, for: now)!
        case .thisWeek: return calendar.dateInterval(of: .weekOfYear, for: now)!
        case .lastWeek:
            let week = calendar.dateInterval(of: .weekOfYear, for: now)!
            return DateInterval(start: calendar.date(byAdding: .weekOfYear, value: -1, to: week.start)!, end: week.start)
        case .thisMonth: return calendar.dateInterval(of: .month, for: now)!
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(customStart, customEnd)))!
            return DateInterval(start: start, end: end)
        }
    }
    private var rangeLabel: String {
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Text("Summary").font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button { regenerate() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("Regenerate summary")
                    if geometry.size.width < 650 {
                        Button { showOptions.toggle() } label: { Label("Filter", systemImage: "line.3.horizontal.decrease.circle") }
                            .popover(isPresented: $showOptions, arrowEdge: .bottom) { options.frame(width: 250).padding(16) }
                    }
                }.padding(.horizontal, 24).frame(height: 58)
                Divider()
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        TextEditor(text: $output).font(.system(size: 14)).padding(16)
                        Divider()
                        HStack {
                            if saved { Text("Saved as note").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button("Save as Note", action: saveAsNote)
                            Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string) }
                        }.padding(14)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if geometry.size.width >= 650 {
                        Divider()
                        ScrollView { options.padding(16) }.frame(width: 220)
                    }
                }
            }
        }
        .onAppear(perform: regenerate)
        .onChange(of: period) { _, _ in regenerate() }
        .onChange(of: customStart) { _, _ in if period == .custom { regenerate() } }
        .onChange(of: customEnd) { _, _ in if period == .custom { regenerate() } }
        .onChange(of: listIDs) { _, _ in regenerate() }
        .onChange(of: status) { _, _ in regenerate() }
        .onChange(of: grouping) { _, _ in regenerate() }
        .onChange(of: fields) { _, _ in regenerate() }
        .onChange(of: nextPeriod) { _, _ in regenerate() }
    }
    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Filter").font(.system(size: 14, weight: .semibold))
            optionRow("Date") {
                Menu {
                    ForEach(Period.allCases, id: \.self) { value in Button(value.rawValue) { period = value } }
                } label: { valueLabel(period.rawValue) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            Text(rangeLabel).font(.system(size: 11)).foregroundStyle(.secondary)
            if period == .custom {
                DatePicker("From", selection: $customStart, displayedComponents: .date)
                DatePicker("To", selection: $customEnd, displayedComponents: .date)
            }
            optionRow("Lists") {
                Menu {
                    Button("All Lists") { listIDs.removeAll() }
                    Toggle("Inbox", isOn: listMembership(TaskFilter.inboxListID))
                    ForEach(store.data.lists) { list in Toggle(list.name, isOn: listMembership(list.id)) }
                } label: { valueLabel(listIDs.isEmpty ? "All Lists" : "\(listIDs.count) selected") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            optionRow("Status") {
                Menu {
                    Button("All Status") { status = .all }; Button("Undone") { status = .active }
                    Button("Completed") { status = .completed }; Button("Won't Do") { status = .wontDo }
                } label: { valueLabel(statusName(status)) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            Divider()
            Text("Display Options").font(.system(size: 14, weight: .semibold))
            optionRow("Grouping") {
                Menu { ForEach(Grouping.allCases, id: \.self) { value in Button(value.rawValue) { grouping = value } } }
                label: { valueLabel(grouping.rawValue) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            optionRow("Fields") {
                Menu { ForEach(Field.allCases, id: \.self) { field in Toggle(field.rawValue, isOn: fieldMembership(field)) } }
                label: { valueLabel("\(fields.count) selected") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            Toggle("Next Period Tasks", isOn: $nextPeriod).toggleStyle(.switch).controlSize(.small)
            Spacer(minLength: 0)
        }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).foregroundStyle(.secondary); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func valueLabel(_ value: String) -> some View { HStack(spacing: 5) { Text(value); Image(systemName: "chevron.down").font(.system(size: 9)) } }
    private func listMembership(_ id: UUID) -> Binding<Bool> { Binding(get: { listIDs.contains(id) }, set: { if $0 { listIDs.insert(id) } else { listIDs.remove(id) } }) }
    private func fieldMembership(_ field: Field) -> Binding<Bool> { Binding(get: { fields.contains(field) }, set: { if $0 { fields.insert(field) } else { fields.remove(field) } }) }
    private func statusName(_ value: FilterStatus) -> String { switch value { case .all: "All Status"; case .active: "Undone"; case .completed: "Completed"; case .wontDo: "Won't Do" } }
    private func listName(_ task: TaskItem) -> String { store.data.lists.first { $0.id == task.listID }?.name ?? "Inbox" }
    private func inPeriod(_ date: Date?) -> Bool { date.map { $0 >= interval.start && $0 < interval.end } ?? false }
    private func statusMatches(_ task: TaskItem) -> Bool {
        switch status { case .all: true; case .active: task.completedAt == nil && task.wontDoAt == nil; case .completed: task.completedAt != nil; case .wontDo: task.wontDoAt != nil }
    }
    private func taskLine(_ task: TaskItem) -> String {
        var details: [String] = []
        if fields.contains(.date), let due = task.dueDate { details.append(task.dayText(due) + (task.hasDueTime ? " " + task.timeText(due) : "")) }
        if fields.contains(.list) { details.append(listName(task)) }
        if fields.contains(.tags) { let names = store.data.tags.filter { task.tagIDs.contains($0.id) }.map { "#" + $0.name }; if !names.isEmpty { details.append(names.joined(separator: " ")) } }
        if fields.contains(.priority), task.priority != .none { details.append(task.priority.label) }
        var line = "- " + task.title + (details.isEmpty ? "" : " (" + details.joined(separator: " · ") + ")")
        if fields.contains(.description), !task.body.isEmpty { line += "\n  " + task.body.replacingOccurrences(of: "\n", with: "\n  ") }
        return line
    }
    private func regenerate() {
        saved = false
        let eligible = store.data.tasks.filter { task in
            task.deletedAt == nil && task.kind == .task && (listIDs.isEmpty || listIDs.contains(task.listID ?? TaskFilter.inboxListID)) && statusMatches(task)
        }
        let current = eligible.filter { inPeriod($0.dueDate) || inPeriod($0.completedAt) || inPeriod($0.wontDoAt) }
        var sections: [(String, [TaskItem])] = []
        switch grouping {
        case .status:
            sections = [("Undone", current.filter { $0.completedAt == nil && $0.wontDoAt == nil }), ("Completed", current.filter { $0.completedAt != nil }), ("Won't Do", current.filter { $0.wontDoAt != nil })]
        case .list:
            let names = Set(current.map(listName)).sorted()
            sections = names.map { name in (name, current.filter { listName($0) == name }) }
        case .date:
            let keys = Set(current.map { $0.dueDate.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: $0.completedAt ?? $0.wontDoAt ?? interval.start) }).sorted()
            sections = keys.map { date in (date.formatted(date: .abbreviated, time: .omitted), current.filter { task in calendar.isDate(task.dueDate ?? task.completedAt ?? task.wontDoAt ?? interval.start, inSameDayAs: date) }) }
        }
        var lines = ["Summary · \(rangeLabel)"]
        for (name, tasks) in sections where !tasks.isEmpty { lines.append("\n\(name)\n" + tasks.map(taskLine).joined(separator: "\n")) }
        if nextPeriod {
            let nextEnd: Date
            switch period {
            case .today: nextEnd = calendar.date(byAdding: .day, value: 1, to: interval.end) ?? interval.end
            case .thisWeek, .lastWeek: nextEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: interval.end) ?? interval.end
            case .thisMonth: nextEnd = calendar.date(byAdding: .month, value: 1, to: interval.end) ?? interval.end
            case .custom: nextEnd = calendar.date(byAdding: .day, value: calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1, to: interval.end) ?? interval.end
            }
            let upcoming = eligible.filter { task in task.completedAt == nil && task.wontDoAt == nil && task.dueDate.map { $0 >= interval.end && $0 < nextEnd } == true }
            if !upcoming.isEmpty { lines.append("\nNext Period Tasks\n" + upcoming.map(taskLine).joined(separator: "\n")) }
        }
        output = lines.joined(separator: "\n")
    }
    private func saveAsNote() {
        let id = store.createTask(title: "Summary \(rangeLabel)", kind: .note, useDefaultList: false, recognizeDates: false, body: output)
        if var note = store.data.tasks.first(where: { $0.id == id }) {
            note.dueDate = nil; note.reminderDates = []; note.reminderFollowsSchedule = false; note.tagIDs = []; note.priority = .none
            store.updateTask(note, applyDefaultReminders: false)
        }
        saved = true
    }
}
