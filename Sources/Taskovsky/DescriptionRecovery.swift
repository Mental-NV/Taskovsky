import SwiftUI
import AppKit
import TaskovskyCore
import TaskovskyWorkspace

/// Application-scoped lifecycle protection. No notification or OS permission work.
@MainActor enum DescriptionEditorLifecycle {
    static weak var session: MacDescriptionSession?
    private static var captures: [UUID: () -> Void] = [:]
    private static var panel: NSPanel?
    private static var terminating = false
    static func register(_ id: UUID, capture: @escaping () -> Void) { captures[id] = capture }
    static func unregister(_ id: UUID) { captures.removeValue(forKey: id) }
    static func captureEditors() { for capture in Array(captures.values) { capture() } }
    static func showRecovery() {
        guard let session else { return }
        if panel == nil {
            let value = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            value.title = "Description Recovery"
            value.isReleasedWhenClosed = false
            value.contentView = NSHostingView(rootView: DescriptionRecoveryView(session: session))
            value.center(); panel = value
        }
        panel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    static func requestTermination() -> NSApplication.TerminateReply {
        guard let session else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true; captureEditors()
        Task { @MainActor in
            await session.finishPending()
            // A successfully journaled draft can survive termination. Conflicts,
            // marked text and newer unjournaled generations cannot.
            var quit = true
            if session.hasUnsafeMemory {
                let alert = NSAlert()
                alert.messageText = "Some description text is only in memory"
                alert.informativeText = "Keep Taskovsky open to finish typing, retry, or copy the text in Description Recovery. Quitting now loses unsaved text that could not be written to recovery."
                alert.addButton(withTitle: "Keep Open")
                alert.addButton(withTitle: "Quit Without Unsaved Text")
                quit = alert.runModal() == .alertSecondButtonReturn
                if !quit { showRecovery() }
            }
            terminating = false
            NSApp.reply(toApplicationShouldTerminate: quit)
        }
        return .terminateLater
    }
}

struct DescriptionRecoveryView: View {
    @ObservedObject var session: MacDescriptionSession
    @State private var discardTask: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Description Recovery").font(.title2)
                Text("Saved drafts are separate from task data. Copy text or its JSON representation before discarding anything you need.").foregroundStyle(.secondary)
                if let error = session.discoveryError { Text(error).foregroundStyle(.red) }
                ForEach(session.recoveryErrors.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { id in
                    Text(session.recoveryErrors[id] ?? "Recovery unavailable").foregroundStyle(.red)
                }
                ForEach(session.compositionSnapshots.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { editor in
                    if let content = session.compositionSnapshots[editor] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("An editor has unfinished input-method text. Return to that editor to finish it; this copy is memory-only.")
                            snapshot(content)
                        }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                ForEach(session.taskIDs, id: \.self) { id in
                    if let view = session.presentation(taskID: id), view.message != nil || view.recovery != nil || !view.conflicts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task " + id.uuidString).font(.caption).textSelection(.enabled)
                            if let message = view.message { Text(message) }
                            if let recovery = session.recoveryContent(taskID: id) {
                                snapshot(recovery)
                                HStack {
                                    if view.recovery == .retryEligible { Button("Resume Draft") { session.resume(taskID: id) } }
                                    Button("Discard Recovery…") { discardTask = id }
                                }
                            } else if view.conflicts.isEmpty {
                                snapshot(view.content)
                                Button("Retry Save") { session.retry(taskID: id) }
                            }
                            ForEach(view.conflicts.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { editor in
                                if let content = view.conflicts[editor] {
                                    snapshot(content)
                                    Button("Discard This Local Conflict") { session.discardConflict(taskID: id, editorID: editor) }
                                }
                            }
                        }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Button("Check Recovery Files Again") { Task { await session.discoverRecovery() } }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Discard this saved recovery draft?", isPresented: Binding(get: { discardTask != nil }, set: { if !$0 { discardTask = nil } })) {
            Button("Cancel", role: .cancel) { discardTask = nil }
            Button("Discard Recovery", role: .destructive) {
                if let id = discardTask { Task { await session.keepSaved(taskID: id) } }
                discardTask = nil
            }
        } message: { Text("The task's current saved description is kept. The separate recovery copy will be removed only if it is still the reviewed draft.") }
    }
    @ViewBuilder private func snapshot(_ content: DescriptionSnapshot) -> some View {
        Text(content.body.isEmpty ? "(Empty description)" : content.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        HStack {
            Button("Copy Text") { copy(content.body) }
            Button("Copy Text and Formatting as JSON") {
                if let bytes = try? JSONEncoder().encode(content), let value = String(data: bytes, encoding: .utf8) { copy(value) }
            }
        }
    }
    private func copy(_ value: String) {
        let board = RichBodyTextView.descriptionClipboard
        board.clearContents(); board.setString(value, forType: .string)
    }
}
