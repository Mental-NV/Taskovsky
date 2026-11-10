import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

private extension FilterStatus {
    var phoneLabel: String {
        switch self {
        case .active: "Undone"
        case .completed: "Completed"
        case .wontDo: "Won't Do"
        case .all: "All statuses"
        }
    }
}

struct PhoneFilterRequest: Identifiable {
    let id = UUID()
    let filter: TaskFilter
    let creating: Bool
    let revision: WorkspaceRevision
}

struct PhoneSavedFilters: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var request: PhoneFilterRequest?

    var body: some View {
        NavigationStack {
            List {
                Button("New Filter", systemImage: "plus") { open(TaskFilter(name: ""), creating: true) }
                    .accessibilityIdentifier("newSavedFilter")
                ForEach(model.document?.snapshot.workspace.filters ?? []) { filter in
                    Button {
                        open(filter)
                    } label: {
                        HStack {
                            Text(filter.name)
                            Spacer()
                            if filter.isPinned { Image(systemName: "pin.fill").accessibilityHidden(true) }
                            if filter.ruleRoot != nil { Text("Advanced").font(.caption).foregroundStyle(.secondary) }
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("manageFilter-" + filter.id.uuidString)
                }
            }
            .disabled(!model.canBeginEditing)
            .navigationTitle("Manage Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("filterManagerDone")
                }
            }
        }
        .sheet(item: $request) { PhoneFilterEditor(model: model, request: $0) }
    }

    private func open(_ filter: TaskFilter, creating: Bool = false) {
        guard let revision = model.document?.revision else { return }
        request = PhoneFilterRequest(filter: filter, creating: creating, revision: revision)
    }
}

struct PhoneFilterEditor: View {
    private enum Confirmation: String, Identifiable {
        case discard, delete, normal
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneFilterRequest
    let onSave: (() -> Void)?
    @State private var draft: TaskFilter
    @FocusState private var nameFocused: Bool
    @State private var parkedRule: FilterRule?
    @State private var confirmation: Confirmation?
    @State private var error: String?

    init(model: PhoneWorkspaceModel, request: PhoneFilterRequest, onSave: (() -> Void)? = nil) {
        self.model = model
        self.request = request
        self.onSave = onSave
        _draft = State(initialValue: request.filter)
    }

    private var changed: Bool {
        (try? SavedFilterChange.sameDefinition(draft, request.filter)) != true
    }
    private var data: WorkspaceData { model.document?.snapshot.workspace ?? WorkspaceData() }
    private var requiresBounds: Bool { draft.ruleRoot == nil && draft.dateRules.contains(.custom) }
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (!requiresBounds || draft.customDateFrom != nil || draft.customDateTo != nil ||
             (!request.creating && request.filter.ruleRoot == nil && request.filter.dateRules == draft.dateRules &&
              request.filter.customDateFrom == nil && request.filter.customDateTo == nil))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Filter name", text: $draft.name)
                            .focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
                            .accessibilityIdentifier("savedFilterName")
                        if !draft.name.isEmpty {
                            Button { draft.name = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Clear name").accessibilityIdentifier("savedFilterClearName")
                        }
                    }
                    Picker("Filter mode", selection: Binding(get: { draft.ruleRoot != nil }, set: selectMode)) {
                        Text("Normal").tag(false)
                        Text("Advanced").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("savedFilterMode")
                    Toggle("Pin filter", isOn: $draft.isPinned).accessibilityIdentifier("savedFilterPin")
                    let count = data.tasks.filter { draft.matches($0, lists: data.lists, now: model.now, calendar: model.calendar) }.count
                    Text("\(count) matching").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("savedFilterMatchCount")
                }
                if let rule = Binding($draft.ruleRoot) {
                    Section("Advanced Rules") {
                        PhoneFilterRuleNode(rule: rule, data: data, depth: 0, path: "root")
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                } else {
                    PhoneNormalFilterFields(draft: $draft, data: data, context: .savedFilter)
                }
                if draft.ruleRoot != nil || draft.dateRules.contains(.custom) {
                    PhoneFilterDateBounds(from: $draft.customDateFrom, to: $draft.customDateTo, now: model.now)
                }
                if !request.creating {
                    Button("Delete Filter", role: .destructive) { confirmation = .delete }
                        .accessibilityIdentifier("deleteSavedFilter")
                }
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("savedFilterError")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .environment(\.calendar, model.calendar)
            .disabled(model.isBusy)
            .navigationTitle(request.creating ? "New Filter" : "Edit Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmation = .discard } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("savedFilterCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { submit(request.creating ? .create(draft) : .update(draft)) }
                        .disabled(model.isBusy || !canSave).accessibilityIdentifier("savedFilterDone")
                }
            }
        }
        .interactiveDismissDisabled(changed || model.isBusy)
        .alert(item: $confirmation, content: confirm)
    }

    private func selectMode(_ advanced: Bool) {
        nameFocused = false
        if advanced && draft.ruleRoot == nil { draft.ruleRoot = parkedRule ?? .and([]) }
        if !advanced && draft.ruleRoot != nil { confirmation = .normal }
    }

    private func confirm(_ kind: Confirmation) -> Alert {
        switch kind {
        case .discard:
            Alert(title: Text("Discard changes?"), primaryButton: .destructive(Text("Discard Changes")) { dismiss() },
                  secondaryButton: .cancel(Text("Keep Editing")))
        case .delete:
            Alert(title: Text("Delete filter?"), message: Text("“\(request.filter.name)” will be removed. Its tasks will remain."),
                  primaryButton: .destructive(Text("Delete Filter")) { submit(.delete(request.filter.id)) }, secondaryButton: .cancel())
        case .normal:
            Alert(title: Text("Switch to Normal?"), message: Text("Normal criteria will replace the advanced rule tree when you save."),
                  primaryButton: .destructive(Text("Switch to Normal")) { parkedRule = draft.ruleRoot; draft.ruleRoot = nil },
                  secondaryButton: .cancel())
        }
    }

    private func submit(_ change: SavedFilterChange) {
        Task {
            error = await model.saveFilter(change, expected: request.revision)
            if error == nil {
                onSave?()
                dismiss()
            }
        }
    }
}

