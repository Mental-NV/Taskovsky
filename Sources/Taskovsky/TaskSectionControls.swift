import SwiftUI
import TaskovskyDomain

struct TaskSectionOrganizer: View {
    @Environment(\.dismiss) private var dismiss
    let list: TaskList
    let editable: Bool
    let save: (TaskSectionChange.Operation) async -> String?
    @State private var name = ""
    @State private var renaming: UUID?
    @State private var removal: TaskSection?
    @State private var saving = false
    @State private var error: String?
    @Namespace private var sectionSpace
    @State private var rowFrames: [UUID: CGRect] = [:]
    @GestureState private var reorderTarget: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sections").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.disabled(saving)
                    .accessibilityIdentifier("sectionsDone")
            }.padding(.horizontal, 16)
            HStack {
                TextField("Section name", text: $name)
                    .accessibilityIdentifier("sectionName")
                    .onSubmit(saveName)
                Button(renaming == nil ? "Add Section" : "Save Name", action: saveName)
                    .accessibilityIdentifier("sectionSaveName")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if renaming != nil { Button("Cancel", action: clearName) }
            }.padding(.horizontal, 16).disabled(!editable || saving)
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 16)
                    .accessibilityIdentifier("sectionError")
            }
            sectionRows
        }
        .padding(.vertical, 16)
        .interactiveDismissDisabled(saving)
        .alert("Remove section?", isPresented: Binding(
            get: { removal != nil }, set: { if !$0 { removal = nil } }), presenting: removal) { section in
                Button("Remove Section", role: .destructive) {
                    submit(.remove(section.id))
                    if renaming == section.id { clearName() }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Tasks in this section will move to No Section.")
            }
    }

    private var sectionRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(list.sections.enumerated()), id: \.element.id) { index, section in
                    sectionRow(section, at: index)
                        .padding(.horizontal, 16).padding(.vertical, 4)
                        .background(reorderTarget == section.id ? Color.accentColor.opacity(0.16) : .clear)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: SectionRowFrames.self,
                                                   value: [section.id: geometry.frame(in: .named(sectionSpace))])
                        })
                    Divider().padding(.leading, 44)
                }
            }
        }
        .coordinateSpace(name: sectionSpace)
        .onPreferenceChange(SectionRowFrames.self) { rowFrames = $0 }
    }

    private func sectionRow(_ section: TaskSection, at index: Int) -> some View {
        HStack {
            if editable && !saving {
                sectionGrip(section, at: index)
            }
            Text(section.name)
            Spacer(minLength: 4)
            if editable {
                sectionActions(section, at: index).disabled(saving)
            }
        }
    }

    private func sectionGrip(_ section: TaskSection, at index: Int) -> some View {
        let grip = Image(systemName: "line.3.horizontal")
            .padding(6).contentShape(Rectangle())
            .accessibilityLabel("Drag " + section.name)
        return grip.gesture(DragGesture(minimumDistance: 5, coordinateSpace: .named(sectionSpace))
            .updating($reorderTarget) { value, target, _ in
                target = sectionTarget(at: value.location, excluding: section.id)
            }
            .onEnded { value in
                guard let target = sectionTarget(at: value.location, excluding: section.id),
                      let destination = list.sections.firstIndex(where: { $0.id == target }) else { return }
                submit(.reorder(section.id, relativeTo: target, after: index < destination))
            })
    }

    private func sectionTarget(at location: CGPoint, excluding source: UUID) -> UUID? {
        list.sections.first { $0.id != source && rowFrames[$0.id]?.contains(location) == true }?.id
    }

    private func sectionActions(_ section: TaskSection, at index: Int) -> some View {
        Menu {
            Button("Rename") { renaming = section.id; name = section.name; error = nil }
            if index > 0 {
                Button("Move Up") { submit(.reorder(section.id, relativeTo: list.sections[index - 1].id, after: false)) }
            }
            if index + 1 < list.sections.count {
                Button("Move Down") { submit(.reorder(section.id, relativeTo: list.sections[index + 1].id, after: true)) }
            }
            Button("Remove", role: .destructive) { removal = section }
        } label: {
            Image(systemName: "ellipsis").padding(8).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Actions for " + section.name)
    }

    private func saveName() {
        guard editable, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let operation: TaskSectionChange.Operation = renaming.map { .rename($0, name: name) } ?? .create(TaskSection(name: name))
        submit(operation, onSuccess: clearName)
    }

    private func clearName() { name = ""; renaming = nil }

    private func submit(_ operation: TaskSectionChange.Operation, onSuccess: @escaping () -> Void = {}) {
        guard editable, !saving else { return }
        error = nil
        saving = true
        Task {
            error = await save(operation)
            if error == nil { onSuccess() }
            saving = false
        }
    }
}

private struct SectionRowFrames: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct TaskSectionMoveMenu: View {
    let sections: [TaskSection]
    let current: UUID?
    let move: (UUID?) -> Void

    var body: some View {
        Menu("Move to Section") {
            Button("No Section") { move(nil) }.disabled(current == nil)
            ForEach(sections) { section in
                Button(section.name) { move(section.id) }.disabled(current == section.id)
            }
        }
    }
}
