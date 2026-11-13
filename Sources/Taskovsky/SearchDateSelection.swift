import TaskovskyCore

/// Full Search's unfiltered state is empty; `.all` must not coexist with
/// specific OR-ed rules or it would silently make those choices ineffective.
enum SearchDateSelection {
    static func toggling(_ rule: FilterDateRule, in selected: Set<FilterDateRule>) -> Set<FilterDateRule> {
        guard rule != .all else { return [] }
        var next = selected.subtracting([.all])
        if next.contains(rule) { next.remove(rule) } else { next.insert(rule) }
        return next
    }
    static func applyingCustom(to selected: Set<FilterDateRule>) -> Set<FilterDateRule> {
        selected.subtracting([.all]).union([.custom])
    }
}
