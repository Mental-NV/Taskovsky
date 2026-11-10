import Foundation

/// Shared legacy cadence, extracted without changing the desktop stepping policy.
public enum LegacyRecurrence {
    public static func nextDate(after date: Date, rule: RepeatRule, anchorDay: Int? = nil, anchorMonth: Int? = nil, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            guard var next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            while calendar.component(.weekday, from: next) == 1 || calendar.component(.weekday, from: next) == 7 {
                guard let following = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }; next = following
            }
            return next
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly, .yearly:
            // Move from the first of the month, then clamp the original day to its length.
            var components = calendar.dateComponents([.era, .year, .month, .hour, .minute, .second, .nanosecond], from: date)
            let day = anchorDay ?? calendar.component(.day, from: date)
            components.day = 1
            guard let first = calendar.date(from: components),
                  let advanced = calendar.date(byAdding: rule == .monthly ? .month : .year, value: 1, to: first) else { return nil }
            var target = calendar.dateComponents([.era, .year, .month, .hour, .minute, .second, .nanosecond], from: advanced)
            if rule == .yearly, let anchorMonth { target.month = anchorMonth }
            target.day = 1
            guard let targetFirst = calendar.date(from: target), let days = calendar.range(of: .day, in: .month, for: targetFirst) else { return nil }
            target.day = min(max(day, 1), days.count)
            return calendar.date(from: target)
        }
    }
}
