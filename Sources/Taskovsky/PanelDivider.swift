import SwiftUI
import AppKit
import TaskovskyCore

/// Thin resize divider with a wide invisible hit area.
///
/// The gesture reports the absolute pointer position in the stable global
/// coordinate space. The owner captures the start position and start size on
/// the first event and derives the delta from those, instead of accumulating
/// the gesture's local translation, so live layout updates can never feed
/// jitter back into the drag.
struct PanelDivider: View {
    /// Absolute global x and whether the gesture ended.
    let drag: (Double, Bool) -> Void
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1)
            .overlay {
                Color.clear.frame(width: 9).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { drag($0.location.x, false) }
                        .onEnded { drag($0.location.x, true) })
            }
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .accessibilityLabel("Resize panel")
    }
}

/// Shared completion actions: one feedback toast, one five-second Undo window,
/// one sound, across main window, drawer, pop-up, and search. The single-slot
/// UndoCoordinator guarantees one consume; expiry clears every surface at once.
@MainActor final class TaskActionCenter: ObservableObject {
    @Published var feedback: TaskFeedback?
    private let coordinator = UndoCoordinator()
    private var activeToken: UUID?
    private var expiry: Task<Void, Never>?

    func complete(store: TaskStore, id: UUID) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        if task.wontDoAt != nil { store.reopenTask(id: id); return }
        let wasComplete = task.completedAt != nil
        store.toggleComplete(id: id)
        if !wasComplete {
            if store.settings.completionSound { CompletionSound.play() }
            show(taskID: id, kind: .complete, message: "Task completed")
        }
    }
    func abandon(store: TaskStore, id: UUID) { store.markWontDo(id: id) }
    func trash(store: TaskStore, id: UUID) {
        guard store.data.tasks.first(where: { $0.id == id }) != nil else { return }
        store.trashTask(id: id)
        show(taskID: id, kind: .trash, message: "Task deleted")
    }
    func restore(store: TaskStore, id: UUID) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        store.restoreTask(id: id)
        let name = task.listID.flatMap { listID in store.data.lists.first { $0.id == listID }?.name } ?? "Inbox"
        show(taskID: id, kind: .restored, message: "Restored to \"\(name)\"")
    }
    func notice(_ message: String) { show(taskID: UUID(), kind: .info, message: message) }
    func undo(store: TaskStore) {
        guard let value = feedback, let token = activeToken, let claim = coordinator.consume(token: token), claim.taskID == value.taskID else { return }
        activeToken = nil
        feedback = nil
        switch claim.kind {
        case .complete: store.undoCompletion(id: claim.taskID)
        case .wontDo: store.reopenTask(id: claim.taskID)
        case .trash: store.restoreTask(id: claim.taskID)
        case .restore: break
        }
    }
    private func show(taskID: UUID, kind: TaskFeedback.Kind, message: String) {
        let undoKind: UndoKind? = switch kind {
        case .complete: .complete
        case .wontDo: .wontDo
        case .trash: .trash
        case .restored: .restore
        case .info: nil
        }
        let claim = undoKind.map { coordinator.record(taskID: taskID, kind: $0) }
        activeToken = claim?.token
        let value = TaskFeedback(taskID: taskID, kind: kind, message: message)
        feedback = value
        expiry?.cancel()
        expiry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            await MainActor.run { self?.expire(token: claim?.token, valueID: value.id) }
        }
    }
    private func expire(token: UUID?) {
        expire(token: token, valueID: feedback?.id)
    }
    private func expire(token: UUID?, valueID: UUID?) {
        if let token { coordinator.expire(token: token) }
        if activeToken == token, feedback?.id == valueID { activeToken = nil; feedback = nil }
    }
}

struct TaskFeedback: Identifiable {
    enum Kind { case complete, wontDo, trash, restored, info }
    let id = UUID()
    let taskID: UUID
    let kind: Kind
    let message: String
}

/// One shared feedback toast for every surface (main, drawer, pop-up, search):
/// dark rounded toast 60pt above the bottom, Undo for reversible actions, a
/// navigation chevron for restores, and nothing extra for notices.
struct FeedbackToast: View {
    @ObservedObject var actions: TaskActionCenter
    let store: TaskStore
    let onNavigateToList: (_ listID: UUID?, _ taskID: UUID) -> Void
    var body: some View {
        if let feedback = actions.feedback {
            HStack(spacing: 14) {
                Text(feedback.message).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                switch feedback.kind {
                case .restored:
                    let listID = store.data.tasks.first { $0.id == feedback.taskID }?.listID
                    Button { onNavigateToList(listID, feedback.taskID) } label: { Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).foregroundStyle(.orange) }.buttonStyle(.plain).help("Open original list").accessibilityLabel("Open original list")
                case .info: EmptyView()
                default:
                    Button { actions.undo(store: store) } label: { Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold)).foregroundStyle(.orange) }.buttonStyle(.plain).help("Undo").accessibilityLabel("Undo \(feedback.message)")
                }
            }.padding(.horizontal, 16).padding(.vertical, 12).background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 9)).shadow(color: .black.opacity(0.2), radius: 12, y: 4).padding(.bottom, 60).transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

@MainActor enum CompletionSound {
    static var sound: NSSound?
    static func play() {
        if let url = Bundle.main.url(forResource: "completion", withExtension: "wav") { sound = NSSound(contentsOf: url, byReference: true) }
        else { sound = NSSound(named: "Glass") }
        sound?.play()
    }
}
