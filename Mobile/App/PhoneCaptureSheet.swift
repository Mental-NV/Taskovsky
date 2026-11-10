import SwiftUI
import UIKit
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneCaptureSheet: View {
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var focusRequest: UUID?
    private func input<T>(_ key: WritableKeyPath<TaskCaptureInput, T>, fallback: T) -> Binding<T> {
        let id = model.captureDraft?.id
        return Binding(get: { model.captureDraft?.id == id ? model.captureDraft?.input[keyPath: key] ?? fallback : fallback }, set: { next in
            if let id { model.changeCapture(id: id) { $0[keyPath: key] = next } }
        })
    }
    private func composing(_ id: UUID) -> Binding<Bool> {
        Binding(get: { model.captureDraft?.id == id && model.captureIsComposing }, set: {
            if model.captureDraft?.id == id { model.captureIsComposing = $0 }
        })
    }
    private func calendarRangeFields(_ range: TaskDurationRange, draft: TaskCaptureDraft) -> some View {
        func choose(_ start: Date, _ end: Date) {
            let first = draft.calendar.startOfDay(for: start)
            let last = draft.calendar.startOfDay(for: end)
            guard first <= last else { return }
            model.changeCapture(id: draft.id) { $0.chooseCalendarRange(first...last, calendar: draft.calendar) }
        }
        return Group {
            DatePicker("Start", selection: Binding(get: { range.start }, set: { choose($0, range.end) }),
                       in: ...range.end, displayedComponents: .date)
                .accessibilityIdentifier("captureCalendarRangeStart")
            DatePicker("End", selection: Binding(get: { range.end }, set: { choose(range.start, $0) }),
                       in: range.start..., displayedComponents: .date)
                .accessibilityIdentifier("captureCalendarRangeEnd")
            Button("Use end date only") { model.changeCapture(id: draft.id) { $0.useCalendarRangeEndOnly() } }
        }
    }
    private func chooseDate(_ date: Date?, timed: Bool) {
        if let draft = model.captureDraft { model.changeCapture(id: draft.id) { $0.chooseDate(date.map { timed ? $0 : draft.calendar.startOfDay(for: $0) }, hasTime: timed) } }
    }
    var body: some View {
        NavigationStack {
            if let draft = model.captureDraft, let document = model.document {
                let frozen = draft.preparedTask != nil
                let preview = model.capturePreview
                let tagNames = (preview?.tagIDs ?? draft.input.tagIDs).compactMap { id in document.snapshot.workspace.tags.first { $0.id == id }?.name }
                Form {
                    Section {
                        if let error = model.captureError {
                            Text(error).foregroundStyle(.red).accessibilityIdentifier("captureError")
                            if !frozen && !model.isBusy {
                                Button("Keep Editing") { focusRequest = UUID() }.accessibilityIdentifier("continueCaptureTyping")
                            }
                        }
                        if model.staleCapture { Text("This capture is based on an older workspace. Your text is kept.").foregroundStyle(.orange) }
                        if frozen { Text("Retry checks this same task. Its submitted contents are protected until the outcome is known.").font(.footnote) }
                        Text(model.captureRecoveryStatus).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("captureRecoveryStatus")
                    }
                    Section {
                        Picker("Kind", selection: input(\.kind, fallback: .task)) {
                            Text("Task").tag(TaskKind.task); Text("Note").tag(TaskKind.note)
                        }.pickerStyle(.segmented)
                        NativeFieldInput(text: input(\.title, fallback: ""), composing: composing(draft.id),
                                         editorID: draft.id, title: true, editable: !frozen && !model.isBusy,
                                         accessibilityID: "captureTitle", focusRequest: focusRequest)
                            .id(draft.id).frame(minHeight: 60, alignment: .topLeading)
                            .overlay(alignment: .topLeading) {
                                if draft.input.title.isEmpty { Text("Title").font(.title2).foregroundStyle(.tertiary).allowsHitTesting(false).accessibilityHidden(true) }
                            }
                        if draft.input.protectsBody {
                            if let rich = draft.input.template?.richBody,
                               let preview = RichDescriptionPreview(body: draft.input.body, rich: rich), !rich.isEmpty {
                                PhoneRichDescription(preview: preview, identifier: "captureRichDescription")
                            } else {
                                Text(draft.input.body).textSelection(.enabled)
                            }
                            Text("Template formatting is preserved. This description is read-only.").font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("captureProtectedBody")
                        } else {
                            NativeFieldInput(text: input(\.body, fallback: ""), composing: composing(draft.id),
                                             editorID: draft.id, title: false, editable: !frozen && !model.isBusy,
                                             focusOnAppear: false, accessibilityID: "captureDescription")
                                .frame(minHeight: 100, alignment: .topLeading)
                                .overlay(alignment: .topLeading) {
                                    if draft.input.body.isEmpty { Text("Optional description").foregroundStyle(.tertiary).allowsHitTesting(false).accessibilityHidden(true) }
                                }
                        }
                    }.disabled(frozen || model.isBusy)
                    Section("Destination") {
                        Picker("List", selection: input(\.listID, fallback: nil)) {
                            Text("Inbox").tag(UUID?.none)
                            ForEach(document.snapshot.workspace.lists.filter { !$0.isArchived }) { list in Text(list.name).tag(Optional(list.id)) }
                        }.pickerStyle(.navigationLink).accessibilityIdentifier("captureListPicker")
                        if let list = document.snapshot.workspace.lists.first(where: { $0.id == draft.input.listID }),
                           !list.sections.isEmpty {
                            Picker("Section", selection: input(\.sectionID, fallback: nil)) {
                                Text("No Section").tag(UUID?.none)
                                ForEach(list.sections) { section in Text(section.name).tag(Optional(section.id)) }
                            }.pickerStyle(.navigationLink).accessibilityIdentifier("captureSectionPicker")
                        }
                        Picker("Priority", selection: input(\.priority, fallback: .none)) {
                            ForEach(TaskPriority.allCases, id: \.self) { value in Text(value.rawValue.capitalized).tag(value) }
                        }.pickerStyle(.navigationLink).accessibilityIdentifier("capturePriorityPicker")
                        NavigationLink { CaptureTags(model: model) } label: {
                            HStack { Text("Tags"); Spacer(); Text(tagNames.isEmpty ? "None" : tagNames.joined(separator: ", ")).lineLimit(2).foregroundStyle(.secondary) }
                        }.accessibilityIdentifier("captureTagsPicker")
                    }.disabled(frozen || model.isBusy)
                    Section("Date") {
                        Text(preview?.dueDate.map { $0.formatted(Date.FormatStyle(date: .abbreviated, time: preview?.hasDueTime == true ? .shortened : .omitted, calendar: draft.calendar, timeZone: draft.calendar.timeZone)) } ?? "No date")
                            .accessibilityIdentifier("captureResolvedDate")
                        Toggle("Set a date", isOn: Binding(get: { preview?.dueDate != nil }, set: { enabled in
                            chooseDate(enabled ? model.calendar.startOfDay(for: model.now) : nil, timed: false)
                        })).accessibilityIdentifier("captureDateToggle")
                        if let range = draft.input.calendarRange {
                            calendarRangeFields(range, draft: draft)
                        } else if let date = preview?.dueDate {
                            DatePicker("Date", selection: Binding(get: { model.capturePreview?.dueDate ?? date }, set: { chooseDate($0, timed: model.capturePreview?.hasDueTime == true) }), displayedComponents: .date)
                            let hasTemplateWindow = draft.input.template?.scheduledDuration != nil && draft.input.preserveTemplateDuration
                            Toggle("Time", isOn: Binding(get: { model.capturePreview?.hasDueTime ?? false }, set: { chooseDate(date, timed: $0) }))
                                .disabled(hasTemplateWindow)
                            if preview?.hasDueTime == true && !hasTemplateWindow {
                                DatePicker("Time", selection: Binding(get: { model.capturePreview?.dueDate ?? date }, set: { chooseDate($0, timed: true) }), displayedComponents: .hourAndMinute)
                            }
                            if hasTemplateWindow { Text("The template duration is retained and follows this end date. Choose No date to clear it.").font(.footnote).foregroundStyle(.secondary) }
                            Button("No date") { chooseDate(nil, timed: false) }
                        }
                    }.disabled(frozen || model.isBusy)
                    if draft.input.template == nil {
                        recognition(draft, document: document, preview: preview).disabled(frozen || model.isBusy)
                    }
                    if !document.snapshot.workspace.templates.isEmpty {
                        Section {
                            NavigationLink("Use template") { CaptureTemplates(model: model) }.accessibilityIdentifier("captureTemplatePicker")
                        }.disabled(frozen || model.isBusy)
                    }
                    if preview == nil && !draft.input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Check the destination, tags, schedule and template. Unsupported content is preserved, so this capture cannot be submitted yet.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.environment(\.calendar, draft.calendar).environment(\.timeZone, draft.calendar.timeZone)
                    .scrollDismissesKeyboard(.immediately).navigationTitle("New \(draft.input.kind.rawValue)").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.requestCloseCapture() }.disabled(model.isBusy).accessibilityIdentifier("captureCancel") }
                        ToolbarItem(placement: .confirmationAction) { Button(model.isBusy ? "Saving…" : frozen || model.captureError != nil ? "Retry" : "Add") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            Task { await model.createCapturedTask() }
                        }.disabled(!model.canCreate).accessibilityIdentifier("captureAdd") }
                    }
            }
        }.interactiveDismissDisabled(model.captureDraft?.hasChanges == true || model.isBusy)
            .alert("Discard this capture?", isPresented: $model.confirmCaptureDiscard) {
                Button("Discard", role: .destructive) { Task { await model.discardCapture() } }
                Button("Keep Editing", role: .cancel) { }
            }
    }
    private func recognition(_ draft: TaskCaptureDraft, document: WorkspaceDocument, preview: TaskItem?) -> some View {
        let rawTitle = draft.input.title
        let datePhrase: String? = {
            guard draft.input.calendarRange == nil, draft.input.recognizeDates, document.snapshot.settings.dateRecognition,
                  let matched = TaskCreation.recognizeDate(in: rawTitle, calendar: draft.calendar, now: draft.createdAt) else { return nil }
            return String(rawTitle[matched.range])
        }()
        let tags: [TaskTag] = draft.input.recognizeTags ? TaskCreation.existingTagCandidates(in: rawTitle, tags: document.snapshot.workspace.tags)
            .filter { !draft.input.ignoredRecognizedTagIDs.contains($0.id) } : []
        return Section("Recognition") {
            if draft.input.calendarRange == nil {
                Toggle("Recognize date text", isOn: input(\.recognizeDates, fallback: true))
            }
            Toggle("Recognize existing tags", isOn: input(\.recognizeTags, fallback: true))
            if let datePhrase {
                Button("Ignore date suggestion: \(datePhrase)") { model.changeCapture(id: draft.id) { $0.recognizeDates = false } }
                    .accessibilityIdentifier("ignoreCaptureDate")
            }
            ForEach(tags) { tag in
                Button("Ignore \(tag.name) suggestion") { model.changeCapture(id: draft.id) { $0.ignoredRecognizedTagIDs.append(tag.id) } }
            }
            if draft.input.recognizeTags && !draft.input.ignoredRecognizedTagIDs.isEmpty {
                Button("Restore tag suggestions") { model.changeCapture(id: draft.id) { $0.ignoredRecognizedTagIDs = [] } }
            }
            if let preview, !preview.title.isEmpty, !preview.title.utf16.elementsEqual(rawTitle.utf16) {
                Text("Saved title: \(preview.title)").font(.footnote)
            }
            Text("Unknown #tags stay in the title. Only existing tags are used.").font(.footnote).foregroundStyle(.secondary)
        }
    }

}

