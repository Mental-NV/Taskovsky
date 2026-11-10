import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneLocalSettingsRequest: Identifiable {
    let id = UUID()
    let settings: AppSettings
    let revision: WorkspaceRevision
    let taskCountdownEnabled: Bool
}

struct PhoneLocalSettings: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneLocalSettingsRequest
    @State private var draft: LocalWorkspacePreferences
    @State private var taskCountdownEnabled: Bool
    @State private var confirmDiscard = false
    @State private var error: String?

    init(model: PhoneWorkspaceModel, request: PhoneLocalSettingsRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: LocalWorkspacePreferences(request.settings))
        _taskCountdownEnabled = State(initialValue: request.taskCountdownEnabled)
    }

    private var workspacePreferencesChanged: Bool { draft != LocalWorkspacePreferences(request.settings) }
    private var changed: Bool { workspacePreferencesChanged || taskCountdownEnabled != request.taskCountdownEnabled }
    private var lists: [TaskList] { model.document?.snapshot.workspace.lists.filter { !$0.isArchived } ?? [] }
    private var tags: [TaskTag] { model.document?.snapshot.workspace.tags ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    let weekdays = model.calendar.standaloneWeekdaySymbols
                    Picker("Start week on", selection: $draft.startWeekOn) {
                        ForEach(1...weekdays.count, id: \.self) { day in Text(weekdays[day - 1]).tag(day) }
                        if !(1...weekdays.count).contains(draft.startWeekOn) {
                            Text("Unavailable saved value").tag(draft.startWeekOn)
                        }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("localWeekStart")
                    Toggle("Save time zone with new dates", isOn: $draft.enableTimeZone)
                    Toggle("Countdown Mode", isOn: $taskCountdownEnabled)
                        .accessibilityIdentifier("localTaskCountdown")
                }
                Section("New Tasks") {
                    Picker("Default date", selection: $draft.defaultDate) {
                        ForEach(DefaultDate.allCases, id: \.self) { date in Text(dateLabel(date)).tag(date) }
                    }
                    Picker("Default list", selection: $draft.defaultListID) {
                        Text("Inbox").tag(nil as UUID?)
                        ForEach(lists) { list in Text(list.name).tag(Optional(list.id)) }
                        if let id = draft.defaultListID, !lists.contains(where: { $0.id == id }) {
                            Text("Unavailable saved list").tag(Optional(id))
                        }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("localDefaultList")
                    Picker("Default tag", selection: $draft.defaultTagID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(tags) { tag in Text(tag.name).tag(Optional(tag.id)) }
                        if let id = draft.defaultTagID, !tags.contains(where: { $0.id == id }) {
                            Text("Unavailable saved tag").tag(Optional(id))
                        }
                    }
                    Picker("Default priority", selection: $draft.defaultPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { Text($0.phoneLabel).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("localDefaultPriority")
                    Picker("Default timed duration", selection: $draft.defaultDurationMinutes) {
                        let minutes = Array(Set([0, 15, 30, 60, 120, draft.defaultDurationMinutes])).sorted()
                        ForEach(minutes, id: \.self) { value in Text(value == 0 ? "None" : "\(value) min").tag(value) }
                    }
                    Picker("Add new tasks to", selection: $draft.defaultAddTo) {
                        Text("Top").tag(TaskPosition.top)
                        Text("Bottom").tag(TaskPosition.bottom)
                    }
                }
                Section("Recognition") {
                    Toggle("Recognize dates in titles", isOn: $draft.dateRecognition)
                    Toggle("Remove recognized date text", isOn: $draft.removeDateText).disabled(!draft.dateRecognition)
                    Toggle("Remove recognized tag text", isOn: $draft.removeTagText)
                }
                Section("Default Reminders") {
                    NavigationLink("Timed reminders") {
                        List(DueReminder.allCases.filter { $0 != .none }, id: \.self) { choice in
                            Toggle(timedLabel(choice), isOn: membership(choice, in: $draft.timedReminders))
                        }.navigationTitle("Timed reminders")
                    }
                    NavigationLink("All-day reminders") {
                        List(AllDayReminder.allCases.filter { $0 != .none }, id: \.self) { choice in
                            Toggle(allDayLabel(choice), isOn: membership(choice, in: $draft.allDayReminders))
                        }.navigationTitle("All-day reminders")
                    }
                }
                Section("About") {
                    Text("Taskovsky Pre-Alpha")
                    Text("Local workspace")
                    if model.document?.allowsKnownFieldWrites == false {
                        Text("Task changes are locked for compatibility.").foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red).padding()
                        .frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial)
                        .accessibilityIdentifier("localSettingsError")
                }
            }
            .disabled(model.isBusy)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmDiscard = true } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("localSettingsCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 30, height: 30)
                            .background(PhoneStyle.accent, in: Circle())
                    }.disabled(model.isBusy).accessibilityLabel("Done").accessibilityIdentifier("localSettingsDone")
                }
            }
        }
        .interactiveDismissDisabled(changed || model.isBusy)
        .alert("Discard settings changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private func save() {
        guard changed else { dismiss(); return }
        Task {
            if workspacePreferencesChanged {
                error = await model.saveLocalPreferences(draft, expected: request.revision)
                guard error == nil else { return }
            }
            model.setTaskCountdownEnabled(taskCountdownEnabled)
            dismiss()
        }
    }

    private func membership<Value: Hashable>(_ value: Value, in values: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(get: { values.wrappedValue.contains(value) }, set: { selected in
            if selected { values.wrappedValue.insert(value) } else { values.wrappedValue.remove(value) }
        })
    }

    private func dateLabel(_ date: DefaultDate) -> String {
        switch date {
        case .none: "None"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .dayAfterTomorrow: "Day after tomorrow"
        case .nextWeek: "Next week"
        }
    }

    private func timedLabel(_ reminder: DueReminder) -> String {
        switch reminder {
        case .none: "None"
        case .onTime: "On time"
        case .fiveMinutesBefore: "5 minutes before"
        case .fifteenMinutesBefore: "15 minutes before"
        case .thirtyMinutesBefore: "30 minutes before"
        case .oneHourBefore: "1 hour before"
        case .oneDayBefore: "1 day before"
        }
    }

    private func allDayLabel(_ reminder: AllDayReminder) -> String {
        switch reminder {
        case .none: "None"
        case .onDay9: "On the day at 9 AM"
        case .dayBefore9: "1 day before at 9 AM"
        case .twoDaysBefore9: "2 days before at 9 AM"
        case .threeDaysBefore9: "3 days before at 9 AM"
        case .weekBefore9: "1 week before at 9 AM"
        }
    }
}
