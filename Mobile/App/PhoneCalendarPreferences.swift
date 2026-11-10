import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

enum PhoneCalendarPreferenceKind { case filters, display }

struct PhoneCalendarPreferenceRoute: Identifiable {
    let id = UUID()
    let kind: PhoneCalendarPreferenceKind
    let options: TaskCalendarOptions
    let expected: WorkspaceRevision
}

struct PhoneCalendarPreferences: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let route: PhoneCalendarPreferenceRoute
    @State private var draft: TaskCalendarOptions
    @State private var showZones = false
    @State private var error: String?

    init(model: PhoneWorkspaceModel, route: PhoneCalendarPreferenceRoute) {
        self.model = model
        self.route = route
        _draft = State(initialValue: route.options)
    }

    var body: some View {
        NavigationStack {
            Form {
                switch route.kind {
                case .display: display
                case .filters:
                    if let data = model.document?.snapshot.workspace { sources(data) }
                }
            }
            .disabled(model.isBusy)
            .safeAreaInset(edge: .bottom) {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading).padding().background(.regularMaterial)
                        .accessibilityIdentifier("calendarPreferenceError")
                }
            }
            .navigationTitle(route.kind == .filters ? "Calendar filters" : "Calendar View Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("calendarPreferencesCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.disabled(model.isBusy).accessibilityIdentifier("calendarPreferencesDone")
                }
            }
        }
        .interactiveDismissDisabled(model.isBusy)
        .sheet(isPresented: $showZones) {
            PhoneCalendarZoneSettings(zones: draft.additionalTimeZones, primary: model.calendar.timeZone) {
                draft.additionalTimeZones = $0
            }
        }
    }

    @ViewBuilder private var display: some View {
        Section("Appearance") {
            Picker("Color by", selection: $draft.colorBy) {
                ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.accessibilityIdentifier("calendarColor")
            Picker("Style", selection: $draft.itemStyle) {
                ForEach(CalendarItemStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.accessibilityIdentifier("calendarStyle")
            Picker("Year style", selection: $draft.yearStyle) {
                ForEach(CalendarYearStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.accessibilityIdentifier("calendarYearStyle")
            Toggle("Show Item Icons", isOn: $draft.showItemIcons).accessibilityIdentifier("calendarIcons")
            Group {
                Toggle("Show Task Icons", isOn: $draft.showTaskIcons).accessibilityIdentifier("calendarTaskIcons")
                Toggle("Show Note Icons", isOn: $draft.showNoteIcons).accessibilityIdentifier("calendarNoteIcons")
            }.disabled(!draft.showItemIcons)
        }
        Section {
            Toggle("Show Completed", isOn: $draft.showCompleted).accessibilityIdentifier("calendarCompleted")
            Toggle("Show Checklist Items", isOn: $draft.showChecklistItems).accessibilityIdentifier("calendarChecklist")
            Toggle("Show All Repeat Cycles", isOn: $draft.showRepeatCycles).accessibilityIdentifier("calendarRepeats")
            Toggle(isOn: $draft.showDetails) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show Details")
                    Text("Show task time and list in Agenda and Month.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.accessibilityIdentifier("calendarDetails")
        } header: { Text("Visible Items") } footer: { Text("Future repeats are previews. Open the repeating task to edit its schedule.") }
        Section("Range") {
            Stepper("Multi-Day: \(draft.multiDayCount) days", value: $draft.multiDayCount, in: 2...14)
            Stepper("Multi-Week: \(draft.multiWeekCount) weeks", value: $draft.multiWeekCount, in: 2...6)
            Picker("All-day rows", selection: $draft.allDayRows) {
                Text("Automatic").tag(nil as Int?)
                ForEach(TaskCalendarOptions.allDayRowRange, id: \.self) { rows in
                    Text(rows == 1 ? "1 row" : "\(rows) rows").tag(Optional(rows))
                }
            }.pickerStyle(.navigationLink).accessibilityIdentifier("calendarAllDayRows")
        }
        Section {
            Toggle("Additional Time Zones", isOn: $draft.showAdditionalTimeZones)
                .accessibilityIdentifier("calendarAdditionalZones")
            Button { showZones = true } label: {
                LabeledContent("Time Zone Settings", value: "\(draft.additionalTimeZones.count) configured")
            }.accessibilityIdentifier("calendarZoneSettings")
        } header: { Text("Time Zone Rulers") } footer: { Text("Secondary rulers appear in Day, Week, and Multi-Day.") }
        Section {
            ForEach(CalendarHourBand.allCases, id: \.self) { band in
                let value = draft.foldedHours
                Picker(band.cutoffTitle, selection: Binding(
                    get: { draft.foldedHours.cutoff(band) },
                    set: { draft.foldedHours = draft.foldedHours.moving(band, to: $0) }
                )) {
                    ForEach(value.range(for: band), id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }.pickerStyle(.navigationLink)
                .accessibilityIdentifier("calendarFoldPreference-" + band.rawValue)
            }
            Button("Reset Folded Hours") { draft.foldedHours = .init() }.disabled(draft.foldedHours == .init())
        } header: { Text("Folded Hours") } footer: { Text("Expand both bands to drag their boundaries in the timeline.") }
    }

    @ViewBuilder private func sources(_ data: WorkspaceData) -> some View {
        Section { source("All", mark: draft.isAllSources ? .on : .off) { draft.selectAllSources() } }
        Section("Lists") {
            source("Select all lists and Inbox", mark: draft.listSelectionState(in: data)) {
                draft.setListsSelected(draft.listSelectionState(in: data) != .on, data: data)
            }
            source("Inbox", mark: draft.isInboxSelected ? .on : .off) {
                draft.setInboxSelected(!draft.isInboxSelected, data: data)
            }
            ForEach(data.lists.filter { !$0.isArchived }) { list in
                HStack {
                    let selected = draft.selectedListIDs(in: data).contains(list.id)
                    source(list.name, mark: selected ? .on : .off) {
                        draft.setListSelected(list.id, !selected, data: data)
                    }
                    Button("Only") { draft.selectOnlyList(list.id) }
                        .buttonStyle(.borderless).frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Show only " + list.name)
                }
            }
        }
        Section("Tags") {
            if !data.tags.isEmpty {
                source("Select all tags", mark: draft.tagSelectionState(in: data)) {
                    draft.setTagsSelected(draft.tagSelectionState(in: data) != .on, data: data)
                }
            }
            ForEach(data.tags) { tag in
                let selected = draft.tagIDs.contains(tag.id)
                source(tag.name, mark: selected ? .on : .off) { draft.setTagSelected(tag.id, !selected, data: data) }
            }
        }
        if hasUnavailableSources(data) {
            Section {
                Text("Some saved Calendar sources are unavailable.")
                Button("Clear unavailable sources") { draft.clearUnavailableSources(data: data) }
            }
        } else if !draft.isAllSources, draft.selectedListIDs(in: data).isEmpty, !draft.isInboxSelected, draft.tagIDs.isEmpty {
            Section { Text("No Calendar sources are selected.") }
        }
    }

    private func hasUnavailableSources(_ data: WorkspaceData) -> Bool {
        let lists = Set(data.lists.filter { !$0.isArchived }.map(\.id))
        let tags = Set(data.tags.map(\.id))
        return !Set(draft.listIDs ?? []).isSubset(of: lists) || !Set(draft.tagIDs).isSubset(of: tags)
    }

    private func source(_ name: String, mark: CalendarFilterMark, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer()
                Image(systemName: mark == .on ? "checkmark.square.fill" : mark == .mixed ? "minus.square.fill" : "square")
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(name)
            .accessibilityValue(mark == .on ? "Selected" : mark == .mixed ? "Partially selected" : "Not selected")
    }

    private func save() {
        Task {
            error = await model.saveCalendarOptions(draft, expected: route.expected)
            if error == nil { dismiss() }
        }
    }
}

private struct PhoneCalendarZoneSettings: View {
    @Environment(\.dismiss) private var dismiss
    @State var zones: [CalendarTimeZone]
    let primary: TimeZone
    let save: ([CalendarTimeZone]) -> Void
    @State private var picker: Choice?

    private struct Choice: Identifiable {
        let id = UUID()
        let replacing: String?
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(primary.identifier.replacingOccurrences(of: "_", with: " "), systemImage: "globe")
                } header: { Text("Primary time zone") }
                Section {
                    ForEach($zones) { $zone in
                        VStack(alignment: .leading, spacing: 8) {
                            Button(zone.identifier.replacingOccurrences(of: "_", with: " ")) {
                                picker = Choice(replacing: zone.identifier)
                            }.buttonStyle(.plain).frame(minHeight: 44)
                            TextField("Optional label", text: $zone.label)
                                .onChange(of: zone.label) { _, label in if label.count > 32 { zone.label = String(label.prefix(32)) } }
                                .accessibilityIdentifier("calendarZoneLabel-" + zone.identifier)
                            if zone.identifier == primary.identifier {
                                Text("The primary ruler already shows this zone.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete { zones.remove(atOffsets: $0) }.onMove { zones.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add Time Zone") { picker = Choice(replacing: nil) }
                        .disabled(zones.count >= CalendarTimeZone.maximumCount).accessibilityIdentifier("calendarZoneAdd")
                } header: { Text("Secondary rulers") } footer: {
                    Text("Up to \(CalendarTimeZone.maximumCount) secondary rulers. Labels and order apply only to Calendar.")
                }
            }
            .navigationTitle("Time Zone Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("calendarZonesCancel")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    EditButton()
                    Button("Done") {
                        save(CalendarTimeZone.normalized(zones))
                        dismiss()
                    }.accessibilityIdentifier("calendarZonesDone")
                }
            }
        }.sheet(item: $picker) { choice in
            let used = Set(zones.map(\.identifier).filter { $0 != choice.replacing }).union([primary.identifier])
            PhoneScheduleZoneSheet(current: choice.replacing, excluded: used, showsDevice: false) { id in
                guard let id, !used.contains(id) else { return }
                if let previous = choice.replacing, let index = zones.firstIndex(where: { $0.identifier == previous }) {
                    zones[index].identifier = id
                } else if zones.count < CalendarTimeZone.maximumCount {
                    zones.append(CalendarTimeZone(identifier: id))
                }
            }
        }
    }
}
