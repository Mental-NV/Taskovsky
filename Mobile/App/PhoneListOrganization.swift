import SwiftUI
import UIKit
import TaskovskyDomain
import TaskovskyWorkspace

extension TaskList {
    var phoneListColor: Color { PhoneEntityColor.read(color) }
}

enum PhoneEntityColor {
    static func read(_ value: String) -> Color {
        let raw = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6, let rgb = UInt32(raw, radix: 16) else { return .accentColor }
        return Color(red: Double(rgb >> 16) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    static func encode(_ color: Color) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let channels = [r, g, b].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}

private struct ListEditorRequest: Identifiable {
    let id = UUID()
    let revision: WorkspaceRevision
    let list: TaskList?
    let folder: ListFolder?
    let creating: Bool
}

struct PhoneListOrganization: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var request: ListEditorRequest?
    @State private var reordering = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let document = model.document {
                    let data = document.snapshot.workspace
                    let active = data.lists.filter { !$0.isArchived }
                    Section {
                        Button("New List", systemImage: "plus") {
                            open(list: TaskList(name: "", color: "#4E64D8"), creating: true)
                        }.accessibilityIdentifier("organizationNewList")
                        Button("New Folder", systemImage: "folder.badge.plus") {
                            open(folder: ListFolder(name: ""), creating: true)
                        }.accessibilityIdentifier("organizationNewFolder")
                    }.disabled(!model.canBeginEditing || reordering)
                    if !data.folders.isEmpty {
                        Section("Folders") {
                            ForEach(Array(data.folders.enumerated()), id: \.element.id) { index, folder in
                                row(name: folder.name, symbol: "folder", id: folder.id, index: index,
                                    ids: data.folders.map(\.id), folder: true) { open(folder: folder) }
                            }
                        }
                    }
                    lists("Lists above folders", active.filter { ListPlacement($0) == .aboveFolders })
                    ForEach(data.folders) { folder in
                        lists(folder.name, active.filter { $0.folderID == folder.id })
                    }
                    lists("Lists below folders", active.filter { ListPlacement($0) == .belowFolders })
                    lists("Archived Lists", data.lists.filter(\.isArchived), movable: false)
                    if let error {
                        Text(error).foregroundStyle(.red).accessibilityIdentifier("organizationReorderError")
                    }
                }
            }
            .navigationTitle("Manage Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(reordering ? "Finish Reordering" : "Reorder") { reordering.toggle() }
                        .disabled(!model.canBeginEditing).accessibilityIdentifier("organizationReorder")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(model.isBusy)
                        .accessibilityIdentifier("organizationManagerDone")
                }
            }
        }
        .sheet(item: $request) { PhoneListEditor(model: model, request: $0) }
        .interactiveDismissDisabled(model.isBusy)
    }

    @ViewBuilder private func lists(_ title: String, _ lists: [TaskList], movable: Bool = true) -> some View {
        if !lists.isEmpty {
            Section(title) {
                ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                    row(name: list.name, symbol: list.symbol ?? "list.bullet", id: list.id, index: index,
                        ids: movable ? lists.map(\.id) : [], folder: false) { open(list: list) }
                }
            }
        }
    }

    private func row(name: String, symbol: String, id: UUID, index: Int, ids: [UUID], folder: Bool,
                     open: @escaping () -> Void) -> some View {
        HStack {
            if reordering {
                Label(name, systemImage: symbol)
                Spacer()
                if !ids.isEmpty {
                    reorderButton(name, id: id, neighbor: index > 0 ? ids[index - 1] : nil, down: false, folder: folder)
                    reorderButton(name, id: id, neighbor: index + 1 < ids.count ? ids[index + 1] : nil, down: true, folder: folder)
                }
            } else {
                Button(action: open) {
                    HStack {
                        Label(name, systemImage: symbol)
                        Spacer()
                        Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!model.canBeginEditing)
                    .accessibilityIdentifier((folder ? "manageFolder-" : "manageList-") + id.uuidString)
            }
        }
    }

    private func reorderButton(_ name: String, id: UUID, neighbor: UUID?, down: Bool, folder: Bool) -> some View {
        Button {
            guard let neighbor, let revision = model.document?.revision else { return }
            let command: ListOrganizationCommand = folder
                ? .reorderFolder(id, relativeTo: neighbor, after: down)
                : .reorderList(id, relativeTo: neighbor, after: down)
            Task { error = await model.saveOrganization(command, expected: revision) }
        } label: {
            Image(systemName: down ? "arrow.down" : "arrow.up")
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(neighbor == nil || !model.canBeginEditing)
            .accessibilityLabel("Move " + name + (down ? " down" : " up"))
            .accessibilityIdentifier((down ? "organizationMoveDown-" : "organizationMoveUp-") + id.uuidString)
    }

    private func open(list: TaskList? = nil, folder: ListFolder? = nil, creating: Bool = false) {
        guard let revision = model.document?.revision else { return }
        request = ListEditorRequest(revision: revision, list: list, folder: folder, creating: creating)
    }
}

private struct PhoneListEditor: View {
    private enum Confirmation: String, Identifiable {
        case discard, delete, duplicate, ungroup
        var id: Self { self }
        var title: String {
            switch self {
            case .discard: "Discard changes?"
            case .delete: "Delete list?"
            case .duplicate: "Duplicate list?"
            case .ungroup: "Ungroup folder?"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: ListEditorRequest
    @State private var list: TaskList
    @State private var folder: ListFolder
    @State private var placement: ListPlacement
    @State private var composing = false
    @State private var focusRequest: UUID?
    @State private var confirm: Confirmation?
    @State private var error: String?
    @State private var copyID = UUID()

    init(model: PhoneWorkspaceModel, request: ListEditorRequest) {
        self.model = model
        self.request = request
        let list = request.list ?? TaskList(name: "", color: "#4E64D8")
        _list = State(initialValue: list)
        _placement = State(initialValue: ListPlacement(list))
        _folder = State(initialValue: request.folder ?? ListFolder(name: ""))
    }

    private var isList: Bool { request.list != nil }
    private var entityName: String { isList ? list.name : folder.name }
    private var fieldLabel: String { isList ? "List name" : "Folder name" }
    private var hasChanges: Bool {
        if composing { return true }
        if let original = request.list {
            return list != original || !RichBody.sameCodeUnits(list.name, original.name) || placement != ListPlacement(original)
        }
        if let original = request.folder {
            return folder != original || !RichBody.sameCodeUnits(folder.name, original.name)
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        NativeFieldInput(text: isList ? $list.name : $folder.name, composing: $composing, editorID: request.id,
                                         title: false, editable: !model.isBusy, focusOnAppear: request.creating,
                                         accessibilityID: "organizationName", focusRequest: focusRequest, fieldLabel: fieldLabel)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .simultaneousGesture(TapGesture().onEnded { focusRequest = UUID() })
                            .overlay(alignment: .leading) {
                                if entityName.isEmpty {
                                    Text(fieldLabel).foregroundStyle(.tertiary).allowsHitTesting(false).accessibilityHidden(true)
                                }
                            }
                        if !entityName.isEmpty {
                            Button {
                                if isList { list.name = "" } else { folder.name = "" }
                                focusRequest = UUID()
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(composing)
                                .accessibilityLabel("Clear name").accessibilityIdentifier("organizationClearName")
                        }
                    }
                }
                if isList { listFields }
                else { Toggle("Pin folder", isOn: $folder.isPinned).accessibilityIdentifier("organizationPin") }
                if !request.creating {
                    Section {
                        if isList {
                            Button("Duplicate List") { confirm = .duplicate }.accessibilityIdentifier("organizationDuplicate")
                            Button("Delete List", role: .destructive) { confirm = .delete }.accessibilityIdentifier("organizationDelete")
                        } else {
                            Button("Ungroup Folder", role: .destructive) { confirm = .ungroup }.accessibilityIdentifier("organizationUngroup")
                        }
                    }.disabled(hasChanges)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(model.isBusy)
            .safeAreaInset(edge: .bottom) {
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote).padding()
                        .background(.regularMaterial).accessibilityIdentifier("organizationSaveError")
                }
            }
            .navigationTitle((request.creating ? "New " : "Edit ") + (isList ? "List" : "Folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if hasChanges { confirm = .discard } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("organizationCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(model.isBusy || composing || entityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("organizationSave")
                }
            }
        }
        .interactiveDismissDisabled(hasChanges || model.isBusy)
        .alert(item: $confirm, content: alert)
    }

    private var listFields: some View {
        Section {
            Picker("Type", selection: $list.kind) {
                Text("Tasks").tag(TaskKind.task)
                Text("Notes").tag(TaskKind.note)
            }
            ColorPicker("Color", selection: Binding(get: { list.phoneListColor }, set: { list.color = PhoneEntityColor.encode($0) ?? list.color }),
                        supportsOpacity: false)
            Picker("Icon", selection: $list.symbol) {
                Text("Default").tag(String?.none)
                ForEach(symbols, id: \.self) { name in Label(name, systemImage: name).tag(Optional(name)) }
            }
            Picker("Placement", selection: $placement) {
                Text("Above folders").tag(ListPlacement.aboveFolders)
                ForEach(model.document?.snapshot.workspace.folders ?? []) { folder in
                    Text(folder.name).tag(ListPlacement.folder(folder.id))
                }
                Text("Below folders").tag(ListPlacement.belowFolders)
            }.pickerStyle(.menu).accessibilityIdentifier("organizationPlacement")
            Toggle("Show in Smart Lists", isOn: $list.showsInSmartLists).accessibilityIdentifier("organizationSmartInclusion")
            Toggle("Pin list", isOn: $list.isPinned).accessibilityIdentifier("organizationPin")
            if !request.creating {
                Toggle("Archived", isOn: $list.isArchived).accessibilityIdentifier("organizationArchive")
            }
        }
    }

    private var symbols: [String] {
        let options = ["list.bullet", "star", "briefcase", "house", "book", "heart", "cart", "graduationcap"]
        guard let existing = list.symbol, !options.contains(existing) else { return options }
        return [existing] + options
    }

    private func alert(_ value: Confirmation) -> Alert {
        switch value {
        case .discard:
            Alert(title: Text(value.title), primaryButton: .destructive(Text("Discard Changes")) { dismiss() },
                  secondaryButton: .cancel(Text("Keep Editing")))
        case .delete:
            Alert(title: Text(value.title), message: Text("Tasks from “\(list.name)” will move to Inbox. Saved filters retain the unavailable list."),
                  primaryButton: .destructive(Text("Delete List")) { submit(.deleteList(list.id)) }, secondaryButton: .cancel())
        case .duplicate:
            Alert(title: Text(value.title), message: Text("Copy “\(list.name)” and its tasks outside Trash?"),
                  primaryButton: .default(Text("Duplicate List")) { submit(.duplicateList(list.id, copyID: copyID)) }, secondaryButton: .cancel())
        case .ungroup:
            Alert(title: Text(value.title), message: Text("Lists in “\(folder.name)” will move above folders. Their tasks stay in those lists."),
                  primaryButton: .destructive(Text("Ungroup Folder")) { submit(.ungroupFolder(folder.id)) }, secondaryButton: .cancel())
        }
    }

    private func save() {
        if isList {
            var edited = list
            if request.creating || placement != ListPlacement(list) { placement.apply(to: &edited) }
            submit(.saveList(edited, creating: request.creating))
        } else {
            submit(.saveFolder(folder, creating: request.creating))
        }
    }

    private func submit(_ command: ListOrganizationCommand) {
        Task {
            error = await model.saveOrganization(command, expected: request.revision)
            if error == nil { dismiss() }
        }
    }
}
