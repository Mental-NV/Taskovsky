import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

private extension SmartListKey {
    var phoneLabel: String {
        switch self {
        case .all: "All"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .week: "Next 7 Days"
        case .inbox: "Inbox"
        case .summary: "Summary"
        case .tags: "Tags"
        case .filters: "Filters"
        case .completed: "Completed"
        case .wontDo: "Won't Do"
        case .trash: "Trash"
        }
    }
}

private extension SmartListVisibility {
    var phoneLabel: String {
        switch self {
        case .show: "Show"
        case .hidden: "Hidden"
        case .showIfNotEmpty: "Show if not empty"
        }
    }
}

struct PhoneSmartDrawer: Equatable {
    static let topGroup = AppSettings.topSmartGroup
    let top: [TaskDestination]
    let bottom: [TaskDestination]
    let tags: Bool
    let filters: Bool
    let pinnedFilters: Set<UUID>
    let pinnedTags: Set<UUID>

    init(settings: AppSettings, data: WorkspaceData, now: Date, calendar: Calendar) {
        func visible(_ group: [SmartListKey]) -> [TaskDestination] {
            settings.effectiveSmartListOrder.compactMap { key in
                guard group.contains(key), let dest = TaskDestination(smartKey: key),
                      settings.isSmartListVisible(key, count: dest.matchingTasks(in: data, showHistory: false,
                                                                                 now: now, calendar: calendar).count)
                else { return nil }
                return dest
            }
        }
        top = visible(Self.topGroup)
        bottom = visible(AppSettings.bottomSmartGroup)
        tags = settings.isSmartListVisible(.tags, count: data.tags.count)
        filters = settings.isSmartListVisible(.filters, count: data.filters.count)
        pinnedFilters = Set(data.filters.filter(\.isPinned).map(\.id))
        pinnedTags = Set(data.tags.filter(\.isPinned).map(\.id))
    }

    func shows(_ destination: TaskDestination) -> Bool {
        switch destination {
        case .tag(let id): tags || pinnedTags.contains(id)
        case .filter(let id): filters || pinnedFilters.contains(id)
        default: destination.smartKey == nil || top.contains(destination) || bottom.contains(destination)
        }
    }

    var fallback: TaskDestination { top.first ?? bottom.first ?? .inbox }
}

struct PhoneSmartListRequest: Identifiable {
    let id = UUID()
    let settings: AppSettings
    let revision: WorkspaceRevision
}

struct PhoneSmartListSettings: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneSmartListRequest
    @State private var draft: AppSettings
    @State private var reordering = false
    @State private var confirmDiscard = false
    @State private var error: String?

    init(model: PhoneWorkspaceModel, request: PhoneSmartListRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: request.settings)
    }

    private var changed: Bool {
        draft.smartListVisibility != request.settings.smartListVisibility ||
            draft.effectiveSmartListOrder != request.settings.effectiveSmartListOrder
    }

    var body: some View {
        NavigationStack {
            List {
                rows("Smart Lists", keys: PhoneSmartDrawer.topGroup)
                if !reordering {
                    Section("Drawer sections") {
                        visibility(.tags)
                        visibility(.filters)
                    }
                }
                rows("History", keys: AppSettings.bottomSmartGroup)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.regularMaterial)
                        .accessibilityIdentifier("smartListError")
                }
            }
            .disabled(model.isBusy)
            .navigationTitle("Smart Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if changed { confirmDiscard = true } else { dismiss() }
                    }.disabled(model.isBusy).accessibilityIdentifier("smartListCancel")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button(reordering ? "Finish" : "Reorder") { reordering.toggle() }
                        .disabled(model.isBusy).accessibilityIdentifier("smartListReorder")
                    Button("Done", action: save).disabled(model.isBusy).accessibilityIdentifier("smartListDone")
                }
            }
        }
        .interactiveDismissDisabled(changed || model.isBusy)
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private func rows(_ title: String, keys: [SmartListKey]) -> some View {
        let ordered = draft.effectiveSmartListOrder.filter(keys.contains)
        return Section(title) {
            ForEach(Array(ordered.enumerated()), id: \.element) { index, key in
                if reordering {
                    HStack {
                        Text(key.phoneLabel)
                        Spacer()
                        move(key, neighbor: index > 0 ? ordered[index - 1] : nil, down: false)
                        move(key, neighbor: index + 1 < ordered.count ? ordered[index + 1] : nil, down: true)
                    }
                } else {
                    visibility(key)
                }
            }
        }
    }

    private func visibility(_ key: SmartListKey) -> some View {
        Picker(key.phoneLabel, selection: Binding(get: { draft.smartListVisibility[key] ?? .show },
                                                   set: { draft.smartListVisibility[key] = $0 })) {
            ForEach(SmartListVisibility.allCases, id: \.self) { option in
                Text(option.phoneLabel).tag(option)
            }
        }.pickerStyle(.navigationLink).accessibilityIdentifier("smartListVisibility-" + key.rawValue)
    }

    private func move(_ key: SmartListKey, neighbor: SmartListKey?, down: Bool) -> some View {
        Button {
            guard let neighbor else { return }
            _ = draft.reorderSmartList(moving: key, before: neighbor, afterTarget: down)
        } label: {
            Image(systemName: down ? "arrow.down" : "arrow.up")
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(neighbor == nil)
            .accessibilityLabel("Move " + key.phoneLabel + (down ? " down" : " up"))
            .accessibilityIdentifier((down ? "smartListDown-" : "smartListUp-") + key.rawValue)
    }

    private func save() {
        guard changed else { dismiss(); return }
        Task {
            error = await model.saveSmartLists(draft, expected: request.revision)
            if error == nil { dismiss() }
        }
    }
}
