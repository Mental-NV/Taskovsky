import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

private enum PhoneQACase: String { case known, lifecycle, captureEmpty = "capture-empty", captureTemplate = "capture-template", afterWrite = "capture-after-write", saveFailure = "save-failure", staleSave = "stale-save", unknownWorkspace = "unknown-workspace", unknownDraft = "unknown-draft" }

@MainActor
final class PhoneWorkspaceModel: ObservableObject {
    @Published private(set) var document: WorkspaceDocument?
    @Published private(set) var failure: String?
    @Published private(set) var activeDraft: TaskFieldDraft?
    @Published private(set) var recoveredDraft: TaskFieldDraft?
    @Published private(set) var protectedDraft = false
    @Published private(set) var isBusy = false
    @Published private(set) var editorError: String?
    @Published private(set) var recoveryStatus = ""
    @Published private(set) var captureDraft: TaskCaptureDraft?
    @Published private(set) var recoveredCapture: TaskCaptureDraft?
    @Published private(set) var protectedCapture = false
    @Published private(set) var captureError: String?
    @Published private(set) var captureRecoveryStatus = ""
    @Published private(set) var createdTaskID: UUID?
    @Published private(set) var creationNotice: String?
    @Published private(set) var lifecycleNotice: String?
    @Published private var lifecycleUndo: WorkspaceLifecycleUndo?
    @Published var captureIsComposing = false
    @Published var confirmCaptureDiscard = false
    @Published var captureRecoveryPrompt = false
    private var captures: CaptureDraftStore?
    private var pendingCaptureScratch: Task<Void, Never>?
    @Published var isComposing = false
    @Published var confirmDiscard = false
    @Published var recoveryPrompt = false
    private var repository: WorkspaceFileRepository?
    private var drafts: FieldDraftStore?
    private var pendingScratch: Task<Void, Never>?
    private var opened = false
    private var readTicket = UUID()
    private let qaCase: PhoneQACase
    private var injectedStale = false
    let directory: URL?
    let isQA: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TaskovskyMobile", isDirectory: true)
        let flags = arguments.indices.filter { arguments[$0] == "--qa-session" }
        let caseFlags = arguments.indices.filter { arguments[$0] == "--qa-case" }
        let chosenCase = caseFlags.first.flatMap { $0 + 1 < arguments.count ? PhoneQACase(rawValue: arguments[$0 + 1]) : nil }
        qaCase = chosenCase ?? .known
        if caseFlags.count > 1 || (!caseFlags.isEmpty && (flags.count != 1 || chosenCase == nil)) {
            directory = nil; isQA = false; return
        }
        if arguments.contains(where: { $0 == "--workspace" || $0 == "--settings" || ($0.hasPrefix("--qa-") && $0 != "--qa-session" && $0 != "--qa-case") || $0.hasPrefix("--workspace=") || $0.hasPrefix("--settings=") }) || flags.count > 1 {
            directory = nil; isQA = false
        } else if let index = flags.first {
            #if DEBUG
            if index + 1 < arguments.count, let id = UUID(uuidString: arguments[index + 1]) {
                directory = support.appendingPathComponent("QA", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
                isQA = true
            } else { directory = nil; isQA = true }
            #else
            directory = nil; isQA = false
            #endif
        } else { directory = support.appendingPathComponent("Local", isDirectory: true); isQA = false }
    }
    var now: Date { isQA ? MobilePreviewFixture.now : Date() }
    var calendar: Calendar {
        var value = document?.snapshot.settings.calendar ?? .current
        if isQA { value.timeZone = TimeZone(identifier: "Europe/Moscow")! }
        return value
    }
    var canBeginEditing: Bool {
        document?.allowsKnownFieldWrites == true && activeDraft == nil && recoveredDraft == nil && !protectedDraft && captureDraft == nil && recoveredCapture == nil && !protectedCapture && !isBusy
    }
    var staleDraft: Bool {
        guard let activeDraft, let document else { return activeDraft != nil }
        return activeDraft.baseRevision != document.revision
    }
    var canSave: Bool {
        guard let draft = activeDraft, let document else { return false }
        return document.allowsKnownFieldWrites && !isBusy && !isComposing && !staleDraft &&
            (draft.field != .title || !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    func open() async {
        guard !opened else { return }; opened = true
        guard let directory else { failure = "The requested test workspace is invalid. No local files were opened."; return }
        readTicket = UUID(); isBusy = true
        do {
            var initial = try MobilePreviewFixture.session(samples: isQA && qaCase != .captureEmpty, unknownData: qaCase == .unknownWorkspace)
            if isQA && qaCase == .captureTemplate {
                var data = initial.workspace; let source = data.tasks[0]
                data.templates = [TaskTemplate(name: "Styled project", title: "Template project", body: source.body,
                                               checklist: [.init(title: "Review the plan", isCompleted: true)], priority: .high,
                                               richBody: source.richBody, customRecurrence: CustomRecurrence(),
                                               scheduledDuration: data.tasks[1].scheduledDuration)]
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            if isQA && qaCase == .lifecycle {
                var data = initial.workspace
                guard data.tasks.count == 8, data.lists.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
                let rootID = data.tasks[0].id
                data.tasks[0].recurrence = .daily
                data.tasks[1].parentID = rootID
                data.tasks[1].listID = nil
                data.tasks[3].parentID = rootID
                data.tasks[3].completedAt = MobilePreviewFixture.now.addingTimeInterval(-7_200)
                data.tasks[4].parentID = rootID
                data.tasks[4].listID = nil
                data.tasks[4].deletedAt = MobilePreviewFixture.now.addingTimeInterval(-3_600)
                data.tasks[6].kind = .note
                data.lists[1].isArchived = true
                initial = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: initial.settingsBytes)
            }
            let wasNew = !FileManager.default.fileExists(atPath: directory.appendingPathComponent("workspace.json").path) &&
                !FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.json").path)
            let bootstrap = initial
            try await Task.detached { try WorkspaceBootstrap.prepare(directory: directory, initial: bootstrap) }.value
            let repo: WorkspaceFileRepository
            if isQA && qaCase == .saveFailure {
                repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"), write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
            } else if isQA && qaCase == .afterWrite {
                repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"), write: { bytes, url in
                    try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); throw CocoaError(.fileWriteUnknown)
                })
            } else { repo = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json")) }
            if isQA && wasNew && qaCase == .unknownDraft {
                try Data(#"{"version":99,"opaque":"Retain original"}"#.utf8).write(to: directory.appendingPathComponent("field-draft.json"), options: .atomic)
            }
            if isQA && wasNew {
                try initial.workspaceBytes.write(to: directory.appendingPathComponent("initial-workspace.json"), options: .atomic)
                try initial.settingsBytes.write(to: directory.appendingPathComponent("initial-settings.json"), options: .atomic)
            }
            repository = repo; drafts = FieldDraftStore(fileURL: directory.appendingPathComponent("field-draft.json"))
            captures = CaptureDraftStore(fileURL: directory.appendingPathComponent("capture-draft.json"))
            document = try await repo.load(); failure = nil
            await readRecovery(); await readCaptureRecovery()
            recoveryPrompt = recoveredDraft != nil
            captureRecoveryPrompt = recoveredDraft == nil && recoveredCapture != nil
        } catch { document = nil; failure = "The workspace could not be opened. Existing files have been kept. Retry when storage is available." }
        isBusy = false
    }
    func retryOpen() async { guard !isBusy else { return }; opened = false; await open() }
    func refresh() async {
        guard let repository, !isBusy else { return }
        let ticket = UUID(); readTicket = ticket
        do {
            let value = try await repository.load()
            guard ticket == readTicket, !isBusy else { return }
            document = value; failure = nil
        } catch {
            guard ticket == readTicket, !isBusy else { return }
            document = nil; failure = "The workspace could not be read. Your files and any open edit have been kept."
        }
    }

    func saveSchedule(_ edit: TaskScheduleEdit, expected: WorkspaceRevision) async -> String? {
        guard canBeginEditing, let repository else { return "Editing is currently unavailable." }
        readTicket = UUID()
        isBusy = true
        defer { isBusy = false }
        switch await repository.apply(edit, expected: expected, now: now) {
        case .saved(let saved), .unchanged(let saved):
            document = saved
            return nil
        case .refused(.stale), .refused(.invalid(.changedTask)):
            if let latest = try? await repository.load() { document = latest }
            return "The workspace changed. Reopen Schedule to edit the current task."
        case .refused(.compatibility):
            return "This workspace contains data this build cannot safely rewrite."
        case .refused(.invalid(.invalidDuration)):
            return "The end must be on or after the start."
        case .refused(.invalid(.invalidTimeZone)):
            return "Choose a supported time zone."
        case .refused(.invalid(.invalidRepeat)):
            return "Edit or explicitly replace the invalid repeat rule."
        case .refused(.missing), .refused(.readOnlyRecord):
            return "Scheduling is unavailable for this task."
        case .persistenceFailed:
            return "Could not confirm the save. Your edits are still here."
        }
    }

    var canUndoLifecycle: Bool {
        canBeginEditing && lifecycleUndo?.revision == document?.revision && lifecycleUndo != nil
    }

    @discardableResult
    func performLifecycle(_ command: TaskLifecycleCommand, taskID: UUID,
                          expected: WorkspaceRevision) async -> Bool {
        guard canBeginEditing, let repository else { return false }
        readTicket = UUID()
        isBusy = true
        let outcome = await repository.apply(command, to: taskID, expected: expected, calendar: calendar)
        let message: String = switch command {
        case .complete: "Task completed"
        case .reopen: "Task reopened"
        case .wontDo: "Marked Won't Do"
        case .trash: "Moved to Trash"
        case .restore: "Restored"
        case .purge: "Deleted forever"
        case .setPinned(let pinned): pinned ? "Pinned" : "Unpinned"
        case .move: "Moved to list"
        }
        return await finishLifecycle(outcome, message: message)
    }

    func undoLifecycle() async {
        guard canUndoLifecycle, let repository, let lifecycleUndo else { return }
        readTicket = UUID()
        isBusy = true
        let outcome = await repository.undo(lifecycleUndo)
        _ = await finishLifecycle(outcome, message: "Change undone")
    }

    private func finishLifecycle(_ outcome: WorkspaceLifecycleOutcome, message: String) async -> Bool {
        defer { isBusy = false }
        switch outcome {
        case .saved(let saved, let undo):
            document = saved
            creationNotice = nil
            lifecycleUndo = undo
            lifecycleNotice = message
            return true
        case .unchanged(let current):
            document = current
            return true
        case .refused(.stale):
            lifecycleUndo = nil
            lifecycleNotice = "The workspace changed. Review the current task and try again."
            if let repository, let latest = try? await repository.load() { document = latest }
        case .refused(.compatibility):
            lifecycleNotice = "This workspace contains data this build cannot safely rewrite."
        case .refused(.task(.invalidDestination)):
            lifecycleNotice = "Choose Inbox or an active list."
        case .refused(.task):
            lifecycleNotice = "This action is unavailable for the current task."
        case .persistenceFailed:
            lifecycleNotice = "Could not confirm the change. Review the workspace before retrying."
            if let repository, let latest = try? await repository.load() { document = latest }
        }
        return false
    }
    func begin(taskID: UUID, field: TaskDraftField) async {
        guard canBeginEditing, let document, let drafts,
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == taskID }),
              task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: document.snapshot.workspace.lists),
              field != .plainBody || task.richBody == nil else { return }
        readTicket = UUID(); isBusy = true; editorError = nil; isComposing = false
        let draft = TaskFieldDraft(taskID: taskID, field: field, baseRevision: document.revision,
                                   text: field == .title ? task.title : task.body)
        let result = await drafts.begin(draft)
        if result == .refused {
            await readRecovery(); editorError = "An existing saved edit must be handled before starting another."
        } else {
            activeDraft = draft
            recoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your edit is still open."
        }
        isBusy = false
    }
    func changeText(_ text: String, editorID: UUID) {
        guard !isBusy, var draft = activeDraft, draft.id == editorID else { return }
        guard !text.utf16.elementsEqual(draft.text.utf16) else { return }
        draft.replaceText(text); activeDraft = draft; recoveryStatus = "Saving recovery copy…"
        pendingScratch?.cancel()
        pendingScratch = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.flushDraft()
        }
    }
    func flushDraft() async {
        guard let draft = activeDraft, let drafts else { return }
        let result = await drafts.save(draft)
        guard activeDraft?.id == draft.id, activeDraft?.sequence == draft.sequence else { return }
        recoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your edit is still open."
    }
    func requestCloseEditor() {
        guard let draft = activeDraft, !isBusy else { return }
        if draft.hasChanges { confirmDiscard = true }
        else { Task { await discardActive() } }
    }
    func discardActive() async {
        guard let draft = activeDraft, let drafts, !isBusy else { return }
        readTicket = UUID(); isBusy = true; pendingScratch?.cancel()
        let result = await drafts.close(id: draft.id)
        if result == .saved { activeDraft = nil; editorError = nil; recoveryStatus = ""; isComposing = false }
        else { editorError = "The saved edit could not be discarded. Your text has been kept. Try again." }
        isBusy = false
        await refresh()
    }
    func save() async {
        guard canSave, let draft = activeDraft, let repository, let drafts else { return }
        readTicket = UUID(); isBusy = true; pendingScratch?.cancel(); editorError = nil
        _ = await drafts.save(draft)
        let patch: WorkspaceFieldPatch = draft.field == .title ? .title(draft.text) : .plainBody(draft.text)
        if isQA && qaCase == .staleSave && !injectedStale, let directory {
            injectedStale = true
            let independent = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"))
            if let latest = try? await independent.load() { _ = await independent.apply(.title("Changed elsewhere"), to: draft.taskID, expected: latest.revision) }
        }
        let outcome = await repository.apply(patch, to: draft.taskID, expected: draft.baseRevision)
        switch outcome {
        case .saved(let value), .unchanged(let value):
            document = value
            let cleanup = await drafts.close(id: draft.id)
            activeDraft = nil; isComposing = false; recoveryStatus = ""
            if cleanup != .saved { await readRecovery(); editorError = "Changes saved, but the recovery copy could not be cleared." }
        case .refused(.stale):
            editorError = "This task changed. Your text is kept. Discard to reload, or keep editing to copy it."
            do { document = try await repository.load() } catch { }
        case .refused(.compatibility): editorError = "This workspace contains data this build cannot safely rewrite. Your edit is kept."
        case .refused(.styledBody): editorError = "Formatting is protected. The description cannot be replaced with plain text."
        case .refused(.readOnlyRecord), .refused(.missing): editorError = "This task is no longer editable. Your text is kept."
        case .refused(.emptyTitle): editorError = "Enter a title before saving."
        case .persistenceFailed: editorError = "Could not save. Your edit is still here. Retry when storage is available."
        }
        isBusy = false
    }
    func resumeRecovery() {
        guard let recoveredDraft, !isBusy else { return }
        activeDraft = recoveredDraft; self.recoveredDraft = nil; editorError = nil; isComposing = false
        recoveryStatus = "Recovery copy saved"
    }
    func discardRecovery() async {
        guard let recoveredDraft, let drafts, !isBusy else { return }
        readTicket = UUID(); isBusy = true
        let result = await drafts.close(id: recoveredDraft.id)
        if result == .saved { self.recoveredDraft = nil; editorError = nil }
        else { editorError = "The saved edit could not be discarded. It has been kept." }
        isBusy = false
    }
    private func readRecovery() async {
        guard let drafts else { return }
        switch await drafts.load() {
        case .none: recoveredDraft = nil; protectedDraft = false
        case .available(let value): recoveredDraft = activeDraft?.id == value.id ? nil : value; protectedDraft = false
        case .unavailable: recoveredDraft = nil; protectedDraft = true
        }
    }
    var canBeginCapture: Bool { canBeginEditing }
    var staleCapture: Bool { guard let draft = captureDraft, let document else { return captureDraft != nil }; return draft.baseRevision != document.revision }
    var capturePreview: TaskItem? {
        guard let draft = captureDraft, let document else { return nil }
        return draft.preparedTask ?? (try? draft.input.task(id: draft.id, now: draft.createdAt, workspace: document.snapshot.workspace, settings: document.snapshot.settings, calendar: draft.calendar, requireTitle: false))
    }
    var canCreate: Bool {
        captureDraft != nil && document?.allowsKnownFieldWrites == true && !isBusy && !captureIsComposing &&
            (captureDraft?.preparedTask != nil || (!staleCapture && capturePreview?.title.isEmpty == false))
    }
    func beginCapture(destination: TaskDestination, calendarDate: Date?) async {
        guard canBeginCapture, let document, let captures else { return }
        readTicket = UUID(); isBusy = true; captureError = nil; creationNotice = nil; createdTaskID = nil; captureIsComposing = false
        let input = TaskCaptureInput.start(destination: destination, calendarDate: calendarDate, workspace: document.snapshot.workspace,
                                           settings: document.snapshot.settings, now: now, calendar: calendar)
        let value = TaskCaptureDraft(baseRevision: document.revision, input: input, now: now, calendar: calendar)
        let result = await captures.begin(value)
        if result == .refused { await readCaptureRecovery(); captureError = "Handle the existing saved capture before creating another." }
        else { captureDraft = value; captureRecoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open." }
        isBusy = false
    }
    func changeCapture(id: UUID, _ change: (inout TaskCaptureInput) -> Void) {
        guard !isBusy, var value = captureDraft, value.id == id, value.preparedTask == nil else { return }
        let before = value.sequence; value.update(change)
        guard before != value.sequence else { return }
        captureDraft = value; captureRecoveryStatus = "Saving recovery copy…"; pendingCaptureScratch?.cancel()
        pendingCaptureScratch = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }; await self?.flushCapture()
        }
    }
    func flushCapture() async {
        guard let value = captureDraft, let captures else { return }
        let result = await captures.save(value)
        guard captureDraft?.id == value.id, captureDraft?.sequence == value.sequence else { return }
        captureRecoveryStatus = result == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open."
    }
    func requestCloseCapture() {
        guard let value = captureDraft, !isBusy else { return }
        if value.hasChanges { confirmCaptureDiscard = true } else { Task { await discardCapture() } }
    }
    func discardCapture() async {
        guard let value = captureDraft, let captures, !isBusy else { return }
        readTicket = UUID(); isBusy = true; pendingCaptureScratch?.cancel()
        if await captures.close(id: value.id) == .saved { captureDraft = nil; captureError = nil; captureRecoveryStatus = ""; captureIsComposing = false }
        else { captureError = "The saved capture could not be discarded. Your draft is kept. Try again." }
        isBusy = false; await refresh()
    }
    func createCapturedTask() async {
        guard canCreate, var value = captureDraft, let document, let captures, let repository else { return }
        readTicket = UUID(); isBusy = true; pendingCaptureScratch?.cancel(); captureError = nil
        let wasPrepared = value.preparedTask != nil
        do { try value.prepare(workspace: document.snapshot.workspace, settings: document.snapshot.settings) }
        catch { captureError = "Check the title, destination, tags and template before saving."; isBusy = false; return }
        captureDraft = value
        let durable: Bool
        if case .available(let saved) = await captures.load(), saved == value { durable = true }
        else { durable = await captures.save(value) == .saved }
        guard durable else {
            if !wasPrepared { value.confirmedNotSaved(); captureDraft = value }
            captureRecoveryStatus = "Recovery copy could not be saved. Your draft is still open."
            captureError = wasPrepared ? "The prior save still needs checking. Your submitted draft is kept." : "The recovery copy could not be saved. No task was submitted. Your draft is kept."
            isBusy = false; return
        }
        captureRecoveryStatus = "Recovery copy saved"
        if isQA && qaCase == .staleSave && !injectedStale, let directory {
            injectedStale = true
            let independent = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"), settingsURL: directory.appendingPathComponent("settings.json"))
            if let latest = try? await independent.load(), let task = latest.snapshot.workspace.tasks.first {
                _ = await independent.apply(.title("Changed elsewhere"), to: task.id, expected: latest.revision)
            }
        }
        switch await repository.create(value) {
        case .created(let saved, let id), .alreadyCreated(let saved, let id):
            self.document = saved
            let cleanup = await captures.close(id: value.id)
            captureDraft = nil; captureRecoveryStatus = ""; captureIsComposing = false
            createdTaskID = id; creationNotice = saved.snapshot.workspace.tasks.first(where: { $0.id == id })?.kind == .note ? "Note added" : "Task added"
            if cleanup != .saved { await readCaptureRecovery(); captureError = "Saved, but the recovery copy could not be cleared." }
        case .notSaved(let latest):
            self.document = latest; value.confirmedNotSaved(); captureDraft = value
            let stored = await captures.save(value)
            captureRecoveryStatus = stored == .saved ? "Recovery copy saved" : "Recovery copy could not be saved. Your draft is still open."
            captureError = "Could not save. Your draft is kept. Retry or keep editing."
        case .uncertain:
            captureError = "The save could not be confirmed. Your draft is kept. Retry checks the same task before creating anything."
        case .refused(let reason):
            switch reason {
            case .stale: captureError = "The workspace changed. Your draft is kept. Discard to reload; it has not been applied to the changed workspace."
            case .compatibility: captureError = "This workspace contains data this build cannot safely rewrite. Your draft is kept."
            case .commandConflict: captureError = "This capture ID already belongs to a changed task. Your draft is kept; no duplicate was created."
            case .invalidCapture, .validation: captureError = "The destination, tags or template are no longer safe to use. Your draft is kept."
            }
            if let latest = try? await repository.load() { self.document = latest }
        }
        isBusy = false
    }
    func resumeCaptureRecovery() {
        guard let recoveredCapture, !isBusy else { return }
        captureDraft = recoveredCapture; self.recoveredCapture = nil; captureError = nil; captureIsComposing = false
        captureRecoveryStatus = "Recovery copy saved"; createdTaskID = nil
    }
    func discardCaptureRecovery() async {
        guard let value = recoveredCapture, let captures, !isBusy else { return }
        readTicket = UUID(); isBusy = true
        if await captures.close(id: value.id) == .saved { recoveredCapture = nil; captureError = nil }
        else { captureError = "The saved capture could not be discarded. It has been kept." }
        isBusy = false
    }
    private func readCaptureRecovery() async {
        guard let captures else { return }
        switch await captures.load() {
        case .none: recoveredCapture = nil; protectedCapture = false
        case .available(let value): recoveredCapture = captureDraft?.id == value.id ? nil : value; protectedCapture = false
        case .unavailable: recoveredCapture = nil; protectedCapture = true
        }
    }

}
