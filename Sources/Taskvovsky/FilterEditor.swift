import SwiftUI
import TaskvovskyCore

struct FilterEditorView: View {
    @ObservedObject var store: TaskStore
    let filter: TaskFilter?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var keyword: String
    @State private var listIDs: Set<UUID>
    @State private var tagIDs: Set<UUID>
    @State private var priority: TaskPriority?
    @State private var dateRule: FilterDateRule
    @State private var status: FilterStatus

    init(store: TaskStore, filter: TaskFilter? = nil, initialKeyword: String = "", initialDateRule: FilterDateRule = .all, initialStatus: FilterStatus = .active, initialListID: UUID? = nil, initialTagID: UUID? = nil) {
        self.store = store; self.filter = filter
        _name = State(initialValue: filter?.name ?? initialKeyword)
        _keyword = State(initialValue: filter?.keyword ?? initialKeyword)
        _listIDs = State(initialValue: Set(filter?.listIDs ?? initialListID.map { [$0] } ?? [])); _tagIDs = State(initialValue: Set(filter?.tagIDs ?? initialTagID.map { [$0] } ?? []))
        _priority = State(initialValue: filter?.priority); _dateRule = State(initialValue: filter?.dateRule ?? initialDateRule)
        _status = State(initialValue: filter?.status ?? initialStatus)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(filter == nil ? "New Filter" : "Edit Filter").font(.system(size: 18, weight: .bold))
            TextField("Filter name", text: $name)
            Form {
                TextField("Keyword", text: $keyword)
                Menu {
                    if store.data.lists.isEmpty { Text("No lists") }
                    ForEach(store.data.lists) { list in Toggle(list.name, isOn: membership(list.id, in: $listIDs)) }
                } label: { selectionLabel("Lists", count: listIDs.count) }
                Menu {
                    if store.data.tags.isEmpty { Text("No tags") }
                    ForEach(store.data.tags) { tag in Toggle(tag.name, isOn: membership(tag.id, in: $tagIDs)) }
                } label: { selectionLabel("Tags", count: tagIDs.count) }
                Picker("Priority", selection: $priority) { Text("Any priority").tag(nil as TaskPriority?); ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag(Optional($0)) } }
                Picker("Date", selection: $dateRule) {
                    Text("Any date").tag(FilterDateRule.all); Text("Today").tag(FilterDateRule.today); Text("Tomorrow").tag(FilterDateRule.tomorrow); Text("Next 7 days").tag(FilterDateRule.next7); Text("Overdue").tag(FilterDateRule.overdue); Text("No date").tag(FilterDateRule.noDate)
                }
                Picker("Status", selection: $status) { Text("Uncompleted").tag(FilterStatus.active); Text("Completed").tag(FilterStatus.completed); Text("Won't Do").tag(FilterStatus.wontDo); Text("All").tag(FilterStatus.all) }
            }.formStyle(.grouped).frame(height: 300)
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save") { saveFilter() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 480).tint(accent)
    }
    private func membership(_ id: UUID, in binding: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue.contains(id) }, set: { selected in if selected { binding.wrappedValue.insert(id) } else { binding.wrappedValue.remove(id) } })
    }
    private func selectionLabel(_ label: String, count: Int) -> some View {
        HStack { Text(label); Spacer(); Text(count == 0 ? "Any" : "\(count) selected").foregroundStyle(.secondary) }
    }
    private func saveFilter() {
        let value = TaskFilter(id: filter?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), listIDs: Array(listIDs), tagIDs: Array(tagIDs), priority: priority, dateRule: dateRule, status: status, keyword: keyword)
        if filter == nil { store.createFilter(value) } else { store.updateFilter(value) }
        dismiss()
    }
}
