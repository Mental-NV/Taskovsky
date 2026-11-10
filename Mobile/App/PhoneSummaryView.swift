import SwiftUI
import TaskovskyDomain
import UIKit

struct PhoneSummaryView: View {
    @ObservedObject var model: PhoneWorkspaceModel
    @AppStorage private var presetData: Data
    @State private var options: SummaryReportOptions
    @State private var text = ""
    @State private var noteTitle = ""
    @State private var showFilters = false
    @State private var feedback: String?
    @FocusState private var editing: Bool

    init(model: PhoneWorkspaceModel) {
        self.model = model
        let key = model.isQA
            ? "TaskovskyMobile.qaSummaryPresets.v1." + (model.directory?.lastPathComponent ?? "invalid")
            : "TaskovskyMobile.summaryPresets.v1"
        _presetData = AppStorage(wrappedValue: Data(), key)
        _options = State(initialValue: SummaryReportOptions(customStart: model.now, customEnd: model.now))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Filter", systemImage: "line.3.horizontal.decrease") {
                    editing = false
                    showFilters = true
                }.accessibilityIdentifier("summaryFilter")
                Spacer()
                Button("Regenerate", systemImage: "arrow.clockwise") {
                    editing = false
                    regenerate()
                }.accessibilityIdentifier("summaryRegenerate")
            }.buttonStyle(.bordered)
            TextEditor(text: $text)
                .focused($editing).scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("summaryText").accessibilityLabel("Summary report")
                .padding(6)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            if let feedback {
                Text(feedback).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("summaryFeedback")
            }
            ViewThatFits(in: .horizontal) {
                HStack { Spacer(); reportActions }
                VStack(alignment: .trailing) { reportActions }
            }.buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 74)
        .onAppear { if noteTitle.isEmpty { regenerate() } }
        .onChange(of: options) { _, _ in regenerate() }
        .sheet(isPresented: $showFilters) {
            if let snapshot = model.document?.snapshot {
                PhoneSummaryFilters(options: $options, presetData: $presetData,
                                    lists: snapshot.workspace.lists, tags: snapshot.workspace.tags)
                    .environment(\.calendar, model.calendar)
            }
        }
    }

    @ViewBuilder private var reportActions: some View {
        Button("Copy") {
            let pasteboard: UIPasteboard
            if model.isQA {
                guard let session = model.directory?.lastPathComponent,
                      let privateBoard = UIPasteboard(name: .init(rawValue: "local.taskovsky.qa.summary." + session),
                                                     create: true) else { return }
                pasteboard = privateBoard
            } else {
                pasteboard = .general
            }
            pasteboard.string = text
            feedback = "Copied"
        }.accessibilityIdentifier("summaryCopy").disabled(noteTitle.isEmpty)
        Button("Save as Note") {
            editing = false
            Task {
                let saved = await model.saveSummaryNote(title: noteTitle, body: text)
                feedback = saved ? "Saved as note" : model.captureError ?? "Could not save the note."
            }
        }.accessibilityIdentifier("summarySave").disabled(!model.canBeginCapture || noteTitle.isEmpty)
    }

    private func regenerate() {
        guard let data = model.document?.snapshot.workspace else { return }
        let report = SummaryReport.generate(from: data, options: options, now: model.now, calendar: model.calendar)
        text = report.text
        noteTitle = report.noteTitle
        feedback = nil
    }
}

