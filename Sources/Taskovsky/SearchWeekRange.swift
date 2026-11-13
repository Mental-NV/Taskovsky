import Foundation
import TaskovskyCore

/// Presentation of the same half-open weeks used by TaskFilter. Captions show
/// the inclusive last civil day; they do not alter filtering or stored criteria.
enum SearchWeekRange {
    static func bounds(for rule: FilterDateRule, now: Date, calendar: Calendar) -> (start: Date, through: Date)? {
        let offset: Int
        switch rule {
        case .thisWeek: offset = 0
        case .nextWeek: offset = 1
        case .lastWeek: offset = -1
        default: return nil
        }
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now),
              let start = calendar.date(byAdding: .weekOfYear, value: offset, to: current.start),
              let end = calendar.date(byAdding: .weekOfYear, value: offset, to: current.end),
              let through = calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        return (start, through)
    }
    static func label(for rule: FilterDateRule, now: Date, calendar: Calendar, locale: Locale = .autoupdatingCurrent) -> String {
        guard let bounds = bounds(for: rule, now: now, calendar: calendar) else { return rule.label }
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return rule.label + " (" + formatter.string(from: bounds.start, to: bounds.through) + ")"
    }
}
