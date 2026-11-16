import XCTest
import TaskovskyDomain
@testable import TaskovskyWorkspace

/// Unified Smart Lists/Tags management (T09/T11): staged drafts, tab
/// preservation, nested-entry gating and compare-and-swap safety against a
/// real file repository. Neutral fixture only; no personal data.
final class UnifiedManagementTests: XCTestCase {
    private func fixture() throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent("workspace.json")
        let settings = root.appendingPathComponent("settings.json")
        var data = WorkspaceData()
        data.tags = [TaskTag(name: "Neutral area", color: "#526BF5")]
        try JSONEncoder().encode(data).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        return (root, workspace, settings)
    }

    private func bytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    // MARK: - Session draft rules

    func testTabSwitchingPreservesStagedVisibilityAndOrder() async throws {
        var session = UnifiedManagementSession(settings: AppSettings(), revision: try await neutralRevision())
        XCTAssertFalse(session.isDirty)
        XCTAssertFalse(session.needsChildDecision)
        session.stage { $0.smartListVisibility[.today] = .hidden }
        session.select(.tags)
        session.stage { $0.smartListVisibility[.tags] = .showIfNotEmpty }
        session.select(.smartLists)
        XCTAssertEqual(session.staged.smartListVisibility[.today], .hidden)
        XCTAssertEqual(session.staged.smartListVisibility[.tags], .showIfNotEmpty)
        XCTAssertTrue(session.isDirty)
        XCTAssertTrue(session.needsChildDecision)
        XCTAssertEqual(session.selectedTab, .smartLists)
    }

    func testReorderStagesWithoutTouchingBaseline() async throws {
        let before = AppSettings()
        var session = UnifiedManagementSession(settings: before, revision: try await neutralRevision())
        session.stage { _ = $0.reorderSmartList(moving: .today, before: .tomorrow, afterTarget: true) }
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(session.baselineSettings, before)
        XCTAssertEqual(session.baselineSettings.effectiveSmartListOrder, before.effectiveSmartListOrder)
    }

    func testDiscardRestoresStagedButKeepsBaselineToken() async throws {
        let revision = try await neutralRevision()
        var session = UnifiedManagementSession(settings: AppSettings(), revision: revision)
        session.stage { $0.smartListVisibility[.inbox] = .hidden }
        XCTAssertTrue(session.isDirty)
        session.discardStaged()
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.staged, session.baselineSettings)
        XCTAssertEqual(session.baselineRevision, revision)
    }

    func testAdoptCleanBaselineOnlyMovesForwardWhenClean() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        // A clean session adopts the exact newer document, preserving its settings.
        var newer = opened.snapshot.settings
        newer.smartListVisibility[.today] = .showIfNotEmpty
        guard case .saved = await repo.saveSmartLists(newer, expected: opened.revision) else {
            return XCTFail("External settings save must succeed")
        }
        let latest = try await repo.load()
        XCTAssertTrue(session.adoptCleanBaseline(from: latest))
        XCTAssertEqual(session.baselineRevision, latest.revision)
        XCTAssertEqual(session.baselineSettings.smartListVisibility[.today], .showIfNotEmpty)
        XCTAssertFalse(session.isDirty)
        // While dirty the pinned token is refused: the staged draft and the
        // original token survive the newer document untouched.
        session.stage { $0.smartListVisibility[.trash] = .hidden }
        let staged = session.staged
        let token = session.baselineRevision
        var evenNewer = latest.snapshot.settings
        evenNewer.smartListVisibility[.inbox] = .hidden
        guard case .saved = await repo.saveSmartLists(evenNewer, expected: latest.revision) else {
            return XCTFail("Second external settings save must succeed")
        }
        let newest = try await repo.load()
        XCTAssertFalse(session.adoptCleanBaseline(from: newest))
        XCTAssertEqual(session.staged, staged)
        XCTAssertEqual(session.baselineRevision, token)
        XCTAssertTrue(session.isDirty)
    }

    func testStagingWithoutSavingLeavesFilesUntouched() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let beforeWorkspace = try bytes(workspace)
        let beforeSettings = try bytes(settings)
        let loaded = try await repo.load()
        var session = UnifiedManagementSession(settings: loaded.snapshot.settings, revision: loaded.revision)
        session.stage { $0.smartListVisibility[.today] = .hidden }
        session.select(.tags)
        session.stage { $0.smartListVisibility[.tags] = .hidden }
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(try bytes(workspace), beforeWorkspace)
        XCTAssertEqual(try bytes(settings), beforeSettings)
    }

    // MARK: - Real Add Tag / Add Filter persistence

    func testRealTagCreateWithCustomColorPersistsAndReloads() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let loaded = try await repo.load()
        let custom = TaskTag(name: "Neutral child", color: "#A1B2C3")
        guard case .saved(let saved) = await repo.apply(.save(custom, creating: true),
                                                        expected: loaded.revision) else {
            return XCTFail("Neutral tag creation must save")
        }
        XCTAssertNotEqual(saved.revision, loaded.revision)
        let reloaded = try await WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings).load()
        let stored = try XCTUnwrap(reloaded.snapshot.workspace.tags.first { $0.id == custom.id })
        XCTAssertEqual(stored.name, "Neutral child")
        XCTAssertEqual(stored.color, "#A1B2C3")
    }

    func testRealFilterCreateWithUnavailableTagPersistsAndReloads() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let loaded = try await repo.load()
        var filter = TaskFilter(name: "Neutral filter")
        filter.tagIDs = [UUID()]
        guard case .saved(let saved) = await repo.apply(.create(filter), expected: loaded.revision) else {
            return XCTFail("Neutral filter creation must save")
        }
        XCTAssertNotEqual(saved.revision, loaded.revision)
        let reloaded = try await WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings).load()
        XCTAssertEqual(reloaded.snapshot.workspace.filters.first { $0.id == filter.id }?.tagIDs, filter.tagIDs)
    }

    // MARK: - CAS and stale-write safety

    func testStaleParentSaveFailsWithoutOverwritingNewerSettings() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let parent = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let external = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await parent.load()
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        session.stage { $0.smartListVisibility[.today] = .hidden }
        // Newer external settings land first.
        var newer = opened.snapshot.settings
        newer.smartListVisibility[.today] = .showIfNotEmpty
        guard case .saved = await external.saveSmartLists(newer, expected: opened.revision) else {
            return XCTFail("External settings save must succeed")
        }
        let newerBytes = try bytes(settings)
        // The dirty parent still holds the old token, so its save must go stale
        // and must not overwrite the newer settings.
        guard case .stale = await parent.saveSmartLists(session.staged, expected: session.baselineRevision) else {
            return XCTFail("Dirty parent save on an old token must report stale")
        }
        XCTAssertEqual(try bytes(settings), newerBytes)
        XCTAssertEqual(session.baselineRevision, opened.revision)
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(session.staged.smartListVisibility[.today], .hidden)
    }

    func testCleanParentAdoptsChildRevisionAndLaterSaveSucceeds() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        // Child tag mutation succeeds while the parent is clean.
        guard case .saved(let afterChild) = await repo.apply(.save(TaskTag(name: "Neutral sibling", color: "#58A58B"), creating: true),
                                                             expected: session.baselineRevision) else {
            return XCTFail("Child tag creation must save while the parent is clean")
        }
        XCTAssertTrue(session.adoptCleanBaseline(from: afterChild))
        session.stage { $0.smartListVisibility[.inbox] = .hidden }
        guard case .saved(let saved) = await repo.saveSmartLists(session.staged, expected: session.baselineRevision) else {
            return XCTFail("Parent save on the adopted child revision must succeed")
        }
        XCTAssertEqual(saved.snapshot.settings.smartListVisibility[.inbox], .hidden)
        let reopened = try await repo.load()
        XCTAssertFalse(reopened.snapshot.workspace.tags.isEmpty)
    }

    func testDirtyParentKeepsPinnedTokenAcrossChildMutation() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        session.stage { $0.smartListVisibility[.week] = .hidden }
        guard case .saved = await repo.apply(.create(TaskFilter(name: "Neutral later")),
                                             expected: opened.revision) else {
            return XCTFail("Child filter creation must save")
        }
        // The dirty parent must not adopt the newer revision: refreshing the
        // baseline would silently re-token staged edits onto newer state.
        let latest = try await repo.load()
        XCTAssertFalse(session.adoptCleanBaseline(from: latest))
        XCTAssertEqual(session.baselineRevision, opened.revision)
        guard case .stale = await repo.saveSmartLists(session.staged, expected: session.baselineRevision) else {
            return XCTFail("Dirty parent save after a child mutation must report stale")
        }
        // The failed parent write changed neither the child filter nor the
        // previously saved visibility.
        let current = try await repo.load()
        XCTAssertEqual(current.snapshot.workspace.filters.count, 1)
        XCTAssertEqual(current.snapshot.settings.smartListVisibility[.week], opened.snapshot.settings.smartListVisibility[.week])
    }

    // MARK: - Nested Edit Tag handoffs

    func testEditHandoffResolvesCurrentSnapshotNeverStaleCapture() async throws {
        // B1 regression: the pending child captures only the tag ID. While the
        // dirty decision is pending, an external rename and then a delete land.
        // The handoff must resolve the current document's own pair — never the
        // stale captured snapshot under the fresh token — and refuse the
        // missing tag.
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let external = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        let tagID = try XCTUnwrap(opened.snapshot.workspace.tags.first?.id)
        let stale = try XCTUnwrap(opened.snapshot.workspace.tags.first { $0.id == tagID })
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        session.stage { $0.smartListVisibility[.today] = .hidden }
        XCTAssertTrue(session.isDirty)
        var renamed = stale
        renamed.name = "Neutral renamed"
        guard case .saved = await external.apply(.save(renamed, creating: false), expected: opened.revision) else {
            return XCTFail("External tag rename must save")
        }
        let latest = try await repo.load()
        XCTAssertNotEqual(latest.revision, opened.revision)
        guard let handoff = session.tagHandoff(tagID: tagID, in: latest) else {
            return XCTFail("Renamed tag must still resolve")
        }
        XCTAssertEqual(handoff.tag.name, "Neutral renamed")
        XCTAssertNotEqual(handoff.tag, stale)
        XCTAssertEqual(handoff.revision, latest.revision)
        XCTAssertEqual(handoff.tag, latest.snapshot.workspace.tags.first { $0.id == tagID })
        guard case .saved = await external.apply(TagOrganizationCommand.delete(tagID), expected: latest.revision) else {
            return XCTFail("External tag delete must save")
        }
        let afterDelete = try await repo.load()
        XCTAssertNil(session.tagHandoff(tagID: tagID, in: afterDelete))
        // The dirty parent still holds its original token and draft; the
        // external tag changes were never folded into the staged settings.
        XCTAssertEqual(session.baselineRevision, opened.revision)
        XCTAssertTrue(session.isDirty)
    }

    func testChildCancelResolvesWithoutWriting() async throws {
        // Resolving a handoff and then cancelling (dropping it without a
        // command) must leave the revision and both files untouched.
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        let session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        let tagID = try XCTUnwrap(opened.snapshot.workspace.tags.first?.id)
        XCTAssertNotNil(session.tagHandoff(tagID: tagID, in: opened))
        XCTAssertNil(session.tagHandoff(tagID: UUID(), in: opened))
        let beforeWorkspace = try bytes(workspace)
        let beforeSettings = try bytes(settings)
        let reloaded = try await repo.load()
        XCTAssertEqual(reloaded.revision, opened.revision)
        XCTAssertEqual(try bytes(workspace), beforeWorkspace)
        XCTAssertEqual(try bytes(settings), beforeSettings)
    }

    func testCleanAdoptFollowsWorkspaceOnlyChildChange() async throws {
        // A workspace-only child change (tag create, settings untouched) moves
        // the revision; a clean parent adopts the exact new document and a
        // later staged save succeeds on it.
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        guard case .saved = await repo.apply(.save(TaskTag(name: "Neutral adopted", color: "#526BF5"), creating: true),
                                             expected: opened.revision) else {
            return XCTFail("Child tag creation must save")
        }
        let latest = try await repo.load()
        XCTAssertEqual(latest.snapshot.settings, opened.snapshot.settings)
        XCTAssertTrue(session.adoptCleanBaseline(from: latest))
        XCTAssertEqual(session.staged, session.baselineSettings)
        session.stage { $0.smartListVisibility[.trash] = .hidden }
        guard case .saved(let saved) = await repo.saveSmartLists(session.staged, expected: session.baselineRevision) else {
            return XCTFail("Parent save on the adopted revision must succeed")
        }
        XCTAssertEqual(saved.snapshot.settings.smartListVisibility[.trash], .hidden)
    }

    func testStaleTagAndFilterWritesAreRefusedWithoutMutation() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        guard case .saved = await repo.apply(.create(TaskFilter(name: "Neutral first")), expected: opened.revision) else {
            return XCTFail("Initial filter creation must save")
        }
        let beforeWorkspace = try bytes(workspace)
        let beforeSettings = try bytes(settings)
        guard case .refused(.stale) = await repo.apply(.save(TaskTag(name: "Neutral late", color: "#526BF5"), creating: true),
                                                       expected: opened.revision) else {
            return XCTFail("Stale tag write must be refused")
        }
        guard case .refused(.stale) = await repo.apply(.create(TaskFilter(name: "Neutral stale")),
                                                       expected: opened.revision) else {
            return XCTFail("Stale filter write must be refused")
        }
        XCTAssertEqual(try bytes(workspace), beforeWorkspace)
        XCTAssertEqual(try bytes(settings), beforeSettings)
    }

    func testFailedParentWriteRetainsDraftWithoutMutation() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let failing = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings,
                                              write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let opened = try await failing.load()
        let beforeSettings = try bytes(settings)
        var session = UnifiedManagementSession(settings: opened.snapshot.settings, revision: opened.revision)
        session.stage { $0.smartListVisibility[.completed] = .showIfNotEmpty }
        guard case .persistenceFailed = await failing.saveSmartLists(session.staged, expected: session.baselineRevision) else {
            return XCTFail("Injected write failure must not succeed")
        }
        XCTAssertEqual(try bytes(settings), beforeSettings)
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(session.staged.smartListVisibility[.completed], .showIfNotEmpty)
    }

    // MARK: - Preserved tag rules

    func testCyclicParentRemainsRefusedAndWritesNothing() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        let parent = try XCTUnwrap(opened.snapshot.workspace.tags.first)
        var child = TaskTag(name: "Neutral descendant", color: "#526BF5", parentID: parent.id)
        guard case .saved(let withChild) = await repo.apply(.save(child, creating: true), expected: opened.revision) else {
            return XCTFail("Child tag creation must save")
        }
        let tags = withChild.snapshot.workspace.tags
        XCTAssertFalse(TagOrganization.allowsParent(child.id, for: parent.id, in: tags))
        XCTAssertFalse(TagOrganization.allowsParent(parent.id, for: parent.id, in: tags))
        XCTAssertFalse(TagOrganization.allowsParent(UUID(), for: parent.id, in: tags))
        var cyclic = parent
        cyclic.parentID = child.id
        child = withChild.snapshot.workspace.tags.first { $0.id == child.id } ?? child
        let beforeWorkspace = try bytes(workspace)
        let beforeSettings = try bytes(settings)
        let cyclicResult = await repo.apply(.save(cyclic, creating: false), expected: withChild.revision)
        guard case .refused = cyclicResult else {
            return XCTFail("Cyclic reparent must be refused")
        }
        XCTAssertEqual(try bytes(workspace), beforeWorkspace)
        XCTAssertEqual(try bytes(settings), beforeSettings)
    }

    func testDuplicateTagNameRemainsRefused() async throws {
        let (root, workspace, settings) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let opened = try await repo.load()
        let beforeWorkspace = try bytes(workspace)
        guard case .refused = await repo.apply(.save(TaskTag(name: "neutral AREA", color: "#526BF5"), creating: true),
                                               expected: opened.revision) else {
            return XCTFail("Duplicate tag name must be refused")
        }
        XCTAssertEqual(try bytes(workspace), beforeWorkspace)
    }

    // MARK: - Helpers

    private func neutralRevision() async throws -> WorkspaceRevision {
        // Sessions only compare tokens for equality; any persisted revision works.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace.json")
        let settings = root.appendingPathComponent("settings.json")
        try JSONEncoder().encode(WorkspaceData()).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        return try await WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings).load().revision
    }
}