private struct PhoneSummaryFilters: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var options: SummaryReportOptions
    @Binding var presetData: Data
    let lists: [TaskList]
    let tags: [TaskTag]
    @State private var draft: SummaryReportOptions
    @State private var initialPresetData: Data
    @State private var draftPresets: SummaryReportPresets?
    @State private var presetError = false

    init(options: Binding<SummaryReportOptions>, presetData: Binding<Data>, lists: [TaskList], tags: [TaskTag]) {
        _options = options
        _presetData = presetData
        self.lists = lists
        self.tags = tags
        _draft = State(initialValue: options.wrappedValue)
        _initialPresetData = State(initialValue: presetData.wrappedValue)
        _draftPresets = State(initialValue: SummaryReportPresets(stored: presetData.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    if let presets = Binding($draftPresets) {
                        NavigationLink {
                            PhoneSummaryPresetList(presets: presets, options: $draft)
                        } label: {
                            Label("Summary Presets", systemImage: "bookmark")
                        }
                        .accessibilityIdentifier("summaryPresets")
                    } else {
                        Text("Presets Unavailable").foregroundStyle(.secondary)
                    }
                }
                Section("Scope") {
                    Picker("Period", selection: $draft.period) {
                        ForEach(SummaryReportOptions.Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("summaryPeriod")
                    if draft.period == .custom {
                        DatePicker("From", selection: $draft.customStart, displayedComponents: .date)
                        DatePicker("To", selection: $draft.customEnd, displayedComponents: .date)
                    }
                    Picker("Status", selection: $draft.status) {
                        Text("All Status").tag(FilterStatus.all)
                        Text("Undone").tag(FilterStatus.active)
                        Text("Completed").tag(FilterStatus.completed)
                        Text("Won't Do").tag(FilterStatus.wontDo)
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("summaryStatus")
                    NavigationLink(draft.listIDs.isEmpty ? "All Lists" : "\(draft.listIDs.count) lists selected") {
                        List {
                            Button("All Lists") { draft.listIDs.removeAll() }
                            Toggle("Inbox", isOn: member(TaskFilter.inboxListID, in: $draft.listIDs))
                            ForEach(lists) { list in
                                Toggle(list.name + (list.isArchived ? " · Archived" : ""), isOn: member(list.id, in: $draft.listIDs))
                            }
                        }.navigationTitle("Lists")
                    }
                    NavigationLink(draft.tagIDs.isEmpty ? "All Tags" : "\(draft.tagIDs.count) tags selected") {
                        List {
                            Button("All Tags") { draft.tagIDs.removeAll() }
                            ForEach(tags) { tag in
                                Toggle(tag.name, isOn: member(tag.id, in: $draft.tagIDs))
                                    .accessibilityIdentifier("summaryTag-" + tag.id.uuidString)
                            }
                        }.navigationTitle("Tags")
                    }.accessibilityIdentifier("summaryTagFilter")
                    NavigationLink(draft.priorities.isEmpty ? "All Priorities" : "\(draft.priorities.count) priorities selected") {
                        List {
                            Button("All Priorities") { draft.priorities.removeAll() }
                            ForEach(TaskPriority.allCases.reversed(), id: \.self) { priority in
                                Toggle(priority.phoneLabel, isOn: member(priority, in: $draft.priorities))
                                    .accessibilityIdentifier("summaryPriority-" + priority.rawValue)
                            }
                        }.navigationTitle("Priority")
                    }.accessibilityIdentifier("summaryPriorityFilter")
                }
                Section("Display Options") {
                    Picker("Grouping", selection: $draft.grouping) {
                        ForEach(SummaryReportOptions.Grouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("summaryGrouping")
                    Picker("Sort", selection: $draft.sort) {
                        ForEach(SummaryReportOptions.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("summarySort")
                    ForEach(SummaryReportOptions.Field.allCases, id: \.self) { field in
                        Toggle(field.rawValue, isOn: member(field, in: $draft.fields))
                            .accessibilityIdentifier("summaryField-" + field.rawValue)
                    }
                    Toggle("Next Period Tasks", isOn: $draft.nextPeriod)
                }
            }
            .navigationTitle("Summary Filter").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("summaryFilterCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: commit).accessibilityIdentifier("summaryFilterDone")
                }
            }
            .alert("Could Not Save Summary Presets", isPresented: $presetError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Close and reopen Summary Filter before trying again.")
            }
        }
    }

    private func commit() {
        if let draftPresets, draftPresets != SummaryReportPresets(stored: initialPresetData) {
            guard presetData == initialPresetData, let encoded = try? draftPresets.encoded() else {
                presetError = true
                return
            }
            presetData = encoded
        }
        options = draft
        dismiss()
    }

    private func member<Value: Hashable>(_ value: Value, in set: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { selected in
            if selected { set.wrappedValue.insert(value) }
            else { set.wrappedValue.remove(value) }
        })
    }
}

private struct PhoneSummaryPresetList: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var presets: SummaryReportPresets
    @Binding var options: SummaryReportOptions
    @State private var managesPresets = false
    @State private var showName = false
    @State private var name = ""
    @State private var renamingPreset: SummaryReportPreset?

    var body: some View {
        List {
            Section {
                Button("Save Current Options…") { editName() }
            }
            if !presets.entries.isEmpty {
                Section("Saved Presets") {
                    ForEach(presets.entries) { preset in
                        if managesPresets {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                Button {
                                    editName(preset)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .accessibilityLabel("Rename " + preset.name)
                                Button(role: .destructive) {
                                    presets.remove(preset.id)
                                    if presets.entries.isEmpty { managesPresets = false }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete " + preset.name)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Button(preset.name) {
                                options = preset.options
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Summary Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !presets.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(managesPresets ? "Finish Managing" : "Manage") { managesPresets.toggle() }
                        .accessibilityIdentifier("summaryPresetManage")
                }
            }
        }
        .alert(renamingPreset == nil ? "Save Summary Preset" : "Rename Summary Preset", isPresented: $showName) {
            TextField("Name", text: $name)
                .accessibilityIdentifier("summaryPresetName")
            Button("Cancel", role: .cancel) {}
            Button("Save", action: stagePreset)
                .disabled(!presets.accepts(name, renaming: renamingPreset?.id))
        } message: {
            Text("Choose a unique name for this preset.")
        }
    }

    private func editName(_ preset: SummaryReportPreset? = nil) {
        renamingPreset = preset
        name = preset?.name ?? ""
        showName = true
    }

    private func stagePreset() {
        if let renamingPreset {
            presets.rename(renamingPreset.id, to: name)
        } else {
            presets.save(name, options: options)
        }
    }
}