private struct CaptureTags: View {
    @ObservedObject var model: PhoneWorkspaceModel
    var body: some View {
        List(model.document?.snapshot.workspace.tags ?? []) { tag in
            Button {
                if let draft = model.captureDraft { model.changeCapture(id: draft.id) { input in
                    if input.tagIDs.contains(tag.id) { input.tagIDs.removeAll { $0 == tag.id } } else { input.tagIDs.append(tag.id) }
                } }
            } label: {
                HStack { Text(tag.name); Spacer(); if model.captureDraft?.input.tagIDs.contains(tag.id) == true { Image(systemName: "checkmark") } }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(model.captureDraft?.input.tagIDs.contains(tag.id) == true ? "Selected" : "Not selected")
        }.navigationTitle("Tags")
    }
}
private struct CaptureTemplates: View {
    @ObservedObject var model: PhoneWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: TaskTemplate?
    @State private var confirm = false
    private func apply(_ seed: TaskTemplate) {
        if let id = model.captureDraft?.id { model.changeCapture(id: id) { $0.applyTemplate(seed) } }; dismiss()
    }
    var body: some View {
        List(model.document?.snapshot.workspace.templates ?? []) { seed in
            Button(seed.name) {
                if model.captureDraft?.hasChanges == true { selected = seed; confirm = true } else { apply(seed) }
            }.frame(minHeight: 44)
        }.navigationTitle("Templates")
            .alert("Replace this capture?", isPresented: $confirm) {
                Button("Use template") { if let selected { apply(selected) } }
                Button("Keep Editing", role: .cancel) { }
            } message: { Text("The template replaces the draft content. Your workspace is unchanged until Add.") }
    }
}
