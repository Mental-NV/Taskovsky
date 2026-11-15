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
    @State private var tagsExpanded = true
    @State private var expandedFolders = Set<UUID>()
    @State private var moreExpanded = false
    @State private var showZones = false
    @State private var error: String?

    init(model: PhoneWorkspaceModel, route: PhoneCalendarPreferenceRoute) {
        self.model = model
        self.route = route
        _draft = State(initialValue: route.options)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch route.kind {
                case .display: Form { display }
                case .filters:
                    ScrollView {
                        if let data = model.document?.snapshot.workspace {
                            sources(data).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
                        }
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
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
            .navigationTitle(route.kind == .filters ? "Filter View Range" : "Calendar View Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if route.kind == .filters {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .cancellationAction) { filterCancel }.sharedBackgroundVisibility(.hidden)
                        ToolbarItem(placement: .confirmationAction) { filterDone }.sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .cancellationAction) { filterCancel }
                        ToolbarItem(placement: .confirmationAction) { filterDone }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("calendarPreferencesCancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { save() }.disabled(model.isBusy).accessibilityIdentifier("calendarPreferencesDone")
                    }
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
            NavigationLink {
                Form { Section { colorControls } }
                    .navigationTitle("Color").navigationBarTitleDisplayMode(.inline)
            } label: { LabeledContent("Color", value: draft.colorBy.rawValue.capitalized) }
                .accessibilityIdentifier("calendarColorPage")
            NavigationLink {
                Form {
                    Section("Item Style") { styleControls }
                    Section {
                        NavigationLink("Show Item Icons") {
                            Form { Section { iconControls } }
                                .navigationTitle("Show Item Icons").navigationBarTitleDisplayMode(.inline)
                        }.accessibilityIdentifier("calendarIconsPage")
                    }
                }.navigationTitle("Style").navigationBarTitleDisplayMode(.inline)
            } label: { LabeledContent("Style", value: draft.itemStyle.rawValue.capitalized) }
                .accessibilityIdentifier("calendarStylePage")
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

    @ViewBuilder private var colorControls: some View {
        Picker("Color by", selection: $draft.colorBy) {
            ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.accessibilityIdentifier("calendarColor")
        if draft.colorBy != .priority, let data = model.document?.snapshot.workspace {
            NavigationLink(draft.colorBy == .list ? "Customize List Colors" : "Customize Tag Colors") {
                PhoneCalendarSourceColors(mode: draft.colorBy, data: data, colors: $draft.sourceColors)
            }.accessibilityIdentifier("calendarSourceColors")
        }
    }

    @ViewBuilder private var styleControls: some View {
        Picker("Style", selection: $draft.itemStyle) {
            ForEach(CalendarItemStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.accessibilityIdentifier("calendarStyle")
        Picker("Year style", selection: $draft.yearStyle) {
            ForEach(CalendarYearStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.accessibilityIdentifier("calendarYearStyle")
    }

    @ViewBuilder private var iconControls: some View {
        Toggle("Show Item Icons", isOn: $draft.showItemIcons).accessibilityIdentifier("calendarIcons")
        Group {
            Toggle("Show Task Icons", isOn: $draft.showTaskIcons).accessibilityIdentifier("calendarTaskIcons")
            Toggle("Show Note Icons", isOn: $draft.showNoteIcons).accessibilityIdentifier("calendarNoteIcons")
        }.disabled(!draft.showItemIcons)
    }

    private var filterCancel: some View {
        Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .regular)).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).foregroundStyle(.secondary).frame(minWidth: 44, minHeight: 44)
            .disabled(model.isBusy).accessibilityLabel("Cancel").accessibilityIdentifier("calendarPreferencesCancel")
    }

    private var filterDone: some View {
        Button { save() } label: { Image(systemName: "checkmark.circle.fill").font(.system(size: 25, weight: .regular)).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).foregroundStyle(Color.accentColor).frame(minWidth: 44, minHeight: 44)
            .disabled(model.isBusy).accessibilityLabel("Done").accessibilityIdentifier("calendarPreferencesDone")
    }

    @ViewBuilder private func sources(_ data: WorkspaceData) -> some View {
        VStack(spacing: 0) {
            source("All", icon: "tray.full", mark: draft.isAllSources ? .on : .off) { draft.selectAllSources() }
            disclosure("Tags", icon: "tag", expanded: tagsExpanded, identifier: "calendarFilterTags") { tagsExpanded.toggle() }
            if tagsExpanded {
                ForEach(data.tags) { tag in
                    let selected = draft.tagIDs.contains(tag.id)
                    source(tag.name, icon: "tag", indented: true, mark: selected ? .on : .off) {
                        draft.setTagSelected(tag.id, !selected, data: data)
                    }
                }
            }
            source("Inbox", icon: "tray", mark: draft.isInboxSelected ? .on : .off) {
                draft.setInboxSelected(!draft.isInboxSelected, data: data)
            }
            let active = data.lists.filter { !$0.isArchived }
            let folderIDs = Set(data.folders.map(\.id))
            ForEach(active.filter { $0.folderID == nil && !$0.belowFolders }) { list in listSource(list, data: data) }
            ForEach(data.folders) { folder in
                let members = active.filter { $0.folderID == folder.id }
                if !members.isEmpty {
                    let expanded = expandedFolders.contains(folder.id)
                    disclosure(folder.name, icon: "folder", expanded: expanded, identifier: "calendarFilterFolder-" + folder.id.uuidString) {
                        if expanded { expandedFolders.remove(folder.id) } else { expandedFolders.insert(folder.id) }
                    }
                    if expanded { ForEach(members) { list in listSource(list, data: data, indented: true) } }
                }
            }
            ForEach(active.filter { list in
                list.folderID == nil ? list.belowFolders : !folderIDs.contains(list.folderID!)
            }) { list in listSource(list, data: data) }
            // Keep Taskovsky's existing bulk actions reachable without inserting extra primary rows.
            disclosure("More", icon: "ellipsis", expanded: moreExpanded, identifier: "calendarFilterMore") { moreExpanded.toggle() }
            if moreExpanded {
                if !data.tags.isEmpty {
                    source("Select all tags", icon: "tag", mark: draft.tagSelectionState(in: data)) {
                        draft.setTagsSelected(draft.tagSelectionState(in: data) != .on, data: data)
                    }
                }
                source("Select all lists and Inbox", icon: "tray.full", mark: draft.listSelectionState(in: data)) {
                    draft.setListsSelected(draft.listSelectionState(in: data) != .on, data: data)
                }
            }
        }.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        if hasUnavailableSources(data) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Some saved Calendar sources are unavailable.")
                Button("Clear unavailable sources") { draft.clearUnavailableSources(data: data) }
            }.font(.footnote).padding(.top, 16)
        } else if !draft.isAllSources, draft.selectedListIDs(in: data).isEmpty, !draft.isInboxSelected, draft.tagIDs.isEmpty {
            Text("No Calendar sources are selected.").font(.footnote).padding(.top, 16)
        }
    }

    private func disclosure(_ title: String, icon: String, expanded: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                Text(title).font(.body).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }.padding(.horizontal, 16).frame(minHeight: 50).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
    }

    private func listSource(_ list: TaskList, data: WorkspaceData, indented: Bool = false) -> some View {
        let selected = draft.selectedListIDs(in: data).contains(list.id)
        return source(list.name, icon: "list.bullet", indented: indented, mark: selected ? .on : .off) {
            draft.setListSelected(list.id, !selected, data: data)
        }.contextMenu {
            Button("Show only " + list.name) { draft.selectOnlyList(list.id) }
        }.accessibilityAction(named: "Show only " + list.name) { draft.selectOnlyList(list.id) }
    }

    private func hasUnavailableSources(_ data: WorkspaceData) -> Bool {
        let lists = Set(data.lists.filter { !$0.isArchived }.map(\.id))
        let tags = Set(data.tags.map(\.id))
        return !Set(draft.listIDs ?? []).isSubset(of: lists) || !Set(draft.tagIDs).isSubset(of: tags)
    }

    private func source(_ name: String, icon: String, indented: Bool = false, mark: CalendarFilterMark, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                Text(name).font(.body).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: mark == .mixed ? "minus" : "checkmark")
                    .font(.system(size: 17, weight: .regular)).foregroundStyle(Color.accentColor)
                    .opacity(mark == .off ? 0 : 1).accessibilityHidden(true)
            }.padding(.leading, indented ? 36 : 16).padding(.trailing, 16)
                .frame(minHeight: 50).contentShape(Rectangle())
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

private struct PhoneCalendarSourceColors: View {
    let mode: CalendarColorMode
    let data: WorkspaceData
    @Binding var colors: CalendarColorSource.Overrides

    var body: some View {
        let rows = CalendarColorSource.swatches(in: data, by: mode)
        Form {
            Section {
                if rows.isEmpty { Text("No tags to customize.").foregroundStyle(.secondary) }
                ForEach(rows) { row in
                    HStack {
                        ColorPicker(row.name, selection: selection(for: row), supportsOpacity: false)
                            .accessibilityValue(colors[row.id] ?? "Default")
                        Button("Default") { colors[row.id] = nil }
                            .buttonStyle(.borderless).disabled(colors[row.id] == nil)
                            .accessibilityLabel("Use default color for " + row.name)
                    }
                }
            } footer: { Text("These colors apply only in Calendar. Changes save when you tap Done in View Options.") }
        }.navigationTitle(mode == .list ? "Calendar List Colors" : "Calendar Tag Colors")
            .navigationBarTitleDisplayMode(.inline)
    }

    private func selection(for row: CalendarColorSource.Swatch) -> Binding<Color> {
        Binding(get: { PhoneEntityColor.read(colors[row.id] ?? row.defaultColor) }, set: { color in
            if let hex = PhoneEntityColor.encode(color) { colors[row.id] = hex }
        })
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
