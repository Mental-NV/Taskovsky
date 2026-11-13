import SwiftUI
import TaskovskyCore

private func highlightedMatch(_ text: String, query: String) -> Text {
    guard !query.isEmpty else { return Text(text) }
    var result = AttributedString()
    var remaining = text[...]
    while let range = remaining.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
        result.append(AttributedString(String(remaining[..<range.lowerBound])))
        var match = AttributedString(String(remaining[range]))
        match.backgroundColor = .yellow.opacity(0.35)
        match.foregroundColor = .primary
        result.append(match)
        remaining = remaining[range.upperBound...]
    }
    result.append(AttributedString(String(remaining)))
    return Text(result)
}

private func searchSnippet(_ task: TaskItem, query: String) -> String? {
    guard !query.isEmpty else { return nil }
    let candidates = [task.body] + task.checklist.map(\.title)
    guard let text = candidates.first(where: { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }),
          let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
    let start = text.index(match.lowerBound, offsetBy: -45, limitedBy: text.startIndex) ?? text.startIndex
    let end = text.index(match.upperBound, offsetBy: 70, limitedBy: text.endIndex) ?? text.endIndex
    return (start == text.startIndex ? "" : "…") + text[start..<end].replacingOccurrences(of: "\n", with: " ") + (end == text.endIndex ? "" : "…")
}

private struct SearchTaskResult: View {
    let task: TaskItem
    let query: String
    let listName: String
    let listSymbol: String?
    var showDate = false
    let onOpen: () -> Void
    let onComplete: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if task.kind == .note {
                Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 22)
            } else {
                Button(action: onComplete) {
                    HoverIcon {
                        TaskCheckbox(state: task.wontDoAt != nil ? .wontDo : task.completedAt != nil ? .completed : .open, color: task.priority == .none ? Palette.taskOutline(colorScheme) : task.priority.color)
                            .frame(width: 18, height: 22).contentShape(Rectangle())
                    }
                }.buttonStyle(.plain).accessibilityLabel(task.completedAt != nil || task.wontDoAt != nil ? "Reopen task" : "Complete task")
            }
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        highlightedMatch(task.title, query: query).font(.system(size: 14)).lineLimit(1)
                        if let snippet = searchSnippet(task, query: query) {
                            highlightedMatch(snippet, query: query).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2)
                        }
                    }.layoutPriority(1)
                    Spacer(minLength: 8)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            if showDate, let due = task.dueDate { dueLabel(due) }
                            listLabel
                        }.fixedSize()
                        if showDate, let due = task.dueDate { dueLabel(due).fixedSize() }
                        EmptyView()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(.vertical, 6)
            .background(hovering ? Color.primary.opacity(0.032) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .onHover { hovering = $0 }
    }
    private var listLabel: some View {
        HStack(spacing: 4) { ListSymbol(symbol: listSymbol, size: 12); Text(listName) }
            .font(.system(size: 12)).foregroundStyle(.secondary)
    }
    private func dueLabel(_ due: Date) -> some View {
        Text(task.dayText(due) + (task.hasDueTime ? " " + task.timeText(due) : ""))
            .font(.system(size: 12)).foregroundStyle(.secondary)
    }
}

