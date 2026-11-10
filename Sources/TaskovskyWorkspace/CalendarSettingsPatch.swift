import Foundation
import TaskovskyDomain

/// A Calendar preference edit replaces a single JSON value. Preserve the
/// exact bytes of adjacent preferences, including keys from newer builds.
enum CalendarSettingsPatch {
    static func replacing(_ settings: Data, current: TaskCalendarOptions, with replacement: Data) throws -> Data? {
        try SettingsMemberPatch.replacing("calendarOptions", in: settings, with: replacement) { existing in
            try isKnown(existing, current: current)
        }
    }

    private static func isKnown(_ existing: Data, current: TaskCalendarOptions) throws -> Bool {
        let value = try JSONSerialization.jsonObject(with: existing, options: .fragmentsAllowed)
        if value is NSNull { return true }
        guard let fields = value as? [String: Any],
              let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any] else {
            return false
        }
        for (key, raw) in fields {
            if key == "additionalTimeZoneID", fields["additionalTimeZones"] == nil {
                if raw is NSNull { continue }
                guard let id = raw as? String, current.additionalTimeZoneID == id else { return false }
            } else if raw is NSNull, key == "listIDs" || key == "additionalTimeZoneID" {
                guard canonical[key] == nil else { return false }
            } else {
                guard let known = canonical[key], try fragment(raw) == fragment(known) else { return false }
            }
        }
        return true
    }

    private static func fragment(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }
}

enum SettingsMemberPatch {
    static func replacing(_ name: String, in settings: Data, with replacement: Data,
                          validate: (Data) throws -> Bool) throws -> Data? {
        guard JSONKeySafety.hasUniqueKeys(settings) else { return nil }
        var scanner = JSONKeySafety(bytes: Array(settings))
        guard let member = scanner.rootMember(named: name) else { return nil }
        var bytes = settings
        if member.range.isEmpty {
            let key = try JSONEncoder().encode(name)
            let comma = member.hasMembers ? Data([44]) : Data()
            bytes.replaceSubrange(member.range, with: comma + key + Data([58]) + replacement)
        } else {
            guard try validate(settings.subdata(in: member.range)) else { return nil }
            bytes.replaceSubrange(member.range, with: replacement)
        }
        return bytes
    }
}