struct PhoneNormalFilterFields: View {
    enum Context { case search, savedFilter }

    @Binding var draft: TaskFilter
    let data: WorkspaceData
    let context: Context

    var body: some View {
        Section(context == .search ? "Search Criteria" : "Normal Criteria") {
            if context == .savedFilter {
                TextField("Keyword", text: $draft.keyword).accessibilityIdentifier("savedFilterKeyword")
            }
            Picker("Status", selection: $draft.status) {
                ForEach(FilterStatus.allCases, id: \.self) { status in Text(status.phoneLabel).tag(status) }
            }.pickerStyle(.navigationLink)
            choices("Lists", values: $draft.listIDs, options: listOptions)
            choices("Tags", values: $draft.tagIDs, options: tagOptions)
            Picker("Tag matching", selection: $draft.tagMode) {
                ForEach(FilterTagMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
            }.pickerStyle(.navigationLink)
            if context == .savedFilter {
                choices("Priority", values: $draft.priorities, options: TaskPriority.allCases.map { ($0, $0.phoneLabel) })
            }
            choices("Type", values: $draft.kinds, options: [(.task, "Tasks"), (.note, "Notes")])
            choices("Dates", values: $draft.dateRules, options: FilterDateRule.allCases.map { ($0, $0.label) })
        }
    }

    private var listOptions: [(UUID, String)] {
        let choices = [(TaskFilter.inboxListID, "Inbox")] + data.lists.map { ($0.id, $0.name) }
        return choices + unavailable(draft.listIDs, from: choices, label: "Unavailable list")
    }

    private var tagOptions: [(UUID, String)] {
        let choices = data.tags.map { ($0.id, $0.name) }
        return choices + unavailable(draft.tagIDs, from: choices, label: "Unavailable tag")
    }

    private func unavailable(_ selected: [UUID], from known: [(UUID, String)], label: String) -> [(UUID, String)] {
        let ids = Set(known.map(\.0))
        var seen = ids
        return selected.filter { seen.insert($0).inserted }.map { ($0, label + " · " + $0.uuidString.prefix(8)) }
    }

    private func choices<Value: Hashable>(_ name: String, values: Binding<[Value]>, options: [(Value, String)]) -> some View {
        NavigationLink {
            List(options, id: \.0) { value, label in
                let selected = values.wrappedValue.contains(value)
                Button {
                    if selected { values.wrappedValue.removeAll { $0 == value } }
                    else { values.wrappedValue.append(value) }
                } label: {
                    HStack {
                        Text(label)
                        Spacer()
                        if selected { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }.navigationTitle(name)
        } label: {
            LabeledContent(name, value: values.wrappedValue.isEmpty ? "Any" : "\(values.wrappedValue.count) selected")
        }
    }
}

struct PhoneFilterDateBounds: View {
    @Binding var from: Date?
    @Binding var to: Date?
    let now: Date

    var body: some View {
        Section("Custom Range") {
            bound("From", value: $from)
            bound("To", value: $to)
        }
    }

    @ViewBuilder private func bound(_ label: String, value: Binding<Date?>) -> some View {
        Toggle(label, isOn: Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? now : nil }))
        if let date = Binding(value) { DatePicker(label, selection: date, displayedComponents: .date) }
    }
}

private struct PhoneFilterRuleNode: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @FocusState private var editingKeyword: Bool
    @State private var showingActions = false
    @State private var showingAdd = false
    @Binding var rule: FilterRule
    let data: WorkspaceData
    let depth: Int
    let path: String
    var remove: (() -> Void)? = nil

    var body: some View {
        switch rule {
        case .and(let children): group("AND", detail: "All conditions", children: children, matchAll: true)
        case .or(let children): group("OR", detail: "Any condition", children: children, matchAll: false)
        case .not(let child):
            VStack(alignment: .leading, spacing: 8) {
                operatorHeader("NOT", detail: "Invert condition")
                nested {
                    PhoneFilterRuleNode(rule: Binding(get: {
                        if case .not(let current) = rule { return current }
                        return child
                    }, set: { if case .not = rule { rule = .not($0) } }),
                    data: data, depth: depth + 1, path: path + "-not")
                }
            }.modifier(PhoneFilterGroupSurface())
        case .condition(let condition):
            HStack(spacing: 4) {
                let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) :
                    AnyLayout(HStackLayout(spacing: 8))
                layout { conditionFields(condition) }
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions
            }
            .padding(.leading, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func operatorHeader(_ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .accessibilityIdentifier("filterOperator-" + path)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            actions
        }
    }

    private var actions: some View {
        Button { showingActions = true } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Rule actions")
        .accessibilityIdentifier("filterRuleActions-" + path)
        .confirmationDialog("Rule actions", isPresented: $showingActions) {
            switch rule {
            case .and:
                Button("Change to OR") { rule = FilterRuleEdit.convertToOr(rule) }
            case .or:
                Button("Change to AND") { rule = FilterRuleEdit.convertToAnd(rule) }
            case .not(let child):
                Button("Remove NOT") { rule = child }
            case .condition:
                Button("Group with AND") { rule = FilterRuleEdit.convertToAnd(rule) }.disabled(!canWrap)
                Button("Group with OR") { rule = FilterRuleEdit.convertToOr(rule) }.disabled(!canWrap)
            }
            Button("Wrap in NOT") { rule = FilterRuleEdit.convertToNot(rule, depth: depth) }.disabled(!canWrap)
            if let remove { Button("Remove rule", role: .destructive, action: remove) }
        }
    }

    private var canWrap: Bool { depth + descendantDepth(rule) < FilterRuleEdit.maxDepth }

    private func descendantDepth(_ rule: FilterRule) -> Int {
        switch rule {
        case .and(let children), .or(let children): children.map(descendantDepth).max().map { $0 + 1 } ?? 0
        case .not(let child): 1 + descendantDepth(child)
        case .condition: 0
        }
    }

    private func group(_ name: String, detail: String, children: [FilterRule], matchAll: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            operatorHeader(name, detail: detail)
            if children.isEmpty {
                Text("Empty group matches all eligible tasks.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(children.indices, id: \.self) { index in
                nested {
                    PhoneFilterRuleNode(rule: child(at: index, fallback: children[index], matchAll: matchAll),
                                        data: data, depth: depth + 1, path: path + "-\(index)",
                                        remove: { removeChild(at: index, matchAll: matchAll) })
                }
            }
            if depth < FilterRuleEdit.maxDepth {
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus").frame(minHeight: 44).padding(.horizontal, 8).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("filterAddRule-" + path)
                .confirmationDialog("Add to " + name, isPresented: $showingAdd) {
                    Button("Add condition") { add(.condition(FilterCondition(kind: .status, status: .active)), matchAll: matchAll) }
                    Button("Add AND group") { add(.and([]), matchAll: matchAll) }.disabled(depth + 1 >= FilterRuleEdit.maxDepth)
                    Button("Add OR group") { add(.or([]), matchAll: matchAll) }.disabled(depth + 1 >= FilterRuleEdit.maxDepth)
                }
            }
        }.modifier(PhoneFilterGroupSurface())
    }

    private func nested<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.leading, depth < 3 ? 9 : 4)
            .overlay(alignment: .leading) { Capsule().fill(Color.accentColor.opacity(0.25)).frame(width: 2) }
    }

