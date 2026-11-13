import SwiftUI
import TaskovskyCore

/// Presentation-only draft. Empty selection retains the existing All scope;
/// unknown IDs are preserved rather than silently broadening a saved filter.
struct SearchListSelectionDraft: Equatable {
    var ids: Set<UUID>
    mutating func toggle(_ id: UUID) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
    mutating func selectAll() { ids.removeAll() }
    enum Mark: String { case none, mixed, selected }
    func mark(for children: [UUID]) -> Mark {
        let members = Set(children)
        let count = ids.intersection(members).count
        if count == 0 { return .none }
        return count == members.count ? .selected : .mixed
    }
}

struct SearchListTree {
    struct Group: Identifiable {
        let folder: ListFolder
        let lists: [TaskList]
        var id: UUID { folder.id }
    }
    let leading: [TaskList]
    let groups: [Group]
    let trailing: [TaskList]
    init(lists: [TaskList], folders: [ListFolder]) {
        let folderIDs = Set(folders.map(\.id))
        let root = lists.filter { $0.folderID.map { !folderIDs.contains($0) } ?? true }
        leading = root.filter { !$0.belowFolders }
        trailing = root.filter(\.belowFolders)
        groups = folders.map { folder in Group(folder: folder, lists: lists.filter { $0.folderID == folder.id }) }
    }
}

struct SearchListPicker: View {
    let lists: [TaskList]
    let folders: [ListFolder]
    let onApply: (Set<UUID>) -> Void
    let onCancel: () -> Void
    @State private var draft: SearchListSelectionDraft
    @State private var expanded: Set<UUID>

    init(lists: [TaskList], folders: [ListFolder], selection: Set<UUID>, onApply: @escaping (Set<UUID>) -> Void, onCancel: @escaping () -> Void) {
        self.lists = lists; self.folders = folders; self.onApply = onApply; self.onCancel = onCancel
        _draft = State(initialValue: SearchListSelectionDraft(ids: selection))
        _expanded = State(initialValue: Set(folders.map(\.id)))
    }
    private var tree: SearchListTree { SearchListTree(lists: lists, folders: folders) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lists").font(.system(size: 13, weight: .semibold)).padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Button { draft.selectAll() } label: { row("All", selected: draft.ids.isEmpty, symbol: "tray.full") }
                        .buttonStyle(.plain).accessibilityValue(draft.ids.isEmpty ? "Selected" : "Not selected")
                    leaf(TaskFilter.inboxListID, name: "Inbox", symbol: "tray")
                    ForEach(tree.leading) { list in leaf(list.id, name: list.name, symbol: list.symbol) }
                    ForEach(tree.groups) { group in
                        let isExpanded = expanded.contains(group.id)
                        let mark = draft.mark(for: group.lists.map(\.id))
                        Button {
                            if isExpanded { expanded.remove(group.id) } else { expanded.insert(group.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 9)).frame(width: 14)
                                Image(systemName: "folder").foregroundStyle(.secondary).frame(width: 16)
                                Text(group.folder.name).lineLimit(2)
                                Spacer(minLength: 4)
                                Image(systemName: mark == .mixed ? "minus" : "checkmark").opacity(mark == .none ? 0 : 1)
                            }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(group.folder.name + " folder")
                            .accessibilityValue((isExpanded ? "Expanded" : "Collapsed") + ", " + mark.rawValue + " explicit selection")
                            .help("Expand or collapse folder")
                        if isExpanded {
                            ForEach(group.lists) { list in leaf(list.id, name: list.name, symbol: list.symbol).padding(.leading, 22) }
                        }
                    }
                    ForEach(tree.trailing) { list in leaf(list.id, name: list.name, symbol: list.symbol) }
                }.padding(.vertical, 6)
            }.frame(maxHeight: 340)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("OK") { onApply(draft.ids) }.keyboardShortcut(.defaultAction)
            }.padding(10)
        }.frame(width: 280).accessibilityIdentifier("SearchListPicker")
    }
    private func leaf(_ id: UUID, name: String, symbol: String?) -> some View {
        Button { draft.toggle(id) } label: { row(name, selected: draft.ids.contains(id), symbol: symbol) }
            .buttonStyle(.plain).accessibilityValue(draft.ids.contains(id) ? "Selected" : "Not selected")
    }
    private func row(_ name: String, selected: Bool, symbol: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: selected ? "checkmark.square.fill" : "square").foregroundStyle(selected ? Color.accentColor : .secondary).frame(width: 14)
            ListSymbol(symbol: symbol, size: 14).frame(width: 16)
            Text(name).lineLimit(2)
            Spacer(minLength: 4)
        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
