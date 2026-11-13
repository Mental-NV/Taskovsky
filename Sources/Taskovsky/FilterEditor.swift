import SwiftUI
import TaskovskyCore

struct FilterEditorView: View {
    @ObservedObject var store: TaskStore
    let filter: TaskFilter?
    @Environment(\.dismiss) private var dismiss
    @State private var draftID: UUID
    @State private var saveError: String?
    @State private var name: String
    @State private var keyword: String
    @State private var listIDs: Set<UUID>
    @State private var tagIDs: Set<UUID>
    @State private var tagMode: FilterTagMode
    @State private var priorities: Set<TaskPriority>
    @State private var dateRules: Set<FilterDateRule>
    @State private var kinds: Set<TaskKind>
    @State private var status: FilterStatus
    @State private var customFrom: Date
    @State private var hasCustomFrom: Bool
    @State private var customTo: Date
    @State private var hasCustomTo: Bool
    @State private var advanced: Bool
    @State private var ruleRoot: FilterRule?

    init(store: TaskStore, filter: TaskFilter? = nil, initialKeyword: String = "", initialDateRules: [FilterDateRule] = [], initialStatus: FilterStatus = .active, initialListIDs: [UUID]? = nil, initialTagIDs: [UUID]? = nil, initialTagMode: FilterTagMode = .any, initialPriorities: [TaskPriority] = [], initialKinds: [TaskKind] = [], initialCustomFrom: Date? = nil, initialCustomTo: Date? = nil) {
        self.store = store; self.filter = filter
        _draftID = State(initialValue: filter?.id ?? UUID())
        _name = State(initialValue: filter?.name ?? initialKeyword)
        _keyword = State(initialValue: filter?.keyword ?? initialKeyword)
        _listIDs = State(initialValue: Set(filter?.listIDs ?? initialListIDs ?? []))
        _tagIDs = State(initialValue: Set(filter?.tagIDs ?? initialTagIDs ?? []))
        _tagMode = State(initialValue: filter?.tagMode ?? initialTagMode)
        _priorities = State(initialValue: Set(filter?.priorities ?? initialPriorities))
        _dateRules = State(initialValue: Set(filter?.dateRules ?? initialDateRules))
        _kinds = State(initialValue: Set(filter?.kinds ?? initialKinds))
        _status = State(initialValue: filter?.status ?? initialStatus)
        _customFrom = State(initialValue: filter?.customDateFrom ?? initialCustomFrom ?? Date())
        _hasCustomFrom = State(initialValue: (filter?.customDateFrom ?? initialCustomFrom) != nil)
        _customTo = State(initialValue: filter?.customDateTo ?? initialCustomTo ?? Date())
        _hasCustomTo = State(initialValue: (filter?.customDateTo ?? initialCustomTo) != nil)
        _advanced = State(initialValue: filter?.ruleRoot != nil)
        _ruleRoot = State(initialValue: filter?.ruleRoot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(filter == nil ? "New Filter" : "Edit Filter").font(.system(size: 18, weight: .bold))
            TextField("Filter name", text: $name)
            Picker("Mode", selection: $advanced) {
                Text("Normal").tag(false)
                Text("Advanced").tag(true)
            }.pickerStyle(.segmented)
            if advanced {
                ScrollView {
                    if let root = Binding($ruleRoot) {
                        RuleNodeView(store: store, rule: root, depth: 0, path: "root", onDelete: { ruleRoot = nil; advanced = false })
                    } else {
                        Button("Add Rule Group") { ruleRoot = .and([]) }
                    }
                    customRangeRow.padding(.top, 10)
                }.frame(height: 340)
            } else {
                Form {
                    TextField("Keyword", text: $keyword)
                    Menu {
                        Toggle("Inbox", isOn: membership(TaskFilter.inboxListID, in: $listIDs))
                        ForEach(store.data.lists) { list in Toggle(list.name, isOn: membership(list.id, in: $listIDs)) }
                        if !deadListIDs.isEmpty {
                            Divider()
                            ForEach(deadListIDs, id: \.self) { dead in
                                Toggle("Unavailable list", isOn: membership(dead, in: $listIDs)).help("This list was deleted. The selection matches nothing; turn it off to clear it.")
                            }
                        }
                    } label: { selectionLabel("Lists", count: listIDs.count) }
                    Menu {
                        Picker("Match", selection: $tagMode) {
                            ForEach(FilterTagMode.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if tagMode == .any || tagMode == .all {
                            Divider()
                            if store.data.tags.isEmpty { Text("No tags") }
                            ForEach(store.data.tags) { tag in Toggle(tag.name, isOn: membership(tag.id, in: $tagIDs)) }
                            if !deadTagIDs.isEmpty {
                                Divider()
                                ForEach(deadTagIDs, id: \.self) { dead in
                                    Toggle("Unavailable tag", isOn: membership(dead, in: $tagIDs)).help("This tag was deleted. The selection matches nothing; turn it off to clear it.")
                                }
                            }
                        } else {
                            Text(tagMode == .none ? "Tasks without any tag" : "Tasks with any tag").font(.caption).foregroundStyle(.secondary)
                        }
                    } label: { selectionLabel("Tags", count: tagMode == .any || tagMode == .all ? tagIDs.count : 1, suffix: tagMode.label) }
                    Menu {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in Toggle(priority.label, isOn: membership(priority, in: $priorities)) }
                    } label: { selectionLabel("Priority", count: priorities.count) }
                    Menu {
                        ForEach(FilterDateRule.allCases, id: \.self) { rule in
                            Button { dateRules = DateRuleSelection.toggling(rule, in: dateRules) } label: {
                                if rule == .all ? (dateRules.isEmpty || dateRules.contains(.all)) : dateRules.contains(rule) {
                                    Label(rule.label, systemImage: "checkmark")
                                } else { Text(rule.label) }
                            }
                        }
                    } label: { selectionLabel("Date", count: dateRules.count) }
                    if dateRules.contains(.custom) { customRangeRow }
                    Menu {
                        Toggle("Tasks", isOn: membership(.task, in: $kinds))
                        Toggle("Notes", isOn: membership(.note, in: $kinds))
                    } label: { selectionLabel("Type", count: kinds.count) }
                    Picker("Status", selection: $status) { Text("Uncompleted").tag(FilterStatus.active); Text("Completed").tag(FilterStatus.completed); Text("Won't Do").tag(FilterStatus.wontDo); Text("All").tag(FilterStatus.all) }
                }.formStyle(.grouped).frame(height: 300)
            }
            if let saveError { Text(saveError).font(.system(size: 12)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save") { saveFilter() }.keyboardShortcut(.defaultAction).disabled(!canSave) }
        }.padding(24).frame(width: 520).tint(accent)
    }

    private var customRangeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom range (days inclusive)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Toggle("From", isOn: $hasCustomFrom)
                DatePicker("", selection: $customFrom, displayedComponents: .date).labelsHidden().disabled(!hasCustomFrom)
            }
            HStack {
                Toggle("To", isOn: $hasCustomTo)
                DatePicker("", selection: $customTo, displayedComponents: .date).labelsHidden().disabled(!hasCustomTo)
            }
        }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if advanced { return ruleRoot != nil }
        // A custom date rule needs at least one bound; nothing else is
        // impossible to save (empty selections mean "any").
        if dateRules.contains(.custom), !hasCustomFrom, !hasCustomTo { return false }
        return true
    }

