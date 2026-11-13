import Foundation

/// Only the undated Time entry path seeds today; existing dated drafts remain intact.
enum ScheduleTimeActivation {
    static func seed(hasDate: Bool, now: Date, calendar: Calendar) -> Date? {
        hasDate ? nil : calendar.startOfDay(for: now)
    }
}
