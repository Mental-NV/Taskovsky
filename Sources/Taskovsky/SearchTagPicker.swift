import SwiftUI
import TaskovskyCore

struct SearchTagDraft: Equatable {
    var ids: Set<UUID>
    var mode: FilterTagMode
    mutating func selectAll() { ids.removeAll(); mode = .any }
    mutating func toggle(_ id: UUID) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
}

private enum SearchTagFocus: Hashable { case all, mode(FilterTagMode), tag(UUID), cancel, apply }

struct SearchTagPicker: View {
    let tags: [TaskTag]
    let onApply: (SearchTagDraft) -> Void
    let onCancel: () -> Void
    @State private var draft: SearchTagDraft
    @State private var focused: SearchTagFocus = .all
    @FocusState private var keyboardFocused: Bool
    init(tags: [TaskTag], ids: Set<UUID>, mode: FilterTagMode, onApply: @escaping (SearchTagDraft) -> Void, onCancel: @escaping () -> Void) {
        self.tags = tags; self.onApply = onApply; self.onCancel = onCancel
        _draft = State(initialValue: SearchTagDraft(ids: ids, mode: mode))
    }
    private var usesIDs: Bool { draft.mode == .any || draft.mode == .all }
    private var order: [SearchTagFocus] {
        [.all, .mode(.none), .mode(.anyTagged), .mode(.any), .mode(.all)]
        + (usesIDs ? tags.map { .tag($0.id) } : []) + [.cancel, .apply]
    }
    private func activate(_ target: SearchTagFocus) {
        focused = target; keyboardFocused = true
        switch target {
        case .all: draft.selectAll()
        case .mode(let mode): draft.mode = mode
        case .tag(let id): draft.toggle(id)
        case .cancel: onCancel()
        case .apply: onApply(draft)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tags").font(.system(size: 13, weight: .semibold)).padding(12)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        row("All", target: .all, selected: usesIDs && draft.ids.isEmpty)
                        row("No Tags", target: .mode(.none), selected: draft.mode == .none)
                        row("Any Tag", target: .mode(.anyTagged), selected: draft.mode == .anyTagged)
                        Divider()
                        Text("Match selected tags").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10)
                        row("Any selected", target: .mode(.any), selected: draft.mode == .any)
                        row("All selected", target: .mode(.all), selected: draft.mode == .all)
                        if usesIDs {
                            Divider()
                            ForEach(tags) { tag in row(tag.name, target: .tag(tag.id), selected: draft.ids.contains(tag.id)) }
                            if tags.isEmpty { Text("No tags available").font(.caption).foregroundStyle(.secondary).padding(10) }
                        }
                    }.padding(.vertical, 6)
                }.frame(maxHeight: 340)
                    .onChange(of: focused) { _, value in proxy.scrollTo(value) }
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).background(focused == .cancel ? Color.primary.opacity(0.07) : .clear)
                Button("OK") { onApply(draft) }.background(focused == .apply ? Color.primary.opacity(0.07) : .clear)
            }.padding(10)
        }.frame(width: 280).accessibilityIdentifier("SearchTagPicker")
            .focusable().focusEffectDisabled().focused($keyboardFocused)
            .onAppear { DispatchQueue.main.async { keyboardFocused = true } }
            .onKeyPress(.space) { activate(focused); return .handled }
            .onKeyPress(phases: .down) { press in
                guard let backwards = SearchListKeyboard.backwards(character: press.key.character, shift: press.modifiers.contains(.shift)) else { return .ignored }
                let targets = order
                let index = targets.firstIndex(of: focused) ?? (backwards ? 0 : -1)
                focused = targets[(index + (backwards ? -1 : 1) + targets.count) % targets.count]
                return .handled
            }
            .onKeyPress(.return) { if focused == .cancel { onCancel() } else { onApply(draft) }; return .handled }
            .onKeyPress(.escape) { onCancel(); return .handled }
    }
    private func row(_ name: String, target: SearchTagFocus, selected: Bool) -> some View {
        Button { activate(target) } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.square.fill" : "square").foregroundStyle(selected ? Color.accentColor : .secondary).frame(width: 14)
                Text(name).lineLimit(2)
                Spacer(minLength: 4)
            }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.id(target).buttonStyle(.plain)
            .background(focused == target ? Color.primary.opacity(0.07) : .clear)
            .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
