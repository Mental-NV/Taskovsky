import Foundation
import TaskovskyDomain

/// Preferences consumed by local Calendar and capture. Presentation and
/// settings owned by other screens are outside this draft.
public struct LocalWorkspacePreferences: Equatable, Sendable {
    public var startWeekOn: Int
    public var dateRecognition: Bool
    public var removeDateText: Bool
    public var removeTagText: Bool
    public var enableTimeZone: Bool
    public var defaultDate: DefaultDate
    public var defaultPriority: TaskPriority
    public var defaultListID: UUID?
    public var defaultTagID: UUID?
    public var defaultDurationMinutes: Int
    public var defaultAddTo: TaskPosition
    public var timedReminders: Set<DueReminder>
    public var allDayReminders: Set<AllDayReminder>

    public init(_ settings: AppSettings) {
        startWeekOn = settings.startWeekOn
        dateRecognition = settings.dateRecognition
        removeDateText = settings.removeDateText
        removeTagText = settings.removeTagText
        enableTimeZone = settings.enableTimeZone
        defaultDate = settings.defaultDate
        defaultPriority = settings.defaultPriority
        defaultListID = settings.defaultListID
        defaultTagID = settings.defaultTagID
        defaultDurationMinutes = settings.defaultDurationMinutes
        defaultAddTo = settings.defaultAddTo
        timedReminders = Set(settings.effectiveTimedReminderDefaults)
        allDayReminders = Set(settings.effectiveAllDayReminderDefaults)
    }

    func valid(from previous: Self, workspace: WorkspaceData) -> Bool {
        guard startWeekOn == previous.startWeekOn || (1...7).contains(startWeekOn),
              (0...10_080).contains(defaultDurationMinutes),
              !timedReminders.contains(.none), !allDayReminders.contains(.none) else { return false }
        if defaultListID != previous.defaultListID, let id = defaultListID,
           !workspace.lists.contains(where: { $0.id == id && !$0.isArchived }) { return false }
        if defaultTagID != previous.defaultTagID, let id = defaultTagID,
           !workspace.tags.contains(where: { $0.id == id }) { return false }
        return true
    }

    func patch(_ bytes: Data, from settings: AppSettings) throws -> Data? {
        let previous = Self(settings)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var result = bytes

        func replace<Value: Codable & Equatable>(_ key: String, _ old: Value, _ new: Value) throws -> Bool {
            guard old != new else { return true }
            let encoded = try encoder.encode(new)
            guard let patched = try SettingsMemberPatch.replacing(key, in: result, with: encoded, validate: { value in
                if value == Data("null".utf8) { return true }
                do { return try decoder.decode(Value.self, from: value) == old }
                catch { return false }
            }) else { return false }
            result = patched
            return true
        }

        guard try replace("startWeekOn", previous.startWeekOn, startWeekOn),
              try replace("dateRecognition", previous.dateRecognition, dateRecognition),
              try replace("removeDateText", previous.removeDateText, removeDateText),
              try replace("removeTagText", previous.removeTagText, removeTagText),
              try replace("enableTimeZone", previous.enableTimeZone, enableTimeZone),
              try replace("defaultDate", previous.defaultDate, defaultDate),
              try replace("defaultPriority", previous.defaultPriority, defaultPriority),
              try replace("defaultListID", previous.defaultListID, defaultListID),
              try replace("defaultTagID", previous.defaultTagID, defaultTagID),
              try replace("defaultDurationMinutes", previous.defaultDurationMinutes, defaultDurationMinutes),
              try replace("defaultAddTo", previous.defaultAddTo, defaultAddTo) else { return nil }

        if timedReminders != previous.timedReminders,
           try !replace("timedReminderDefaults", settings.timedReminderDefaults, DueReminder.allCases.filter(timedReminders.contains)) {
            return nil
        }
        if allDayReminders != previous.allDayReminders,
           try !replace("allDayReminderDefaults", settings.allDayReminderDefaults, AllDayReminder.allCases.filter(allDayReminders.contains)) {
            return nil
        }
        return result
    }
}
