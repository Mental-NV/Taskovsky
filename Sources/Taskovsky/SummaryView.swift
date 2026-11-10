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

    private typealias Period = SummaryReportOptions.Period
    private typealias Grouping = SummaryReportOptions.Grouping
    private typealias Field = SummaryReportOptions.Field
    private var calendar: Calendar { store.settings.calendar }
    private var reportOptions: SummaryReportOptions {
        SummaryReportOptions(period: period, customStart: customStart, customEnd: customEnd, listIDs: listIDs,
                             status: status, grouping: grouping, fields: fields, nextPeriod: nextPeriod)
    }
    private var rangeLabel: String {
        SummaryReport.rangeLabel(for: reportOptions.interval(now: Date(), calendar: calendar), calendar: calendar)
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
    private func regenerate() {
        saved = false
        output = SummaryReport.generate(from: store.data, options: reportOptions, now: Date(), calendar: calendar).text
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
