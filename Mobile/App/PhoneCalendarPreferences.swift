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
            PhoneCalendarZoneSettings(enabled: draft.showAdditionalTimeZones, zones: draft.additionalTimeZones, primary: model.calendar.timeZone) { enabled, zones in
                draft.showAdditionalTimeZones = enabled
                draft.additionalTimeZones = zones
            }
        }
    }

    @ViewBuilder private var display: some View {
        Section("Appearance") {
            NavigationLink {
                Form { colorControls }
                    .navigationTitle("Color").navigationBarTitleDisplayMode(.inline)
            } label: { LabeledContent("Color", value: draft.colorBy.rawValue.capitalized) }
                .accessibilityIdentifier("calendarColorPage")
            NavigationLink {
                Form {
                    Section("Item Style") { itemStyleTiles }
                    Section {
                        NavigationLink("Show Item Icons") {
                            Form { Section { iconControls } }
                                .navigationTitle("Show Item Icons").navigationBarTitleDisplayMode(.inline)
                        }.accessibilityIdentifier("calendarIconsPage")
                    }
                    Section("Heatmap") { heatmapTiles }
                }.navigationTitle("Style").navigationBarTitleDisplayMode(.inline)
            } label: { LabeledContent("Style", value: draft.itemStyle.displayTitle) }
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
            Button { showZones = true } label: {
                LabeledContent("Additional Time Zone", value: draft.showAdditionalTimeZones ? "On" : "Off")
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

    /// C07/C08 structural parity: the Color page carries the anchored
    /// Color By menu and the genuine source swatches inline. Every row edits
    /// the outer staged draft; nothing saves until View Options Done.
    @ViewBuilder private var colorControls: some View {
        Section {
            Menu {
                ForEach(CalendarColorMode.allCases, id: \.self) { mode in
                    Button {
                        draft.colorBy = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue.capitalized)
                            if draft.colorBy == mode {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel("Color by " + mode.rawValue.capitalized)
                    .accessibilityIdentifier("calendarColorMode-" + mode.rawValue)
                    .accessibilityValue(draft.colorBy == mode ? "Selected" : "Not selected")
                    .accessibilityAddTraits(draft.colorBy == mode ? .isSelected : [])
                }
            } label: {
                LabeledContent("Color By", value: draft.colorBy.rawValue.capitalized)
            }
            .accessibilityIdentifier("calendarColor")
            .accessibilityValue(draft.colorBy.rawValue.capitalized)
        }
        if let data = model.document?.snapshot.workspace {
            switch draft.colorBy {
            case .list: listColorGroups(data)
            case .tag: tagColorGroups(data)
            case .priority: priorityColorNote
            }
        }
    }

    @ViewBuilder private func listColorGroups(_ data: WorkspaceData) -> some View {
        let hierarchy = CalendarColorSource.listSections(in: data)
        Section {
            colorRow(hierarchy.inbox)
        }
        ForEach(hierarchy.sections, id: \.placement) { section in
            Section {
                ForEach(section.rows) { row in colorRow(row) }
            } header: {
                if let folderName = section.folderName { Text(folderName) }
            }
        }
    }

    @ViewBuilder private func tagColorGroups(_ data: WorkspaceData) -> some View {
        Section {
            let rows = CalendarColorSource.swatches(in: data, by: .tag)
            if rows.isEmpty {
                Text("No tags to customize.").foregroundStyle(.secondary)
            }
            ForEach(rows) { row in colorRow(row) }
        } footer: {
            Text("These colors apply only in Calendar. Changes save when you tap Done in View Options.")
        }
    }

    private var priorityColorNote: some View {
        Section {
            Text("Priority uses its fixed Calendar colors. There is nothing to customize.")
                .foregroundStyle(.secondary)
        } footer: {
            Text("High, Medium, Low, and No Priority keep their built-in colors in Calendar.")
        }
    }

    private func colorRow(_ row: CalendarColorSource.Swatch) -> some View {
        PhoneCalendarSourceColorRow(row: row, colors: $draft.sourceColors)
    }

    /// C10 structural parity: side-by-side Modern/Classic preview tiles with
    /// a selected blue checked circle, plus clearly labeled legacy choices.
    /// Tiles render through the shared `CalendarItemStyle.rendering` policy
    /// with neutral task samples (calendar events are unsupported). Back
    /// retains the outer staged draft; outer Done saves it.
    @ViewBuilder private var itemStyleTiles: some View {
        HStack(spacing: 12) {
            ForEach(CalendarItemStyle.primaryStyles, id: \.self) { style in
                itemTile(style)
            }
        }
        if draft.itemStyle.isLegacy {
            Text("Current saved style: \(draft.itemStyle.displayTitle). It stays unchanged until you pick another style.")
                .font(.caption).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional styles").font(.caption).foregroundStyle(.secondary)
            ForEach(CalendarItemStyle.legacyStyles, id: \.self) { style in
                Button {
                    draft.itemStyle = style
                } label: {
                    HStack {
                        Text(style.displayTitle).foregroundStyle(.primary)
                        Spacer()
                        if draft.itemStyle == style {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .accessibilityLabel(style.displayTitle + " style")
                .accessibilityValue(draft.itemStyle == style ? "Selected" : "Not selected")
                .accessibilityIdentifier("calendarItemStyle-" + style.rawValue)
            }
        }
        Text("Previews show neutral tasks. Calendar events are not supported. Exact reference colors and borders remain uncertain.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func itemTile(_ style: CalendarItemStyle) -> some View {
        let selected = draft.itemStyle == style
        return Button {
            draft.itemStyle = style
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                PhoneCalendarStyleSample(style: style)
                HStack {
                    Text(style.displayTitle).font(.caption).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 1.5 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayTitle + " style")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("calendarItemStyle-" + style.rawValue)
    }

    /// Heatmap section with side-by-side Hide/Show month previews using the
    /// existing Standard/Heatmap projection semantics and the current-day
    /// marker. Hide keeps Standard dots; the reference fully-plain Hide
    /// state is not claimed.
    @ViewBuilder private var heatmapTiles: some View {
        HStack(spacing: 12) {
            ForEach([CalendarYearStyle.standard, CalendarYearStyle.heatmap], id: \.self) { style in
                heatTile(style)
            }
        }
        Text("Hide keeps Standard dots; Show shades dates by item count.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func heatTile(_ style: CalendarYearStyle) -> some View {
        let selected = draft.yearStyle == style
        return Button {
            draft.yearStyle = style
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                PhoneCalendarHeatSample(style: style)
                HStack {
                    Text(style.heatmapTileTitle).font(.caption).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                Text(style.heatmapTileSubtitle).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 1.5 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Heatmap " + style.heatmapTileTitle)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("calendarYearStyle-" + style.heatmapTileTitle.lowercased())
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

/// Neutral Style tile sample driven by the shared production rendering
/// policy. Calendar events are unsupported, so both rows are tasks.
private struct PhoneCalendarStyleSample: View {
    var style: CalendarItemStyle

    private func color(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return .accentColor }
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    private func row(title: String, time: String, hex: String) -> some View {
        let rendering = style.rendering
        let tint = color(hex)
        return HStack(spacing: 3) {
            if rendering.showsStripe {
                Rectangle().fill(tint).frame(width: 2)
            }
            Image(systemName: "square")
                .font(.system(size: 8))
                .foregroundStyle(style == .classic ? .primary : tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11)).lineLimit(1).foregroundStyle(.primary)
                Text(time).font(.system(size: 9)).lineLimit(1).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rendering.fillOpacity > 0 ? tint.opacity(rendering.fillOpacity) : .clear, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            if rendering.showsOutline {
                RoundedRectangle(cornerRadius: 3).strokeBorder(tint.opacity(0.7))
            }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            row(title: "Prepare agenda", time: "09:00 – 09:30", hex: "#5B8DEF")
            row(title: "Review notes", time: "14:00 – 14:30", hex: "#58A58B")
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Neutral Heatmap tile sample using the same overlap-count rule and cell
/// treatment as the production Year grid (Standard dots, Heatmap shading).
private struct PhoneCalendarHeatSample: View {
    var style: CalendarYearStyle

    private var days: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let start = CalendarDates.weekStart(month, calendar: calendar)
        return CalendarDates.days(from: start, count: 42, calendar: calendar)
    }

    private var counts: [Date: Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let start = CalendarDates.weekStart(month, calendar: calendar)
        func entry(offset: Int) -> CalendarEntry {
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let at = CalendarDates.instant(on: day, minute: 9 * 60, calendar: calendar)
            return CalendarEntry(id: "heat-\(offset)", taskID: UUID(), title: "Sample task",
                start: at, end: at, due: at, isAllDay: false, isProjected: false,
                isCompleted: false, isNote: false, hasDuration: false, color: "#5B8DEF", listID: nil)
        }
        let entries = [entry(offset: 8), entry(offset: 8), entry(offset: 15)]
        var result: [Date: Int] = [:]
        for day in days {
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            result[day] = entries.filter { $0.start < end && $0.end > day }.count
        }
        return result
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
            ForEach(days, id: \.self) { day in
                let count = counts[day, default: 0]
                let heat = style == .heatmap && count > 0 ? Color.accentColor.opacity(min(0.7, 0.1 + Double(count) * 0.1)) : .clear
                Text("\(Calendar(identifier: .gregorian).component(.day, from: day))")
                    .font(.system(size: 7))
                    .frame(maxWidth: .infinity, minHeight: 12)
                    .background(heat, in: RoundedRectangle(cornerRadius: 2))
                    .overlay(alignment: .bottom) {
                        if style == .standard && count > 0 {
                            Circle().fill(Color.accentColor).frame(width: 2, height: 2)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PhoneCalendarSourceColorRow: View {
    let row: CalendarColorSource.Swatch
    @Binding var colors: CalendarColorSource.Overrides

    var body: some View {
        HStack {
            ColorPicker(row.name, selection: selection(for: row), supportsOpacity: false)
                .accessibilityValue(colors[row.id] ?? "Default")
            Button("Default") { colors[row.id] = nil }
                .buttonStyle(.borderless).disabled(colors[row.id] == nil)
                .accessibilityLabel("Use default color for " + row.name)
        }
    }

    private func selection(for row: CalendarColorSource.Swatch) -> Binding<Color> {
        Binding(get: { PhoneEntityColor.read(colors[row.id] ?? row.defaultColor) }, set: { color in
            if let hex = PhoneEntityColor.encode(color) { colors[row.id] = hex }
        })
    }
}

private struct PhoneCalendarZoneSettings: View {
    @Environment(\.dismiss) private var dismiss
    @State var enabled: Bool
    @State var zones: [CalendarTimeZone]
    let primary: TimeZone
    let save: (Bool, [CalendarTimeZone]) -> Void
    @State private var picker: Choice?

    private struct Choice: Identifiable {
        let id = UUID()
        let replacing: String?
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Additional Time Zone", isOn: $enabled)
                        .accessibilityIdentifier("calendarAdditionalZones")
                    LabeledContent("Current Time Zone", value: primary.identifier.replacingOccurrences(of: "_", with: " "))
                        .accessibilityIdentifier("calendarCurrentZone")
                }
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
                        save(enabled, CalendarTimeZone.normalized(zones))
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
