import SwiftUI
import AppKit
import TaskovskyCore

struct QuickEntry: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: TaskStore
    @Binding var title: String
    @Binding var kind: TaskKind
    @Binding var focused: Bool
    var onTemplate: () -> Void
    var onSubmit: (String, Bool) -> Void
    @State private var description = ""
    @State private var showDescription = false
    @State private var ignoreDate = false
    @State private var suggestionsDismissed = false
    @FocusState private var descriptionFocused: Bool

    private var recognized: (date: Date, hasTime: Bool, range: Range<String.Index>)? {
        guard store.settings.dateRecognition, !ignoreDate else { return nil }
        return TaskStore.recognizeDate(in: title, calendar: store.settings.calendar)
    }
    private var tagQuery: String? {
        guard !suggestionsDismissed, let token = title.split(separator: " ", omittingEmptySubsequences: false).last, token.hasPrefix("#") else { return nil }
        return String(token.dropFirst())
    }
    private var tagMatches: [TaskTag] { guard let tagQuery else { return [] }; return store.data.tags.filter { tagQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(tagQuery) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Menu {
                    Button("Task") { kind = .task }; Button("Note") { kind = .note }
                    Divider(); Button("Add from Template…", action: onTemplate)
                } label: { HoverIcon { Image(systemName: kind == .task ? "plus" : "doc.text").font(.system(size: 16)).foregroundStyle(.secondary).padding(4) } }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("Choose task, note, or template")
                RecognizingField(text: $title, isFocused: Binding(get: { focused }, set: { focused = $0 }), placeholder: kind == .task ? "Add task" : "Add note", dateRange: recognized.map { NSRange($0.range, in: title) }, onSubmit: submit, onDescription: { showDescription = true; focused = false; descriptionFocused = true })
                    .frame(minWidth: 60, minHeight: 22)
                if let recognized {
                    Menu {
                        Text(recognized.date.formatted(date: .complete, time: recognized.hasTime ? .shortened : .omitted))
                        Button("Ignore recognized date") { ignoreDate = true }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                            Text(recognized.date.formatted(.dateTime.month(.abbreviated).day()) + (recognized.hasTime ? " " + recognized.date.formatted(date: .omitted, time: .shortened) : ""))
                        }.font(.system(size: 12)).foregroundStyle(accent).fixedSize()
                    }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Recognized date; click to ignore")
                }
            }.padding(.horizontal, 12).frame(height: 38)
                .background(Palette.card(colorScheme), in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).stroke(focused ? accent : .clear, lineWidth: 1) }
            if showDescription {
                TextField("Description", text: $description, axis: .vertical).textFieldStyle(.plain).font(.system(size: 14)).lineLimit(2...5).focused($descriptionFocused).padding(10).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
                HStack { Spacer(); Button("Add", action: submit).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.font(.system(size: 12))
            } else if focused && !title.isEmpty {
                Text("⇧↩ Add description").font(.system(size: 10)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .overlay(alignment: .topLeading) {
            if focused, let tagQuery {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tagMatches.prefix(5)) { tag in
                        Button { chooseTag(tag.name) } label: { Label(String(repeating: "  ", count: TagHierarchy.ancestors(of: tag.id, in: store.data.tags).count) + tag.name, systemImage: "tag").foregroundStyle(Color(hex: tag.color)).frame(maxWidth: .infinity, alignment: .leading).padding(7) }.buttonStyle(.plain)
                    }
                    if !tagQuery.isEmpty && !store.data.tags.contains(where: { $0.name.localizedCaseInsensitiveCompare(tagQuery) == .orderedSame }) {
                        Button { chooseTag(tagQuery) } label: { Text("Create tag \"\(tagQuery)\"").frame(maxWidth: .infinity, alignment: .leading).padding(7) }.buttonStyle(.plain)
                    }
                }.font(.system(size: 13)).padding(4).frame(maxWidth: 260).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).shadow(color: .black.opacity(0.12), radius: 8, y: 3).offset(y: 44)
            }
        }.zIndex(10)
        .onChange(of: title) { _, value in suggestionsDismissed = false; if value.isEmpty { ignoreDate = false; description = ""; showDescription = false } }
    }
    private func chooseTag(_ name: String) {
        guard let start = title.range(of: "#", options: .backwards)?.lowerBound else { return }
        let token = name.contains(where: { $0.isWhitespace }) ? "#\"" + name + "\" " : "#" + name + " "
        title.replaceSubrange(start..., with: token); suggestionsDismissed = true; focused = true
    }
    private func submit() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSubmit(description, !ignoreDate); description = ""; showDescription = false; ignoreDate = false
    }
}

/// NSTextField keeps the date highlight in the field editor without changing its
/// text or selection. The task itself remains plain text.
private struct RecognizingField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var dateRange: NSRange?
    var onSubmit: () -> Void
    var onDescription: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(); field.isBordered = false; field.drawsBackground = false
        field.font = .systemFont(ofSize: 14); field.focusRingType = .none; field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail; field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self; field.placeholderString = placeholder
        if field.stringValue != text { field.stringValue = text }
        field.setAccessibilityLabel(placeholder)
        context.coordinator.highlight(field)
        if isFocused && field.currentEditor() == nil {
            DispatchQueue.main.async { if self.isFocused { field.window?.makeFirstResponder(field) } }
        }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RecognizingField
        init(_ parent: RecognizingField) { self.parent = parent }
        func controlTextDidBeginEditing(_ obj: Notification) { parent.isFocused = true }
        func controlTextDidEndEditing(_ obj: Notification) { parent.isFocused = false }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }; parent.text = field.stringValue
        }
        func highlight(_ field: NSTextField) {
            guard let editor = field.currentEditor() as? NSTextView, let storage = editor.textStorage else { return }
            let selection = editor.selectedRanges
            storage.setAttributes([.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor], range: NSRange(location: 0, length: storage.length))
            if let range = parent.dateRange, NSMaxRange(range) <= storage.length { storage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range) }
            editor.selectedRanges = selection
            editor.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { parent.onDescription() } else { parent.onSubmit() }; return true
            }
            return false
        }
    }
}