    private func add(_ child: FilterRule, matchAll: Bool) {
        let children = groupChildren() + [child]
        rule = matchAll ? .and(children) : .or(children)
    }

    private func removeChild(at index: Int, matchAll: Bool) {
        var children = groupChildren()
        guard children.indices.contains(index) else { return }
        children.remove(at: index)
        rule = matchAll ? .and(children) : .or(children)
    }

    private func child(at index: Int, fallback: FilterRule, matchAll: Bool) -> Binding<FilterRule> {
        Binding(get: {
            let children = groupChildren()
            return children.indices.contains(index) ? children[index] : fallback
        }, set: { updated in
            var children = groupChildren()
            guard children.indices.contains(index) else { return }
            children[index] = updated
            rule = matchAll ? .and(children) : .or(children)
        })
    }

    private func groupChildren() -> [FilterRule] {
        switch rule {
        case .and(let children), .or(let children): children
        default: []
        }
    }

    @ViewBuilder private func conditionFields(_ current: FilterCondition) -> some View {
        let condition = Binding(get: {
            if case .condition(let value) = rule { return value }
            return current
        }, set: { rule = .condition($0) })
        Picker("Condition", selection: Binding(get: { condition.wrappedValue.kind },
                                                set: { condition.wrappedValue = FilterCondition(kind: $0) })) {
            ForEach(FilterConditionKind.allCases, id: \.self) { kind in Text(kind.label).tag(kind) }
        }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Condition kind")
            .accessibilityIdentifier("filterConditionKind-" + path)
        switch current.kind {
        case .list:
            let lists = [(TaskFilter.inboxListID, "Inbox")] + data.lists.map { ($0.id, $0.name) }
            referencePicker("List", selection: condition.listID, options: lists)
        case .tag:
            referencePicker("Tag", selection: condition.tagID, options: data.tags.map { ($0.id, $0.name) })
        case .priority:
            Picker("Priority", selection: condition.priority) {
                Text("Choose priority").tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases, id: \.self) { priority in Text(priority.phoneLabel).tag(Optional(priority)) }
            }.pickerStyle(.menu).labelsHidden()
        case .date:
            Picker("Date", selection: condition.dateRule) {
                Text("Choose date").tag(FilterDateRule?.none)
                ForEach(FilterDateRule.allCases, id: \.self) { date in Text(date.label).tag(Optional(date)) }
            }.pickerStyle(.menu).labelsHidden()
        case .kind:
            Picker("Type", selection: condition.taskKind) {
                Text("Choose type").tag(TaskKind?.none)
                Text("Task").tag(Optional(TaskKind.task))
                Text("Note").tag(Optional(TaskKind.note))
            }.pickerStyle(.menu).labelsHidden()
        case .status:
            Picker("Status", selection: condition.status) {
                Text("Choose status").tag(FilterStatus?.none)
                ForEach(FilterStatus.allCases, id: \.self) { status in Text(status.phoneLabel).tag(Optional(status)) }
            }.pickerStyle(.menu).labelsHidden()
        case .keyword:
            TextField("Keyword", text: Binding(get: { condition.wrappedValue.keyword ?? "" },
                                               set: { condition.wrappedValue.keyword = $0 }))
                .focused($editingKeyword).submitLabel(.done).onSubmit { editingKeyword = false }
                .accessibilityIdentifier("filterRuleKeyword-" + path)
        case .noTags, .repeating: EmptyView()
        }
    }

    private func referencePicker(_ label: String, selection: Binding<UUID?>, options: [(UUID, String)]) -> some View {
        Picker(label, selection: selection) {
            Text("Choose " + label.lowercased()).tag(UUID?.none)
            ForEach(options, id: \.0) { id, name in Text(name).tag(Optional(id)) }
            if let id = selection.wrappedValue, !options.contains(where: { $0.0 == id }) {
                Text("Unavailable " + label.lowercased()).tag(Optional(id))
            }
        }.pickerStyle(.menu).labelsHidden()
    }
}


private struct PhoneFilterGroupSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, 8).padding(.bottom, 4)
            .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}
