import Foundation

/// Pure rule-tree transformations backing the Advanced filter editor's
/// "convert" menu. Every conversion preserves the existing conditions:
/// group-to-group keeps children WITHOUT inserting an always-true
/// placeholder (an inserted empty-keyword condition would make an OR
/// branch match everything), and wrapping a leaf keeps the leaf itself.
/// Conversions that would silently drop conditions are refused by returning
/// the rule unchanged.
public enum FilterRuleEdit {
    /// Maximum editor nesting depth (mirrors the UI's add-button cap).
    public static let maxDepth = 3

    /// Group conversions preserve children; a leaf (condition or NOT)
    /// wraps as the group's single child.
    public static func convertToAnd(_ rule: FilterRule) -> FilterRule {
        switch rule {
        case .and: return rule
        case .or(let children): return .and(children)
        case .not, .condition: return .and([rule])
        }
    }

    /// Group conversions preserve children; a leaf (condition or NOT)
    /// wraps as the group's single child.
    public static func convertToOr(_ rule: FilterRule) -> FilterRule {
        switch rule {
        case .or: return rule
        case .and(let children): return .or(children)
        case .not, .condition: return .or([rule])
        }
    }

    /// Wraps the rule in NOT. Refused past the depth cap (returns the rule
    /// unchanged) so the tree cannot grow without bound through the UI.
    public static func convertToNot(_ rule: FilterRule, depth: Int) -> FilterRule {
        guard depth < maxDepth else { return rule }
        return .not(rule)
    }

    /// Collapses to a single condition only when semantics are identical:
    /// a rule that already is one, or a group with exactly one child.
    /// Multi-child groups and NOTs return unchanged — replacing them with a
    /// bare condition would silently drop constraints.
    public static func convertToCondition(_ rule: FilterRule) -> FilterRule {
        switch rule {
        case .condition: return rule
        case .and(let children), .or(let children):
            return children.count == 1 ? children[0] : rule
        case .not: return rule
        }
    }
}