    private func membership<T: Hashable>(_ id: T, in binding: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue.contains(id) }, set: { selected in if selected { binding.wrappedValue.insert(id) } else { binding.wrappedValue.remove(id) } })
    }
    private func selectionLabel(_ label: String, count: Int, suffix: String? = nil) -> some View {
        HStack { Text(label); Spacer(); Text(count == 0 ? "Any" : suffix.map { "\($0) · \(count)" } ?? "\(count) selected").foregroundStyle(.secondary) }
    }
    /// IDs selected here that no longer name a live list/tag. They persist
    /// as no-match (editing or renaming must never broaden a filter), and
    /// the menus below surface them as unavailable for deliberate removal.
    private var deadListIDs: [UUID] {
        let live = Set(store.data.lists.map(\.id))
        return listIDs.filter { $0 != TaskFilter.inboxListID && !live.contains($0) }
    }
    private var deadTagIDs: [UUID] {
        let live = Set(store.data.tags.map(\.id))
        return tagIDs.filter { !live.contains($0) }
    }
    private func saveFilter() {
        // Dead selections persist untouched: pruning an only-deleted
        // selection would broaden the filter from "nothing" to "everything".
        // Rule trees are never rewritten (fail-closed instead).
        let value = TaskFilter(
            id: draftID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            listIDs: Array(listIDs), tagIDs: Array(tagIDs),
            priorities: Array(priorities), dateRules: Array(dateRules),
            status: status, keyword: keyword, kinds: Array(kinds), tagMode: tagMode,
            customDateFrom: (dateRules.contains(.custom) || advanced) && hasCustomFrom ? customFrom : nil,
            customDateTo: (dateRules.contains(.custom) || advanced) && hasCustomTo ? customTo : nil,
            isPinned: filter?.isPinned ?? false,
            ruleRoot: advanced ? ruleRoot : nil)
        let saved: Bool
        if let filter { saved = store.updateFilter(value, expected: filter) }
        else { saved = store.createFilter(value) != nil }
        guard saved else {
            saveError = store.storageError ?? "Filter was not saved. Your draft is still here; retry or cancel."
            return
        }
        saveError = nil
        dismiss()
    }
}