struct SearchPane: View {
    @ObservedObject var store: TaskStore
    let initialQuery: String
    let onSelectTask: (UUID) -> Void
    let onSelectList: (UUID) -> Void
    let onSelectFilter: (UUID) -> Void
    let onSelectTag: (UUID) -> Void
    let onComplete: (UUID) -> Void
    let onClose: () -> Void
    @State private var query: String
    @State private var editing = false
    @State private var dateRules: Set<FilterDateRule> = []
    @State private var status: FilterStatus = .all
    @State private var listIDs: Set<UUID> = []
    @State private var tagIDs: Set<UUID> = []
    @State private var tagMode: FilterTagMode = .any
    @State private var kinds: Set<TaskKind> = []
    @State private var customFrom = Date()
    @State private var hasCustomFrom = false
    @State private var customTo = Date()
    @State private var hasCustomTo = false
    @State private var saveFilter = false
    @State private var pickingLists = false
    @State private var pickingTags = false
    init(store: TaskStore, initialQuery: String, onSelectTask: @escaping (UUID) -> Void, onSelectList: @escaping (UUID) -> Void, onSelectFilter: @escaping (UUID) -> Void, onSelectTag: @escaping (UUID) -> Void, onComplete: @escaping (UUID) -> Void, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose; self.onComplete = onComplete
        self.store = store; self.initialQuery = initialQuery; self.onSelectTask = onSelectTask; self.onSelectList = onSelectList; self.onSelectFilter = onSelectFilter; self.onSelectTag = onSelectTag
        _query = State(initialValue: initialQuery)
    }
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var criteria: TaskFilter {
        TaskFilter(
            name: "", listIDs: Array(listIDs), tagIDs: Array(tagIDs),
            dateRules: Array(dateRules), status: status, kinds: Array(kinds), tagMode: tagMode,
            customDateFrom: dateRules.contains(.custom) && hasCustomFrom ? customFrom : nil,
            customDateTo: dateRules.contains(.custom) && hasCustomTo ? customTo : nil)
    }
    private var tasks: [TaskItem] {
        store.data.tasks.filter { criteria.matches($0, lists: store.data.lists, calendar: store.settings.calendar) && TaskSearch.matches($0, query: trimmed) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Close Search").help("Close Search")
                if editing { TextField("Search", text: $query, onCommit: { editing = false }).textFieldStyle(.roundedBorder).frame(maxWidth: 350) }
                else { Text("Search \(query)").font(.system(size: 20, weight: .bold)).lineLimit(1); Button { editing = true } label: { Image(systemName: "pencil").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Edit search") }
                Spacer()
                Button("Save as Filter") { saveFilter = true }.disabled(trimmed.isEmpty)
            }.padding(.bottom, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    dateMenu
                    Button { pickingLists = true } label: { menuLabel(listIDs.isEmpty ? "All Lists" : "Lists (\(listIDs.count))") }
                        .buttonStyle(.plain)
                        .popover(isPresented: $pickingLists, arrowEdge: .bottom) {
                            SearchListPicker(lists: store.data.lists, folders: store.data.folders, selection: listIDs,
                                onApply: { listIDs = $0; pickingLists = false },
                                onCancel: { pickingLists = false })
                        }
                    tagMenu
                    kindMenu
                    valueMenu(statusLabel, options: [("All Status", .all), ("Uncompleted", .active), ("Completed", .completed), ("Won't Do", .wontDo)], selection: $status)
                }
            }.padding(.bottom, 16)
            if dateRules.contains(.custom) { customRangeRow.padding(.bottom, 12) }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if tasks.isEmpty { Text("No results found").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 50) }
                    ForEach(tasks) { task in
                        SearchTaskResult(task: task, query: trimmed, listName: store.data.lists.first(where: { $0.id == task.listID })?.name ?? "Inbox", listSymbol: store.data.lists.first(where: { $0.id == task.listID })?.symbol, showDate: true, onOpen: { onSelectTask(task.id) }, onComplete: { onComplete(task.id) })
                    }
                }.padding(.vertical, 20)
            }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .sheet(isPresented: $saveFilter) {
                FilterEditorView(
                    store: store, filter: nil, initialKeyword: trimmed,
                    initialDateRules: Array(dateRules), initialStatus: status,
                    initialListIDs: Array(listIDs), initialTagIDs: Array(tagIDs),
                    initialTagMode: tagMode, initialKinds: Array(kinds),
                    initialCustomFrom: dateRules.contains(.custom) && hasCustomFrom ? customFrom : nil,
                    initialCustomTo: dateRules.contains(.custom) && hasCustomTo ? customTo : nil)
            }
    }
    private var dateMenu: some View {
        Menu {
            ForEach(FilterDateRule.allCases, id: \.self) { rule in
                Button { toggle(rule, in: $dateRules) } label: {
                    if dateRules.contains(rule) { Label(rule.label, systemImage: "checkmark") } else { Text(rule.label) }
                }
            }
        } label: { menuLabel(dateRules.isEmpty ? "All Dates" : dateRules.count == 1 ? dateRules.first!.label : "Dates (\(dateRules.count))") }
    }
    private var tagMenu: some View {
        Button { pickingTags = true } label: { menuLabel(tagLabel) }
            .buttonStyle(.plain)
            .popover(isPresented: $pickingTags, arrowEdge: .bottom) {
                SearchTagPicker(tags: store.data.tags, ids: tagIDs, mode: tagMode,
                    onApply: { tagIDs = $0.ids; tagMode = $0.mode; pickingTags = false },
                    onCancel: { pickingTags = false })
            }
    }
    private var tagLabel: String {
        switch tagMode {
        case .any: return tagIDs.isEmpty ? "All Tags" : "Tags (\(tagIDs.count))"
        case .all: return tagIDs.isEmpty ? "All Tags" : "Tags, all (\(tagIDs.count))"
        case .none: return "No Tags"
        case .anyTagged: return "Any Tag"
        }
    }
    private var kindMenu: some View {
        Menu {
            Button { toggle(TaskKind.task, in: $kinds) } label: {
                if kinds.contains(.task) { Label("Tasks", systemImage: "checkmark") } else { Text("Tasks") }
            }
            Button { toggle(TaskKind.note, in: $kinds) } label: {
                if kinds.contains(.note) { Label("Notes", systemImage: "checkmark") } else { Text("Notes") }
            }
        } label: { menuLabel(kinds.isEmpty ? "All Types" : kinds.count == 2 ? "All Types" : kinds.contains(.task) ? "Tasks" : "Notes") }
    }
    private var customRangeRow: some View {
        HStack(spacing: 16) {
            HStack { Toggle("From", isOn: $hasCustomFrom); DatePicker("", selection: $customFrom, displayedComponents: .date).labelsHidden().disabled(!hasCustomFrom) }
            HStack { Toggle("To", isOn: $hasCustomTo); DatePicker("", selection: $customTo, displayedComponents: .date).labelsHidden().disabled(!hasCustomTo) }
            if !hasCustomFrom, !hasCustomTo { Text("Pick at least one bound.").font(.caption).foregroundStyle(.secondary) }
        }.font(.system(size: 13))
    }
    private func toggle<T: Hashable>(_ value: T, in binding: Binding<Set<T>>) {
        if binding.wrappedValue.contains(value) { binding.wrappedValue.remove(value) } else { binding.wrappedValue.insert(value) }
    }
    private var statusLabel: String { switch status { case .all: "All Status"; case .active: "Uncompleted"; case .completed: "Completed"; case .wontDo: "Won't Do" } }
    private func menuLabel(_ text: String) -> some View { HStack(spacing: 5) { Text(text); Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }.font(.system(size: 13)).foregroundStyle(.secondary) }
    private func valueMenu<T: Equatable>(_ label: String, options: [(String, T)], selection: Binding<T>) -> some View {
        Menu { ForEach(Array(options.enumerated()), id: \.offset) { _, option in Button { selection.wrappedValue = option.1 } label: { if selection.wrappedValue == option.1 { Label(option.0, systemImage: "checkmark") } else { Text(option.0) } } } } label: { menuLabel(label) }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize()
    }

}

