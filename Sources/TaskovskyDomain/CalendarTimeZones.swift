import Foundation

/// Local display preferences only: rulers never change a task's time zone.
public struct CalendarTimeZone: Codable, Equatable, Identifiable, Sendable {
    /// Four configurable rulers beside the primary zone, verified in the Mac editor.
    public static let maximumCount = 4
    public var identifier: String
    public var label: String
    public var id: String { identifier }
    public init(identifier: String, label: String = "") {
        self.identifier = identifier
        self.label = label
    }
    private enum CodingKeys: String, CodingKey { case identifier, label }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.decode(String.self, forKey: .identifier)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
    }
    public func title(at date: Date) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TimeZone(identifier: identifier)?.abbreviation(for: date) ?? identifier : trimmed
    }
    public static func normalized(_ zones: [Self]) -> [Self] {
        var seen = Set<String>()
        return Array(zones.compactMap { zone -> Self? in
            guard TimeZone(identifier: zone.identifier) != nil, seen.insert(zone.identifier).inserted else { return nil }
            return Self(identifier: zone.identifier, label: String(zone.label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32)))
        }.prefix(maximumCount))
    }
}
