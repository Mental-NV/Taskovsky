import Foundation

/// Live-observed D12 Repeat preset menu, in exact reference order:
/// None, Daily, Weekly ({Weekday}), Monthly (the {ordinal} day),
/// Yearly ({day} {Mon}), Every Weekday ({Mon} - {Fri}), Custom.
///
/// This is a pure presentation/derivation helper. It stages nothing and
/// changes no recurrence, anchor, end-date, persistence or notification
/// semantics; preset taps stage through `TaskScheduleEdit.selectSimpleRepeat`
/// and custom rules continue through the existing custom branch. Names come
/// from the staged calendar's symbols; the fixed sentence shapes follow the
/// observed English reference and are not claimed locale-correct.
public enum RepeatPreset: String, CaseIterable, Sendable {
    case none, daily, weekly, monthly, yearly, weekdays, custom

    /// The menu rows in exact reference order.
    public static var menuCases: [RepeatPreset] {
        [.none, .daily, .weekly, .monthly, .yearly, .weekdays, .custom]
    }

    /// The simple `RepeatRule` a preset stages, if any. Custom has no simple
    /// rule: it opens the existing custom sheet instead.
    public var repeatRule: RepeatRule? {
        switch self {
        case .none: return .none
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .weekdays: return .weekdays
        case .custom: return nil
        }
    }

    /// Detects the preset matching staged state. A staged custom rule never
    /// reports a simple preset, so opening the menu cannot read a custom
    /// rule as a converted preset.
    public static func current(repeatRule: RepeatRule, customRule: CustomRecurrence?) -> RepeatPreset? {
        guard customRule == nil else { return nil }
        return RepeatPreset(rawValue: repeatRule.rawValue)
    }

    /// Menu row label derived from the staged due date in the staged
    /// calendar/zone (for example Thursday November 12 yields
    /// "Weekly (Thursday)", "Monthly (the 12th day)", "Yearly (12 Nov)").
    public func menuLabel(due: Date, calendar: Calendar) -> String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly:
            return "Weekly (\(Self.fullWeekday(calendar.component(.weekday, from: due), calendar: calendar)))"
        case .monthly:
            return "Monthly (the \(Self.ordinal(calendar.component(.day, from: due))) day)"
        case .yearly:
            let day = calendar.component(.day, from: due)
            let month = calendar.component(.month, from: due)
            return "Yearly (\(day) \(Self.shortMonth(month, calendar: calendar)))"
        case .weekdays:
            return "Every Weekday (\(Self.shortWeekday(2, calendar: calendar)) - \(Self.shortWeekday(6, calendar: calendar)))"
        case .custom: return "Custom"
        }
    }

    /// Draft summary shown on the Schedule Repeat row. Weekly follows the
    /// observed `Every week on Thu` shape; other simple presets reuse their
    /// menu label (Taskovsky wording, not a claimed reference summary).
    public func draftSummary(due: Date, calendar: Calendar) -> String {
        switch self {
        case .weekly:
            return "Every week on \(Self.shortWeekday(calendar.component(.weekday, from: due), calendar: calendar))"
        default:
            return menuLabel(due: due, calendar: calendar)
        }
    }

    // MARK: - Symbols

    static func fullWeekday(_ weekday: Int, calendar: Calendar) -> String {
        guard (1...7).contains(weekday), calendar.weekdaySymbols.count == 7 else { return "day \(weekday)" }
        return calendar.weekdaySymbols[weekday - 1]
    }

    static func shortWeekday(_ weekday: Int, calendar: Calendar) -> String {
        guard (1...7).contains(weekday), calendar.shortWeekdaySymbols.count == 7 else { return "day \(weekday)" }
        return calendar.shortWeekdaySymbols[weekday - 1]
    }

    static func shortMonth(_ month: Int, calendar: Calendar) -> String {
        guard (1...12).contains(month), calendar.shortMonthSymbols.count == 12 else { return "month \(month)" }
        return calendar.shortMonthSymbols[month - 1]
    }

    static func ordinal(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "\(day)st"
        case 2, 22: return "\(day)nd"
        case 3, 23: return "\(day)rd"
        default: return "\(day)th"
        }
    }
}