struct SearchDialog: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TaskStore
    let onSearch: (String) -> Void
    let onSelectTask: (UUID) -> Void
    let onSelectList: (UUID) -> Void
    let onSelectFilter: (UUID) -> Void
    let onSelectTag: (UUID) -> Void
    let onComplete: (UUID) -> Void
    @State private var query = ""
    @State private var recent: [String] = UserDefaults.standard.stringArray(forKey: "Taskovsky.recentSearches") ?? []
    @State private var selected: Int? = nil
    @FocusState private var focused: Bool
    private enum ResultID: Hashable { case task(UUID), list(UUID), tag(UUID), filter(UUID) }
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tasks: [TaskItem] { store.data.tasks.filter { $0.deletedAt == nil && TaskSearch.matches($0, query: trimmed) } }
    private var lists: [TaskList] { store.data.lists.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    private var tags: [TaskTag] { store.data.tags.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    private var filters: [TaskFilter] { store.data.filters.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    private var results: [ResultID] { tasks.prefix(5).map { .task($0.id) } + lists.prefix(8).map { .list($0.id) } + tags.prefix(8).map { .tag($0.id) } + filters.prefix(8).map { .filter($0.id) } }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search tasks, lists, tags, and filters", text: $query).textFieldStyle(.plain).font(.system(size: 16)).focused($focused).onSubmit { submit() }.onChange(of: query) { _, _ in selected = nil }.onKeyPress(.downArrow) { moveSelection(1); return .handled }.onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Close Search").help("Close Search").keyboardShortcut(.cancelAction)
            }.padding(18)
            Divider()
            ScrollViewReader { proxy in
              ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if trimmed.isEmpty {
                        HStack { Text("Recent Searches").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if !recent.isEmpty { Button("Clear") { recent = []; UserDefaults.standard.removeObject(forKey: "Taskovsky.recentSearches") }.buttonStyle(.plain).foregroundStyle(accent) } }
                        ForEach(recent, id: \.self) { term in Button { query = term } label: { Label(term, systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain) }
                    } else {
                        if !tasks.isEmpty { group("Tasks") {
                            ForEach(tasks.prefix(5)) { task in
                                SearchTaskResult(task: task, query: trimmed, listName: store.data.lists.first(where: { $0.id == task.listID })?.name ?? "Inbox", listSymbol: store.data.lists.first(where: { $0.id == task.listID })?.symbol, onOpen: { open(.task(task.id)) }, onComplete: { onComplete(task.id) })
                                    .background(selectionColor(.task(task.id)), in: RoundedRectangle(cornerRadius: 5)).id(ResultID.task(task.id))
                            }
                            Button("View more") { remember(); onSearch(trimmed) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(accent).padding(.vertical, 5)
                        } }
                        if !lists.isEmpty { group("Lists") { ForEach(lists.prefix(8)) { list in result(list.name, symbol: list.symbol ?? "line.3.horizontal", id: .list(list.id)) } } }
                        if !tags.isEmpty { group("Tags") { ForEach(tags.prefix(8)) { tag in result(tag.name, symbol: "tag", id: .tag(tag.id)) } } }
                        if !filters.isEmpty { group("Filters") { ForEach(filters.prefix(8)) { filter in result(filter.name, symbol: "line.3.horizontal.decrease.circle", id: .filter(filter.id)) } } }
                        if results.isEmpty { Text("No results found").foregroundStyle(.secondary) }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
              }
              .onChange(of: selected) { _, index in
                  if let index, results.indices.contains(index) { proxy.scrollTo(results[index], anchor: .center) }
              }
            }
            if !trimmed.isEmpty { Divider(); HStack { Text("Press Return to see all results").font(.system(size: 12)).foregroundStyle(.secondary); Spacer() }.padding(12) }
        }.frame(width: 550, height: 420).onAppear { focused = true }
            .onMoveCommand { direction in
                guard !trimmed.isEmpty, !results.isEmpty else { return }
                if direction == .down { moveSelection(1) }
                if direction == .up { moveSelection(-1) }
            }
    }
    private func moveSelection(_ step: Int) {
        guard !trimmed.isEmpty, !results.isEmpty else { return }
        if step > 0 { selected = min((selected ?? -1) + 1, results.count - 1) }
        else { selected = max((selected ?? results.count) - 1, 0) }
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary); content() } }
    private func selectionColor(_ id: ResultID) -> Color { selected.flatMap { results.indices.contains($0) ? results[$0] : nil } == id ? Color.primary.opacity(0.08) : .clear }
    private func result(_ title: String, symbol: String, id: ResultID) -> some View {
        Button { open(id) } label: { HStack(spacing: 10) {
            if case .list(let listID) = id { ListSymbol(symbol: store.data.lists.first(where: { $0.id == listID })?.symbol, size: 16).frame(width: 18) }
            else { Image(systemName: symbol).frame(width: 18) }
            highlightedMatch(title, query: trimmed)
        }.font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).contentShape(Rectangle()) }.buttonStyle(.plain).background(selectionColor(id), in: RoundedRectangle(cornerRadius: 5)).id(id)
    }
    private func submit() { guard !trimmed.isEmpty else { return }; if let selected, results.indices.contains(selected) { open(results[selected]) } else { remember(); onSearch(trimmed) } }
    private func open(_ id: ResultID) { remember(); switch id { case .task(let id): onSelectTask(id); case .list(let id): onSelectList(id); case .tag(let id): onSelectTag(id); case .filter(let id): onSelectFilter(id) } }
    private func remember() { guard !trimmed.isEmpty else { return }; recent.removeAll { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }; recent.insert(trimmed, at: 0); recent = Array(recent.prefix(10)); UserDefaults.standard.set(recent, forKey: "Taskovsky.recentSearches") }
}
