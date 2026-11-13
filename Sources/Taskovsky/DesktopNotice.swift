import SwiftUI
import TaskovskyCore

/// One presentation lifetime per event, not per distinct message string.
/// Success/Undo feedback follows the existing five-second completion toast.
/// Errors remain until dismissal/replacement. Expiry never performs a store mutation.
@MainActor final class DesktopNotice: ObservableObject {
    struct Event: Identifiable {
        let id = UUID()
        let message: String
        let undo: CalendarScheduleUndo?
    }
    @Published private(set) var event: Event?
    private var expiry: Task<Void, Never>?
    private let duration: Duration

    init(duration: Duration = .seconds(5)) { self.duration = duration }
    deinit { expiry?.cancel() }

    func show(_ message: String, undo: CalendarScheduleUndo? = nil, persistent: Bool = false) {
        expiry?.cancel()
        let value = Event(message: message, undo: undo)
        event = value
        guard !persistent else { expiry = nil; return }
        let duration = duration
        expiry = Task { [weak self] in
            do { try await Task.sleep(for: duration) } catch { return }
            self?.expire(id: value.id)
        }
    }
    func dismiss() { expiry?.cancel(); expiry = nil; event = nil }
    func expire(id: UUID) {
        guard event?.id == id else { return }
        dismiss()
    }
    func undo(in store: TaskStore) {
        guard let token = event?.undo else { return }
        if store.undoCalendarSchedule(token) { show("Schedule restored") }
        else { show(store.storageError ?? "Schedule changed since this edit", persistent: true) }
    }
}
