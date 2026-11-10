import SwiftUI
import TaskovskyDomain
import UIKit

struct PhoneSummaryView: View {
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var options: SummaryReportOptions
    @State private var text = ""
    @State private var noteTitle = ""
    @State private var showFilters = false
    @State private var feedback: String?
    @FocusState private var editing: Bool

    init(model: PhoneWorkspaceModel) {
        self.model = model
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
                PhoneSummaryFilters(options: $options, lists: snapshot.workspace.lists)
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
    let lists: [TaskList]
    @State private var draft: SummaryReportOptions

    init(options: Binding<SummaryReportOptions>, lists: [TaskList]) {
        _options = options
        self.lists = lists
        _draft = State(initialValue: options.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                }
                Section("Display Options") {
                    Picker("Grouping", selection: $draft.grouping) {
                        ForEach(SummaryReportOptions.Grouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("summaryGrouping")
                    ForEach(SummaryReportOptions.Field.allCases, id: \.self) { field in
                        Toggle(field.rawValue, isOn: member(field, in: $draft.fields))
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
                    Button("Done") { options = draft; dismiss() }.accessibilityIdentifier("summaryFilterDone")
                }
            }
        }
    }

    private func member<Value: Hashable>(_ value: Value, in set: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { selected in
            if selected { set.wrappedValue.insert(value) }
            else { set.wrappedValue.remove(value) }
        })
    }
}