/// Recursive AND/OR/NOT rule builder. Depth is capped so the tree cannot grow
/// without bound through the UI; saved files decode at any depth.
private struct RuleNodeView: View {
    @ObservedObject var store: TaskStore
    @Binding var rule: FilterRule
    var depth: Int
    var path: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        switch rule {
        case .and(let children): group("AND", detail: "All conditions", children: children)
        case .or(let children): group("OR", detail: "Any condition", children: children)
        case .not(let child):
            VStack(alignment: .leading, spacing: 6) {
                operatorHeader("NOT", detail: "Invert condition")
                nested {
                    RuleNodeView(store: store, rule: childBindingSingle(child), depth: depth + 1, path: path + "-not")
                }
            }.modifier(MacFilterGroupSurface())
        case .condition(let condition):
            HStack(spacing: 8) {
                FilterConditionView(store: store, condition: conditionBinding(condition), path: path)
                Spacer(minLength: 0)
                actions
            }
            .padding(.leading, 8)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func operatorHeader(_ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .accessibilityIdentifier("macFilterOperator-" + path)
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            actions
        }
    }

    private var actions: some View {
        Menu {
            switch rule {
            case .and:
                Button("Change to OR") { rule = FilterRuleEdit.convertToOr(rule) }
            case .or:
                Button("Change to AND") { rule = FilterRuleEdit.convertToAnd(rule) }
            case .not(let child):
                Button("Remove NOT") { rule = child }
                Button("Group with AND") { rule = FilterRuleEdit.convertToAnd(rule) }
                Button("Group with OR") { rule = FilterRuleEdit.convertToOr(rule) }
            case .condition:
                Button("Group with AND") { rule = FilterRuleEdit.convertToAnd(rule) }
                Button("Group with OR") { rule = FilterRuleEdit.convertToOr(rule) }
            }
            Button("Wrap in NOT") { rule = FilterRuleEdit.convertToNot(rule, depth: depth) }
                .disabled(depth >= FilterRuleEdit.maxDepth)
            if FilterRuleEdit.convertToCondition(rule) != rule {
                Button("Unwrap single condition") { rule = FilterRuleEdit.convertToCondition(rule) }
            }
            if let onDelete { Button("Remove rule", role: .destructive, action: onDelete) }
        } label: {
            Image(systemName: "ellipsis").frame(width: 28, height: 24).contentShape(Rectangle())
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Rule actions").accessibilityLabel("Rule actions").accessibilityIdentifier("macFilterActions-" + path)
    }

    private func group(_ title: String, detail: String, children: [FilterRule]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            operatorHeader(title, detail: detail)
            if children.isEmpty {
                Text("Empty group matches all eligible tasks.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(children.indices, id: \.self) { index in
                nested {
                    RuleNodeView(store: store, rule: childBinding(index), depth: depth + 1,
                                 path: path + "-\(index)", onDelete: { removeChild(index) })
                }
            }
            Menu {
                Button("Add Condition") { addChild(Self.staleCondition) }
                if depth < FilterRuleEdit.maxDepth {
                    Button("Add AND Group") { addChild(.and([])) }
                    Button("Add OR Group") { addChild(.or([])) }
                    Button("Add NOT") { addChild(.not(Self.staleCondition)) }
                }
            } label: {
                Label("Add", systemImage: "plus").font(.system(size: 12)).foregroundStyle(accent)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityIdentifier("macFilterAdd-" + path)
        }.modifier(MacFilterGroupSurface())
    }

    private func nested<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.leading, depth < FilterRuleEdit.maxDepth ? 9 : 4)
            .overlay(alignment: .leading) { Capsule().fill(accent.opacity(0.28)).frame(width: 2) }
    }

