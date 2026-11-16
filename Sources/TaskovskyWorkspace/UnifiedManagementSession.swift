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
///
/// Baseline moves always carry one exact persisted document's settings plus
/// its revision — fields are never paired across revisions. Nested tag entry
/// captures only the tag ID; the editor snapshot is resolved from that same
/// document at handoff, so a stale captured tag is never saved under a fresh
/// token.
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

    /// Adopt an exact persisted document as the new baseline, but only when
    /// nothing is staged. Returns false and changes nothing while dirty.
    ///
    /// Provenance (owned child save, external update, stale-recovery reload)
    /// does not matter here: a clean session holds no user edits, so moving
    /// the baseline to this document's own settings+revision pair preserves
    /// newer state and never mixes fields across revisions. While dirty the
    /// pinned token is kept, so a later parent save reports stale instead of
    /// overwriting the newer document.
    @discardableResult
    public mutating func adoptCleanBaseline(from document: WorkspaceDocument) -> Bool {
        guard !isDirty else { return false }
        baselineSettings = document.snapshot.settings
        baselineRevision = document.revision
        staged = document.snapshot.settings
        return true
    }

    /// Resolve a nested Edit Tag handoff from one exact persisted document.
    /// Returns the tag snapshot together with that same document's revision,
    /// or nil when the tag is gone (deleted or unknown). Callers must open the
    /// editor with exactly this pair — never a previously captured tag under a
    /// newer token — and must refuse to open when this returns nil.
    public func tagHandoff(tagID: UUID, in document: WorkspaceDocument) -> UnifiedTagHandoff? {
        guard let tag = document.snapshot.workspace.tags.first(where: { $0.id == tagID }) else { return nil }
        return UnifiedTagHandoff(tag: tag, revision: document.revision)
    }
}

/// One exact document's tag snapshot plus its own revision for a nested Edit
/// Tag handoff. The pair must travel together into the editor request.
public struct UnifiedTagHandoff: Sendable {
    public let tag: TaskTag
    public let revision: WorkspaceRevision
}
