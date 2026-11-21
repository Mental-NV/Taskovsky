/// Normal date pickers’ unfiltered state is empty; `.all` must not coexist with
/// specific OR-ed rules or it would silently make those choices ineffective.
public enum DateRuleSelection {
    public static func toggling(_ rule: FilterDateRule, in selected: Set<FilterDateRule>) -> Set<FilterDateRule> {
        guard rule != .all else { return [] }
        var next = selected.subtracting([.all])
        if next.contains(rule) { next.remove(rule) } else { next.insert(rule) }
        return next
    }
    public static func applyingCustom(to selected: Set<FilterDateRule>) -> Set<FilterDateRule> {
        selected.subtracting([.all]).union([.custom])
    }
    /// Array-backed forms retain the order of unrelated selections on explicit edits.
    public static func togglingArray(_ rule: FilterDateRule, in selected: [FilterDateRule]) -> [FilterDateRule] {
        guard rule != .all else { return [] }
        var next = selected.filter { $0 != .all && $0 != rule }
        if !selected.contains(rule) { next.append(rule) }
        return next
    }
}
