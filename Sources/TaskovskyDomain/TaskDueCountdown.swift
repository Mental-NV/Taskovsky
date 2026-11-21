import Foundation

public enum TaskDueCountdown {
    public static func label(for task: TaskItem, now: Date, calendar: Calendar) -> String? {
        guard task.kind == .task, task.completedAt == nil, task.wontDoAt == nil, task.deletedAt == nil,
              let due = task.dueDate else { return nil }
        let seconds = due.timeIntervalSince(now)
        guard seconds.isFinite else { return nil }
        let local = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
        guard let days = local.dateComponents([.day], from: local.startOfDay(for: now),
                                              to: local.startOfDay(for: due)).day else { return nil }
        if !task.hasDueTime || (days != 0 && abs(seconds) >= 86_400) {
            if days == 0 { return "Due today" }
            let unit = days.magnitude == 1 ? "day" : "days"
            return "\(days.magnitude) \(unit) \(days > 0 ? "left" : "overdue")"
        }
        if seconds == 0 { return "Due now" }
        let roundedMinutes = ceil(abs(seconds) / 60)
        guard roundedMinutes < Double(Int.max) else { return nil }
        let minutes = Int(roundedMinutes)
        let hours = minutes / 60, remainder = minutes % 60
        let amount = hours == 0 ? "\(minutes)m" : remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        return amount + (seconds > 0 ? " left" : " overdue")
    }
}
