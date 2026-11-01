import SwiftUI
import TaskovskyCore

struct SearchPane: View {
    @ObservedObject var store: TaskStore
    let initialQuery: String
    let onSelectTask: (UUID) -> Void
    let onSelectList: (UUID) -> Void
    let onSelectFilter: (UUID) -> Void
    let onSelectTag: (UUID) -> Void
    let onClose: () -> Void
    @State private var query: String
    @State private var editing = false
    @State private var dateRule: FilterDateRule = .all
    @State private var status: FilterStatus = .all
    @State private var listID: UUID?
    @State private var tagID: UUID?
    @State private var saveFilter = false
    init(store: TaskStore, initialQuery: String, onSelectTask: @escaping (UUID) -> Void, onSelectList: @escaping (UUID) -> Void, onSelectFilter: @escaping (UUID) -> Void, onSelectTag: @escaping (UUID) -> Void, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        self.store = store; self.initialQuery = initialQuery; self.onSelectTask = onSelectTask; self.onSelectList = onSelectList; self.onSelectFilter = onSelectFilter; self.onSelectTag = onSelectTag
        _query = State(initialValue: initialQuery)
    }
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tasks: [TaskItem] {
        let criteria = TaskFilter(name: "", listIDs: listID.map { [$0] } ?? [], tagIDs: tagID.map { [$0] } ?? [], dateRule: dateRule, status: status)
        return store.data.tasks.filter { criteria.matches($0, calendar: store.settings.calendar) && TaskSearch.matches($0, query: trimmed) }
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
              HStack(spacing: 12) {
                Picker("Date", selection: $dateRule) { Text("All Dates").tag(FilterDateRule.all); Text("Today").tag(FilterDateRule.today); Text("Tomorrow").tag(FilterDateRule.tomorrow); Text("Next 7 Days").tag(FilterDateRule.next7); Text("Overdue").tag(FilterDateRule.overdue); Text("No Date").tag(FilterDateRule.noDate) }.frame(width: 140)
                Picker("List", selection: $listID) { Text("All Lists").tag(nil as UUID?); ForEach(store.data.lists) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 140)
                Picker("Tag", selection: $tagID) { Text("All Tags").tag(nil as UUID?); ForEach(store.data.tags) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 140)
                Picker("Status", selection: $status) { Text("All Status").tag(FilterStatus.all); Text("Uncompleted").tag(FilterStatus.active); Text("Completed").tag(FilterStatus.completed); Text("Won't Do").tag(FilterStatus.wontDo) }.frame(width: 140)
              }.labelsHidden()
            }.padding(.bottom, 16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tasks.isEmpty { Text("No results found").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 50) }
                    ForEach(tasks) { task in
                        Button { onSelectTask(task.id) } label: {
                            HStack(spacing: 10) { Image(systemName: task.completedAt != nil ? "checkmark.circle.fill" : task.wontDoAt != nil ? "minus.circle" : "circle").foregroundStyle(task.completedAt != nil ? accent : task.priority.color)
                                VStack(alignment: .leading, spacing: 3) { Text(task.title).font(.system(size: 14)); if !task.body.isEmpty { Text(task.body).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1) } }
                                Spacer(); if let list = store.data.lists.first(where: { $0.id == task.listID }) { Text(list.name).font(.system(size: 12)).foregroundStyle(.secondary) }
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 20)
            }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .sheet(isPresented: $saveFilter) { FilterEditorView(store: store, filter: nil, initialKeyword: trimmed, initialDateRule: dateRule, initialStatus: status, initialListID: listID, initialTagID: tagID) }
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
    @State private var query = ""
    @State private var recent: [String] = UserDefaults.standard.stringArray(forKey: "Taskovsky.recentSearches") ?? []
    @FocusState private var focused: Bool
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tasks: [TaskItem] { store.data.tasks.filter { $0.deletedAt == nil && TaskSearch.matches($0, query: trimmed) } }
    private var lists: [TaskList] { store.data.lists.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    private var tags: [TaskTag] { store.data.tags.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    private var filters: [TaskFilter] { store.data.filters.filter { $0.name.localizedCaseInsensitiveContains(trimmed) } }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search tasks, lists, tags, and filters", text: $query).textFieldStyle(.plain).font(.system(size: 16)).focused($focused).onSubmit { guard !trimmed.isEmpty else { return }; remember(); onSearch(trimmed) }; if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }; Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Close Search").help("Close Search").keyboardShortcut(.cancelAction) }.padding(18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if trimmed.isEmpty {
                        HStack { Text("Recent Searches").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if !recent.isEmpty { Button("Clear") { recent = []; UserDefaults.standard.removeObject(forKey: "Taskovsky.recentSearches") }.buttonStyle(.plain).foregroundStyle(accent) } }
                        ForEach(recent, id: \.self) { term in Button { query = term } label: { Label(term, systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain) }
                    } else {
                        if !tasks.isEmpty { group("Tasks") { ForEach(tasks.prefix(8)) { task in result(task.title, symbol: "circle") { remember(); onSelectTask(task.id) } } } }
                        if !lists.isEmpty { group("Lists") { ForEach(lists.prefix(8)) { list in result(list.name, symbol: "list.bullet") { remember(); onSelectList(list.id) } } } }
                        if !tags.isEmpty { group("Tags") { ForEach(tags.prefix(8)) { tag in result(tag.name, symbol: "number") { remember(); onSelectTag(tag.id) } } } }
                        if !filters.isEmpty { group("Filters") { ForEach(filters.prefix(8)) { filter in result(filter.name, symbol: "line.3.horizontal.decrease.circle") { remember(); onSelectFilter(filter.id) } } } }
                        if tasks.isEmpty && lists.isEmpty && tags.isEmpty && filters.isEmpty { Text("No results found").foregroundStyle(.secondary) }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !trimmed.isEmpty { Divider(); HStack { Text("Press Return to see all results").font(.system(size: 12)).foregroundStyle(.secondary); Spacer() }.padding(12) }
        }.frame(width: 550, height: 420).onAppear { focused = true }
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary); content() } }
    private func result(_ title: String, symbol: String, action: @escaping () -> Void) -> some View { Button(action: action) { Label(title, systemImage: symbol).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).contentShape(Rectangle()) }.buttonStyle(.plain) }
    private func remember() { guard !trimmed.isEmpty else { return }; recent.removeAll { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }; recent.insert(trimmed, at: 0); recent = Array(recent.prefix(10)); UserDefaults.standard.set(recent, forKey: "Taskovsky.recentSearches") }
}