    /// A stale index (the tree changed under the row) reads as an empty
    /// condition and writes/removals no-op instead of trapping.
    private static let staleCondition = FilterRule.condition(FilterCondition(kind: .keyword, keyword: ""))
    private func childBinding(_ index: Int) -> Binding<FilterRule> {
        Binding(get: {
            switch rule { case .and(let c), .or(let c): return c.indices.contains(index) ? c[index] : Self.staleCondition; default: return Self.staleCondition }
        }, set: { new in
            switch rule {
            case .and(var c): guard c.indices.contains(index) else { return }; c[index] = new; rule = .and(c)
            case .or(var c): guard c.indices.contains(index) else { return }; c[index] = new; rule = .or(c)
            default: break
            }
        })
    }
    private func childBindingSingle(_ child: FilterRule) -> Binding<FilterRule> {
        Binding(get: {
            if case .not(let c) = rule { return c }
            return child
        }, set: { if case .not = rule { rule = .not($0) } })
    }
    private func conditionBinding(_ condition: FilterCondition) -> Binding<FilterCondition> {
        Binding(get: {
            if case .condition(let c) = rule { return c }
            return condition
        }, set: { rule = .condition($0) })
    }
    private func addChild(_ child: FilterRule) {
        switch rule {
        case .and(var c): c.append(child); rule = .and(c)
        case .or(var c): c.append(child); rule = .or(c)
        default: break
        }
    }
    private func removeChild(_ index: Int) {
        switch rule {
        case .and(var c): guard c.indices.contains(index) else { return }; c.remove(at: index); rule = .and(c)
        case .or(var c): guard c.indices.contains(index) else { return }; c.remove(at: index); rule = .or(c)
        default: break
        }
    }
}

private struct MacFilterGroupSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(8)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FilterConditionView: View {
    @ObservedObject var store: TaskStore
    @Binding var condition: FilterCondition
    let path: String

    var body: some View {
        HStack(spacing: 8) {
            Picker("Kind", selection: $condition.kind) {
                ForEach(FilterConditionKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }.pickerStyle(.menu).fixedSize().labelsHidden()
            .accessibilityLabel("Condition kind").accessibilityIdentifier("macFilterKind-" + path)
            .onChange(of: condition.kind) { _, kind in seedDefaults(for: kind) }
            valueView
        }
    }

    /// New conditions start unset; seed the editor's displayed defaults so a
    /// fresh condition means what its picker shows (Today, no priority, task
    /// type, uncompleted) instead of matching nothing.
    private func seedDefaults(for kind: FilterConditionKind) {
        switch kind {
        case .date: if condition.dateRule == nil { condition.dateRule = .today }
        case .priority: if condition.priority == nil { condition.priority = TaskPriority.none }
        case .kind: if condition.taskKind == nil { condition.taskKind = .task }
        case .status: if condition.status == nil { condition.status = .active }
        case .list, .tag, .noTags, .keyword, .repeating: break
        }
    }

    @ViewBuilder private var valueView: some View {
        switch condition.kind {
        case .list:
            Menu {
                Button("Inbox") { condition.listID = TaskFilter.inboxListID }
                ForEach(store.data.lists) { list in Button(list.name) { condition.listID = list.id } }
            } label: { Text(listName).foregroundStyle(.secondary) }
        case .tag:
            Menu {
                ForEach(store.data.tags) { tag in Button(tag.name) { condition.tagID = tag.id } }
            } label: { Text(tagName).foregroundStyle(.secondary) }
        case .priority:
            Picker("Priority", selection: Binding(get: { condition.priority ?? TaskPriority.none }, set: { condition.priority = $0 })) {
                ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) }
            }.pickerStyle(.menu).fixedSize().labelsHidden()
        case .date:
            Picker("Date", selection: Binding(get: { condition.dateRule ?? .today }, set: { condition.dateRule = $0 })) {
                ForEach(FilterDateRule.allCases, id: \.self) { Text($0.label).tag($0) }
            }.pickerStyle(.menu).fixedSize().labelsHidden()
        case .kind:
            Picker("Type", selection: Binding(get: { condition.taskKind ?? .task }, set: { condition.taskKind = $0 })) {
                Text("Task").tag(TaskKind.task); Text("Note").tag(TaskKind.note)
            }.pickerStyle(.menu).fixedSize().labelsHidden()
        case .status:
            Picker("Status", selection: Binding(get: { condition.status ?? .active }, set: { condition.status = $0 })) {
                Text("Uncompleted").tag(FilterStatus.active); Text("Completed").tag(FilterStatus.completed)
                Text("Won't Do").tag(FilterStatus.wontDo); Text("All").tag(FilterStatus.all)
            }.pickerStyle(.menu).fixedSize().labelsHidden()
        case .keyword:
            TextField("Keyword", text: Binding(get: { condition.keyword ?? "" }, set: { condition.keyword = $0 }))
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("macFilterKeyword-" + path)
        case .noTags, .repeating:
            EmptyView()
        }
    }

    private var listName: String {
        guard let id = condition.listID else { return "Choose list" }
        if id == TaskFilter.inboxListID { return "Inbox" }
        return store.data.lists.first { $0.id == id }?.name ?? "Unavailable list"
    }
    private var tagName: String {
        guard let id = condition.tagID else { return "Choose tag" }
        return store.data.tags.first { $0.id == id }?.name ?? "Unavailable tag"
    }
}
