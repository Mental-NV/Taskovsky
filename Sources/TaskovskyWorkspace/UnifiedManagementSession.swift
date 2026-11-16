import Foundation
import TaskovskyDomain

/// Selected tab of the unified iPhone Smart Lists/Tags management sheet (T09/T11).
public enum UnifiedManagementTab: String, Sendable, CaseIterable {
    case smartLists
    case tags
}

/// Staged visibility state for the unified management sheet.
///
/// The sheet stages Smart List visibility and order (including the Tags and
/// Filters section rows) in one draft while tab switching only changes
/// presentation. `baselineRevision` is the compare-and-swap token captured when
/// the sheet opened: the parent saves with it, and a successful nested child
/// mutation (tag/filter) may only move the baseline forward while the parent
/// draft is clean. When dirty, the baseline is pinned so a later parent save
/// fails stale instead of overwriting newer settings.
public struct UnifiedManagementSession: Sendable {
    public private(set) var baselineSettings: AppSettings
    public private(set) var baselineRevision: WorkspaceRevision
    public private(set) var staged: AppSettings
    public private(set) var selectedTab: UnifiedManagementTab

    public init(settings: AppSettings, revision: WorkspaceRevision,
                selectedTab: UnifiedManagementTab = .smartLists) {
        baselineSettings = settings
        baselineRevision = revision
        staged = settings
        self.selectedTab = selectedTab
    }

    /// True while staged visibility or order differs from the baseline.
    public var isDirty: Bool { staged != baselineSettings }

    /// Stage a visibility or order edit. Never touches the baseline.
    public mutating func stage(_ update: (inout AppSettings) -> Void) {
        update(&staged)
    }

    /// Switch tabs. The staged draft is preserved untouched.
    public mutating func select(_ tab: UnifiedManagementTab) {
        selectedTab = tab
    }

    /// A nested Add/Edit Tag or Add Filter must ask first while dirty.
    public var needsChildDecision: Bool { isDirty }

    /// Drop staged edits and return to the baseline. The CAS token is unchanged.
    public mutating func discardStaged() {
        staged = baselineSettings
    }

    /// Move the baseline forward after a successful parent save of `staged`.
    /// The parent just wrote exactly these settings, so adopting them is safe.
    public mutating func markSaved(revision: WorkspaceRevision) {
        baselineSettings = staged
        baselineRevision = revision
    }

    /// Adopt newer settings plus their revision only when nothing is staged.
    /// Returns false and changes nothing while dirty, so a newer external
    /// revision is never swallowed and newer settings are never overwritten.
    @discardableResult
    public mutating func adoptBaseline(settings: AppSettings, revision: WorkspaceRevision) -> Bool {
        guard !isDirty else { return false }
        baselineSettings = settings
        baselineRevision = revision
        staged = settings
        return true
    }
}
