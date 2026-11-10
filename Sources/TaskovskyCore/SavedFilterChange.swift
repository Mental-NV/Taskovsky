import Foundation

public enum SavedFilterChange: Sendable {
    case create(TaskFilter)
    case update(TaskFilter)
    case delete(UUID)

    public func apply(to data: inout WorkspaceData) throws -> Bool? {
        switch self {
        case .create(let value):
            guard !data.filters.contains(where: { $0.id == value.id }), let filter = validated(value) else { return nil }
            data.filters.append(filter)
        case .update(let value):
            let matches = data.filters.indices.filter { data.filters[$0].id == value.id }
            guard matches.count == 1, let index = matches.first,
                  let filter = validated(value, original: data.filters[index]) else { return nil }
            if try Self.sameDefinition(data.filters[index], filter) { return false }
            data.filters[index] = filter
        case .delete(let id):
            let matches = data.filters.indices.filter { data.filters[$0].id == id }
            guard matches.count == 1, let index = matches.first else { return nil }
            data.filters.remove(at: index)
        }
        return true
    }

    public static func sameDefinition(_ lhs: TaskFilter, _ rhs: TaskFilter) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(lhs) == encoder.encode(rhs)
    }

    private func validated(_ value: TaskFilter, original: TaskFilter? = nil) -> TaskFilter? {
        var filter = value
        filter.name = filter.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filter.name.isEmpty else { return nil }
        if filter.ruleRoot == nil, filter.dateRules.contains(.custom),
           filter.customDateFrom == nil, filter.customDateTo == nil {
            guard let original, original.ruleRoot == nil, original.dateRules == filter.dateRules,
                  original.customDateFrom == nil, original.customDateTo == nil else { return nil }
        }
        return filter
    }
}
