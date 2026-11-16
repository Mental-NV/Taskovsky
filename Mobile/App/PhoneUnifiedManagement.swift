import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

/// Entry token for the unified Smart Lists/Tags management sheet (T09/T11).
struct PhoneManagementRequest: Identifiable {
    let id = UUID()
    let settings: AppSettings
    let revision: WorkspaceRevision
    let initialTab: UnifiedManagementTab
}

private enum ManagementPendingChild {
    case newTag
    case editTag(UUID)
    case newFilter
}

/// Unified Smart Lists/Tags management (T09/T11).
///
/// One sheet with Smart Lists and Tags tabs sharing a single staged visibility
/// draft, so tab switching never resets staged rows. The Smart Lists tab keeps
/// the genuine visibility pickers, within-group reorder and Add Filter; the
/// Tags tab keeps the Tags visibility picker, Add Tag and the existing tag
/// rows. Nested Add/Edit Tag and Add Filter reuse the standalone editors and
/// their revision-checked saves. A dirty parent gates nested entry behind an
/// explicit Save/Discard/Keep Editing choice instead of silently abandoning or
/// overwriting staged edits. The parent CAS token stays pinned while dirty; a
/// successful child mutation refreshes the baseline only when clean.
struct PhoneUnifiedManagement: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneManagementRequest
    @State private var session: UnifiedManagementSession
    @State private var reordering = false
    @State private var confirmDiscard = false
    @State private var confirmChild = false
    @State private var pendingChild: ManagementPendingChild?
    @State private var tagRequest: PhoneTagRequest?
    @State private var filterRequest: PhoneFilterRequest?
    @State private var error: String?

    init(model: PhoneWorkspaceModel, request: PhoneManagementRequest) {
        self.model = model
        self.request = request
        _session = State(initialValue: UnifiedManagementSession(settings: request.settings,
                                                               revision: request.revision,
                                                               selectedTab: request.initialTab))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Manage", selection: Binding(get: { session.selectedTab },
                                                    set: {
                                                        session.select($0)
                                                        // Reorder belongs to the Smart Lists tab: leaving it
                                                        // resets the mode so Tags controls stay enabled.
                                                        if $0 != .smartLists { reordering = false }
                                                    })) {
                    Text("Smart Lists").tag(UnifiedManagementTab.smartLists)
                    Text("Tags").tag(UnifiedManagementTab.tags)
                }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
                    .accessibilityIdentifier("managementTabs")
                List {
                    if session.selectedTab == .smartLists {
                        smartListsContent
                    } else {
                        tagsContent
                    }
                }.listStyle(.insetGrouped)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.regularMaterial)
                        .accessibilityIdentifier("managementError")
                }
            }
            .disabled(model.isBusy)
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if session.isDirty { confirmDiscard = true } else { dismiss() }
                    }.disabled(model.isBusy).accessibilityIdentifier("managementCancel")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if session.selectedTab == .smartLists {
                        Button(reordering ? "Finish" : "Reorder") { reordering.toggle() }
                            .disabled(model.isBusy).accessibilityIdentifier("managementReorder")
                    }
                    Button("Done", action: saveAndThenContinue)
                        .disabled(model.isBusy).accessibilityIdentifier("managementDone")
                }
            }
        }
        .interactiveDismissDisabled(session.isDirty || model.isBusy)
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .confirmationDialog("Unsaved visibility changes", isPresented: $confirmChild, titleVisibility: .visible) {
            Button("Save Changes") { saveAndThenContinue() }
                .accessibilityIdentifier("managementSaveAndContinue")
            Button("Discard Changes", role: .destructive) { discardThenOpen() }
                .accessibilityIdentifier("managementDiscardAndContinue")
            Button("Keep Editing", role: .cancel) { pendingChild = nil }
        } message: {
            Text("Save or discard the staged Smart List visibility before adding or editing.")
        }
        .sheet(item: $tagRequest) { PhoneTagEditor(model: model, request: $0) }
        .sheet(item: $filterRequest) { PhoneFilterEditor(model: model, request: $0) }
        .onChange(of: model.document?.revision) { _, _ in adoptLatestDocumentIfClean() }
    }

    /// Moves the baseline to the live document when nothing is staged.
    ///
    /// Owned child saves, external updates and stale-recovery reloads all
    /// arrive here, and any of them is safe to adopt while clean: the session
    /// holds no user edits, and the settings plus revision always come from
    /// this one exact document — fields are never paired across revisions and
    /// newer unrelated settings are preserved. While dirty this refuses, so
    /// staged edits keep their original token and fail stale instead of being
    /// overwritten.
    private func adoptLatestDocumentIfClean() {
        guard let document = model.document else { return }
        _ = session.adoptCleanBaseline(from: document)
    }

    // MARK: - Smart Lists tab

    @ViewBuilder private var smartListsContent: some View {
        smartRows("Smart Lists", keys: AppSettings.topSmartGroup)
        if !reordering {
            Section("Drawer sections") {
                visibility(.filters)
            }
            Section {
                Button("Add Filter", systemImage: "plus") { requestChild(.newFilter) }
                    .disabled(model.isBusy || !canOpenChild)
                    .accessibilityIdentifier("addFilter")
            }
        }
        smartRows("History", keys: AppSettings.bottomSmartGroup)
    }

    private func smartRows(_ title: String, keys: [SmartListKey]) -> some View {
        let ordered = session.staged.effectiveSmartListOrder.filter(keys.contains)
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
        Picker(key.phoneLabel, selection: Binding(get: { session.staged.smartListVisibility[key] ?? .show },
                                                  set: { option in session.stage { $0.smartListVisibility[key] = option } })) {
            ForEach(SmartListVisibility.allCases, id: \.self) { option in
                Text(option.phoneLabel).tag(option)
            }
        }.pickerStyle(.navigationLink).accessibilityIdentifier("smartListVisibility-" + key.rawValue)
    }

    private func move(_ key: SmartListKey, neighbor: SmartListKey?, down: Bool) -> some View {
        Button {
            guard let neighbor else { return }
            session.stage { _ = $0.reorderSmartList(moving: key, before: neighbor, afterTarget: down) }
        } label: {
            Image(systemName: down ? "arrow.down" : "arrow.up")
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(neighbor == nil)
            .accessibilityLabel("Move " + key.phoneLabel + (down ? " down" : " up"))
            .accessibilityIdentifier((down ? "smartListDown-" : "smartListUp-") + key.rawValue)
    }

    // MARK: - Tags tab

    @ViewBuilder private var tagsContent: some View {
        Section("Tags") {
            visibility(.tags)
        }
        Section {
            Button("Add Tag", systemImage: "tag") { requestChild(.newTag) }
                .disabled(reordering || !canOpenChild)
                .accessibilityIdentifier("newTag")
            if let document = model.document {
                let tags = document.snapshot.workspace.tags
                ForEach(orderedTags(tags)) { tag in
                    let depth = TagHierarchy.ancestors(of: tag.id, in: tags).count
                    Button { requestChild(.editTag(tag.id)) } label: {
                        HStack {
                            tagLabel(tag)
                            Spacer()
                            if tag.isPinned { Image(systemName: "pin.fill").accessibilityHidden(true) }
                            Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44).padding(.leading, CGFloat(min(depth, 4)) * 12).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!canOpenChild)
                        .accessibilityIdentifier("manageTag-" + tag.id.uuidString)
                }
            }
        }
    }

    /// Same depth-first presentation order as the standalone tag manager.
    private func orderedTags(_ tags: [TaskTag]) -> [TaskTag] {
        var result: [TaskTag] = []
        var seen = Set<UUID>()
        func visit(_ tag: TaskTag) {
            guard seen.insert(tag.id).inserted else { return }
            result.append(tag)
            TagHierarchy.children(of: tag.id, in: tags).forEach(visit)
        }
        TagHierarchy.roots(in: tags).forEach(visit)
        tags.forEach(visit)
        return result
    }

    private func tagLabel(_ tag: TaskTag) -> some View {
        HStack {
            Image(systemName: "tag").foregroundStyle(PhoneEntityColor.read(tag.color)).accessibilityHidden(true)
            Text(tag.name)
        }
    }

    // MARK: - Nested entry gating

    private var canOpenChild: Bool {
        !model.isBusy && model.canBeginEditing && model.document != nil &&
            tagRequest == nil && filterRequest == nil && !confirmChild
    }

    private func requestChild(_ child: ManagementPendingChild) {
        guard canOpenChild else { return }
        if session.needsChildDecision {
            pendingChild = child
            confirmChild = true
        } else {
            openChild(child)
        }
    }

    private func openChild(_ child: ManagementPendingChild) {
        // The snapshot and the CAS token always come from this one exact
        // document. Edit Tag captures only the ID at tap time and resolves it
        // here, so a tag renamed or deleted while the dirty gate was open is
        // never paired with a newer token — and a missing tag refuses to open.
        guard canOpenChild, let document = model.document else { return }
        let revision = document.revision
        switch child {
        case .newTag:
            tagRequest = PhoneTagRequest(tag: TaskTag(name: "", color: "#4E64D8"), creating: true, revision: revision)
        case .editTag(let id):
            guard let handoff = session.tagHandoff(tagID: id, in: document) else {
                error = "That tag is no longer available."
                return
            }
            tagRequest = PhoneTagRequest(tag: handoff.tag, creating: false, revision: handoff.revision)
        case .newFilter:
            filterRequest = PhoneFilterRequest(filter: TaskFilter(name: ""), creating: true, revision: revision)
        }
    }

    private func saveAndThenContinue() {
        Task {
            guard session.isDirty else { finishSaveContinue(); return }
            let staged = session.staged
            let expected = session.baselineRevision
            if let message = await model.saveSmartLists(staged, expected: expected) {
                // The boundary failed: drop the pending child intent so a later
                // ordinary Done retries the save instead of opening the child
                // requested before the failure.
                pendingChild = nil
                error = message
                return
            }
            error = nil
            if let document = model.document { session.markSaved(revision: document.revision) }
            finishSaveContinue()
        }
    }

    private func finishSaveContinue() {
        if let child = pendingChild {
            pendingChild = nil
            openChild(child)
        } else {
            dismiss()
        }
    }

    private func discardThenOpen() {
        guard let child = pendingChild else { return }
        pendingChild = nil
        session.discardStaged()
        if let document = model.document {
            _ = session.adoptCleanBaseline(from: document)
        }
        openChild(child)
    }
}
