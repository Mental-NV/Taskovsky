import SwiftUI
import AppKit
import TaskovskyCore

/// A local, editable plain-text report. Changing a filter regenerates the report.
struct SummaryView: View {
    @ObservedObject var store: TaskStore
    @State private var reportOptions = SummaryReportOptions(customStart: Date(), customEnd: Date())
    @State private var output = ""
    @State private var showOptions = false
    @State private var saved = false
    @AppStorage("Taskovsky.summaryPresets.v1", store: IsolatedDefaults.store) private var presetData = Data()
    @State private var showPresetName = false
    @State private var presetName = ""
    @State private var renamingPreset: SummaryReportPreset?
    @State private var showPresetDelete = false
    @State private var deletingPreset: SummaryReportPreset?
    @State private var presetError = false

    private typealias Period = SummaryReportOptions.Period
    private typealias Grouping = SummaryReportOptions.Grouping
    private typealias Field = SummaryReportOptions.Field
    private var calendar: Calendar { store.settings.calendar }
    private var presets: SummaryReportPresets? { SummaryReportPresets(stored: presetData) }
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
                            .popover(isPresented: $showOptions, arrowEdge: .bottom) {
                                ScrollView { options.padding(16) }
                                    .frame(width: 282)
                                    .frame(maxHeight: max(120, min(520, geometry.size.height - 96)))
                            }
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
        .onChange(of: reportOptions) { _, _ in regenerate() }
        .alert(renamingPreset == nil ? "Save Summary Preset" : "Rename Summary Preset", isPresented: $showPresetName) {
            TextField("Name", text: $presetName)
            Button("Cancel", role: .cancel) {}
            Button("Save", action: savePreset)
                .disabled(presets?.accepts(presetName, renaming: renamingPreset?.id) != true)
        } message: {
            Text("Choose a unique name for this preset.")
        }
        .alert("Delete Summary Preset?", isPresented: $showPresetDelete, presenting: deletingPreset) { preset in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard var updated = presets else { return }
                updated.remove(preset.id)
                storePresets(updated)
            }
        } message: { preset in
            Text(preset.name)
        }
        .alert("Could Not Save Summary Presets", isPresented: $presetError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var presetMenu: some View {
        Menu {
            Button("Save Current Options…") { editPresetName() }
            if let entries = presets?.entries, !entries.isEmpty {
                Divider()
                ForEach(entries) { preset in
                    Button(preset.name) { reportOptions = preset.options }
                }
                Menu("Manage Presets") {
                    ForEach(entries) { preset in
                        Menu(preset.name) {
                            Button("Rename…") { editPresetName(preset) }
                            Button("Delete…", role: .destructive) {
                                deletingPreset = preset
                                showPresetDelete = true
                            }
                        }
                    }
                }
            }
        } label: {
            valueLabel(presets == nil ? "Presets Unavailable" : "Presets")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel("Summary presets")
        .disabled(presets == nil)
    }

    private func editPresetName(_ preset: SummaryReportPreset? = nil) {
        renamingPreset = preset
        presetName = preset?.name ?? ""
        showPresetName = true
    }

    private func savePreset() {
        guard var updated = presets else { return }
        let changed = if let renamingPreset {
            updated.rename(renamingPreset.id, to: presetName)
        } else {
            updated.save(presetName, options: reportOptions)
        }
        if changed { storePresets(updated) }
        else { presetError = true }
    }

    private func storePresets(_ updated: SummaryReportPresets) {
        do { presetData = try updated.encoded() }
        catch { presetError = true }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            presetMenu
            Divider()
            Text("Filter").font(.system(size: 14, weight: .semibold))
            optionRow("Date") {
                Menu {
                    ForEach(Period.allCases, id: \.self) { value in Button(value.rawValue) { reportOptions.period = value } }
                } label: { valueLabel(reportOptions.period.rawValue) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            Text(rangeLabel).font(.system(size: 11)).foregroundStyle(.secondary)
            if reportOptions.period == .custom {
                DatePicker("From", selection: $reportOptions.customStart, displayedComponents: .date)
                DatePicker("To", selection: $reportOptions.customEnd, displayedComponents: .date)
            }
            optionRow("Lists") {
                Menu {
                    Button("All Lists") { reportOptions.listIDs.removeAll() }
                    Toggle("Inbox", isOn: membership(TaskFilter.inboxListID, in: $reportOptions.listIDs))
                    ForEach(store.data.lists) { list in Toggle(list.name, isOn: membership(list.id, in: $reportOptions.listIDs)) }
                } label: { valueLabel(reportOptions.listIDs.isEmpty ? "All Lists" : "\(reportOptions.listIDs.count) selected") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            optionRow("Status") {
                Menu {
                    Button("All Status") { reportOptions.status = .all }; Button("Undone") { reportOptions.status = .active }
                    Button("Completed") { reportOptions.status = .completed }; Button("Won't Do") { reportOptions.status = .wontDo }
                } label: { valueLabel(statusName(reportOptions.status)) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            optionRow("Tags") {
                Menu {
                    Button("All Tags") { reportOptions.tagIDs.removeAll() }
                    ForEach(store.data.tags) { tag in
                        Toggle(tag.name, isOn: membership(tag.id, in: $reportOptions.tagIDs))
                    }
                } label: { valueLabel(reportOptions.tagIDs.isEmpty ? "All Tags" : "\(reportOptions.tagIDs.count) selected") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Summary tags")
            }
            optionRow("Priority") {
                Menu {
                    Button("All Priorities") { reportOptions.priorities.removeAll() }
                    ForEach(TaskPriority.allCases.reversed(), id: \.self) { priority in
                        Toggle(priority.label, isOn: membership(priority, in: $reportOptions.priorities))
                    }
                } label: { valueLabel(reportOptions.priorities.isEmpty ? "All Priorities" : "\(reportOptions.priorities.count) selected") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Summary priority")
            }
            Divider()
            Text("Display Options").font(.system(size: 14, weight: .semibold))
            optionRow("Grouping") {
                Menu { ForEach(Grouping.allCases, id: \.self) { value in Button(value.rawValue) { reportOptions.grouping = value } } }
                label: { valueLabel(reportOptions.grouping.rawValue) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            optionRow("Sort") {
                Menu { ForEach(SummaryReportOptions.Sort.allCases, id: \.self) { value in Button(value.rawValue) { reportOptions.sort = value } } }
                label: { valueLabel(reportOptions.sort.rawValue) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Summary sort")
            }
            optionRow("Fields") {
                Menu { ForEach(Field.allCases, id: \.self) { field in Toggle(field.rawValue, isOn: membership(field, in: $reportOptions.fields)) } }
                label: { valueLabel("\(reportOptions.fields.count) selected") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
            }
            Toggle("Next Period Tasks", isOn: $reportOptions.nextPeriod).toggleStyle(.switch).controlSize(.small)
            Spacer(minLength: 0)
        }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).foregroundStyle(.secondary); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func valueLabel(_ value: String) -> some View { HStack(spacing: 5) { Text(value); Image(systemName: "chevron.down").font(.system(size: 9)) } }
    private func membership<Value: Hashable>(_ value: Value, in set: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { selected in
            if selected { set.wrappedValue.insert(value) }
            else { set.wrappedValue.remove(value) }
        })
    }
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
