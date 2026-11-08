import XCTest
@testable import TaskovskyCore

/// List archiving/exclusion/duplication, tag hierarchy/merge/delete, filter
/// criteria/rules/legacy, pins, and the shared smart-list eligibility policy.
final class OrgScopeTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
    }
    @MainActor private func store() -> (TaskStore, URL) {
        let url = tempURL()
        return (TaskStore(fileURL: url, seed: false), url)
    }
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Legacy defaults

    func testWorkspaceDocumentDecodesAllNewFields() throws {
        let listA = UUID(), listB = UUID(), parent = UUID(), child = UUID(), filter = UUID()
        let task = UUID()
        let json = """
        {"tasks":[{"id":"\(task.uuidString)","title":"T","body":"hi","listID":"\(listA.uuidString)",
         "tagIDs":["\(child.uuidString)"],"kind":"task","hasDueTime":false,"priority":"high",
         "recurrence":"daily","checklist":[],"createdAt":718332000,"updatedAt":718332000,
         "richBody":{"text":"hi","runs":[{"location":0,"length":2,"bold":true}],"blocks":[{"location":0,"length":2,"heading":2}]},
         "isPinned":true}],
         "lists":[{"id":"\(listA.uuidString)","name":"Old","color":"#fff","isArchived":true},
          {"id":"\(listB.uuidString)","name":"Live","color":"#fff","showsInSmartLists":false,"isPinned":true,"folderID":null,"belowFolders":true}],
         "tags":[{"id":"\(parent.uuidString)","name":"P","color":"#fff","isPinned":true},
          {"id":"\(child.uuidString)","name":"C","color":"#fff","parentID":"\(parent.uuidString)"}],
         "folders":[{"id":"\(UUID().uuidString)","name":"F","isPinned":true}],
         "filters":[{"id":"\(filter.uuidString)","name":"R","listIDs":[],"tagIDs":[],"status":"active","keyword":"",
          "priorities":["high"],"dateRules":["thisWeek"],"kinds":["task"],"tagMode":"all",
          "ruleRoot":{"type":"and","children":[{"type":"condition","condition":{"kind":"repeating"}}]}}],
         "templates":[]}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(WorkspaceData.self, from: json)
        let loaded = try XCTUnwrap(data.tasks.first)
        XCTAssertEqual(loaded.body, "hi")
        XCTAssertEqual(loaded.richBody?.valid(for: "hi")?.runs.first?.bold, true)
        XCTAssertEqual(loaded.richBody?.valid(for: "hi")?.blocks.first?.heading, 2)
        XCTAssertTrue(loaded.isPinned)
        XCTAssertEqual(loaded.priority, .high)
        XCTAssertEqual(loaded.recurrence, .daily)
        XCTAssertTrue(data.lists.first { $0.id == listA }?.isArchived == true)
        XCTAssertFalse(data.lists.first { $0.id == listB }?.showsInSmartLists == true)
        XCTAssertTrue(data.lists.first { $0.id == listB }?.isPinned == true)
        XCTAssertEqual(data.tags.first { $0.id == child }?.parentID, parent)
        let rule = try XCTUnwrap(data.filters.first?.ruleRoot)
        XCTAssertEqual(data.filters.first?.priorities, [.high])
        XCTAssertEqual(data.filters.first?.dateRules, [.thisWeek])
        XCTAssertEqual(data.filters.first?.tagMode, .all)
        if case .and(let kids) = rule { XCTAssertEqual(kids.count, 1) } else { return XCTFail("rule") }
        // Round-trips byte-identically through the encoder.
        let back = try JSONDecoder().decode(WorkspaceData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(back, data)
    }

    func testLegacyEntitiesDecodeActiveUnpinned() throws {
        let json = """
        {"tasks":[],"filters":[],"templates":[],
         "lists":[{"id":"\(UUID().uuidString)","name":"L","color":"#fff","kind":"task"}],
         "tags":[{"id":"\(UUID().uuidString)","name":"T","color":"#fff"}],
         "folders":[{"id":"\(UUID().uuidString)","name":"F"}]}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(WorkspaceData.self, from: json)
        let list = try XCTUnwrap(data.lists.first)
        XCTAssertFalse(list.isArchived)
        XCTAssertTrue(list.showsInSmartLists)
        XCTAssertFalse(list.isPinned)
        XCTAssertFalse(try XCTUnwrap(data.tags.first).isPinned)
        XCTAssertNil(try XCTUnwrap(data.tags.first).parentID)
        XCTAssertFalse(try XCTUnwrap(data.folders.first).isPinned)
    }

    // MARK: - Archive / exclusion eligibility

    @MainActor func testArchiveSuppressesSmartAndRemindersButKeepsTasks() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let listID = store.createList(name: "Old", color: "#fff")
        let taskID = store.createTask(title: "Relic", listID: listID)
        var lists = store.data.lists
        XCTAssertFalse(SmartListEligibility.isExcludedFromSmart(store.data.tasks.first { $0.id == taskID }!, lists: lists))
        XCTAssertTrue(store.setListArchived(id: listID, archived: true))
        lists = store.data.lists
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == taskID })
        XCTAssertTrue(SmartListEligibility.isExcludedFromSmart(task, lists: lists))
        XCTAssertTrue(SmartListEligibility.isArchived(task, lists: lists))
        XCTAssertFalse(SmartListEligibility.allowsReminders(task, lists: lists))
        // The task itself survives untouched and unarchiving restores it.
        XCTAssertEqual(task.title, "Relic")
        XCTAssertTrue(store.setListArchived(id: listID, archived: false))
        XCTAssertFalse(SmartListEligibility.isExcludedFromSmart(store.data.tasks.first { $0.id == taskID }!, lists: store.data.lists))
    }

    @MainActor func testExcludedListKeepsReminders() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let listID = store.createList(name: "Someday", color: "#fff")
        let taskID = store.createTask(title: "Idea", listID: listID)
        XCTAssertTrue(store.setListSmartInclusion(id: listID, shows: false))
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == taskID })
        XCTAssertTrue(SmartListEligibility.isExcludedFromSmart(task, lists: store.data.lists))
        XCTAssertFalse(SmartListEligibility.isArchived(task, lists: store.data.lists))
        XCTAssertTrue(SmartListEligibility.allowsReminders(task, lists: store.data.lists))
    }

    func testUnknownListStaysVisible() {
        // Fail-open: a task referencing a missing list is never hidden.
        let task = TaskItem(title: "X", listID: UUID())
        XCTAssertFalse(SmartListEligibility.isExcludedFromSmart(task, lists: []))
        XCTAssertFalse(SmartListEligibility.isArchived(task, lists: []))
    }

    // MARK: - Duplicate list

    @MainActor func testDuplicateListCopiesNondeletedWithFreshIDs() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let folder = store.createFolder(name: "F")
        let listID = store.createList(name: "Work", color: "#fff", folderID: folder)
        let keepID = store.createTask(title: "Keep", listID: listID)
        var keep = try XCTUnwrap(store.data.tasks.first { $0.id == keepID })
        keep.body = "notes here"
        keep.richBody = RichBody(text: "notes here", runs: [RichInlineRun(location: 0, length: 5, bold: true)])
        keep.checklist = [ChecklistItem(title: "step", isCompleted: true)]
        keep.priority = .high
        store.updateTask(keep)
        let goneID = store.createTask(title: "Gone", listID: listID)
        store.trashTask(id: goneID)
        XCTAssertTrue(store.setListPinned(id: listID, pinned: true))
        let copyID = try XCTUnwrap(store.duplicateList(id: listID))
        let copy = try XCTUnwrap(store.data.lists.first { $0.id == copyID })
        XCTAssertEqual(copy.name, "Work copy")
        XCTAssertEqual(copy.folderID, folder)
        XCTAssertFalse(copy.isArchived)
        XCTAssertFalse(copy.isPinned)
        let copied = store.data.tasks.filter { $0.listID == copyID }
        XCTAssertEqual(copied.count, 1)
        let task = try XCTUnwrap(copied.first)
        XCTAssertNotEqual(task.id, keepID)
        XCTAssertEqual(task.body, "notes here")
        XCTAssertEqual(task.richBody?.valid(for: task.body)?.runs.first?.bold, true)
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.checklist.count, 1)
        XCTAssertNotEqual(task.checklist.first?.id, keep.checklist.first?.id)
        XCTAssertTrue(task.checklist.first?.isCompleted == true)
        // Recurrence links never chain the copy to the original.
        XCTAssertNil(task.recurrenceSourceID)
        XCTAssertNil(store.duplicateList(id: UUID()))
    }

    @MainActor func testArchivedListsRefuseNewAndMovedTasks() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let archived = store.createList(name: "Old", color: "#fff")
        XCTAssertTrue(store.setListArchived(id: archived, archived: true))
        let made = store.createTask(title: "New", listID: archived)
        XCTAssertNil(store.data.tasks.first { $0.id == made }?.listID)
        let other = store.createList(name: "Live", color: "#fff")
        let taskID = store.createTask(title: "T", listID: other)
        XCTAssertFalse(store.moveTasksToList(ids: [taskID], listID: archived))
        XCTAssertEqual(store.data.tasks.first { $0.id == taskID }?.listID, other)
        // Default-list fallback: an archived default creates into Inbox.
        store.settings.defaultListID = archived
        let fallback = store.createTask(title: "D")
        XCTAssertNil(store.data.tasks.first { $0.id == fallback }?.listID)
        // Templates instantiate into Inbox too.
        guard let templateID = store.saveTemplate(from: taskID) else { return XCTFail("template") }
        let instanced = try XCTUnwrap(store.createTaskFromTemplate(id: templateID, listID: archived))
        XCTAssertNil(store.data.tasks.first { $0.id == instanced }?.listID)
    }

    // MARK: - Pins persist

    @MainActor func testPinsPersistAcrossReload() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let listID = store.createList(name: "L", color: "#fff")
        guard let folderID = store.createFolder(name: "F") else { return XCTFail("folder") }
        let tagID = store.createTag(name: "T", color: "#fff")
        let filterID = store.createFilter(TaskFilter(name: "Fil"))
        XCTAssertTrue(store.setListPinned(id: listID, pinned: true))
        XCTAssertTrue(store.setFolderPinned(id: folderID, pinned: true))
        XCTAssertTrue(store.setTagPinned(id: tagID, pinned: true))
        XCTAssertTrue(store.setFilterPinned(id: filterID, pinned: true))
        XCTAssertFalse(store.setListPinned(id: UUID(), pinned: true))
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(loaded.data.lists.first { $0.id == listID }?.isPinned == true)
        XCTAssertTrue(loaded.data.folders.first { $0.id == folderID }?.isPinned == true)
        XCTAssertTrue(loaded.data.tags.first { $0.id == tagID }?.isPinned == true)
        XCTAssertTrue(loaded.data.filters.first { $0.id == filterID }?.isPinned == true)
    }

    // MARK: - Tag hierarchy defense

    func testTagParentSanitization() {
        let a = TaskTag(name: "A", color: "#fff")
        let b = TaskTag(name: "B", color: "#fff")
        let c = TaskTag(name: "C", color: "#fff")
        var tags = [a, b, c]
        // Self-parent + 2-cycle among B and C.
        tags[1].parentID = tags[2].id
        tags[2].parentID = tags[1].id
        tags.append({ var t = TaskTag(name: "S", color: "#fff"); t.parentID = t.id; return t }())
        let clean = WorkspaceData.sanitizedTagParents(tags)
        XCTAssertEqual(clean.count, 4)
        XCTAssertFalse(clean.contains { $0.parentID != nil && !clean.map(\.id).contains($0.parentID!) })
        // No cycles remain: every chain terminates.
        for tag in clean {
            var seen = Set([tag.id]); var cursor = tag.parentID
            var hops = 0
            while let current = cursor, hops <= clean.count {
                XCTAssertTrue(seen.insert(current).inserted, "cycle at \(current)")
                cursor = clean.first { $0.id == current }?.parentID
                hops += 1
            }
        }
    }

    @MainActor func testSetTagParentValidation() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let root = store.createTag(name: "Root", color: "#fff")
        let child = store.createTag(name: "Child", color: "#fff", parentID: root)
        let grand = store.createTag(name: "Grand", color: "#fff", parentID: child)
        XCTAssertFalse(store.setTagParent(id: root, parentID: grand)) // cycle
        XCTAssertFalse(store.setTagParent(id: root, parentID: root)) // self
        XCTAssertFalse(store.setTagParent(id: root, parentID: UUID())) // unknown
        XCTAssertFalse(store.setTagParent(id: UUID(), parentID: root)) // unknown tag
        XCTAssertTrue(store.setTagParent(id: grand, parentID: nil))
        XCTAssertNil(store.data.tags.first { $0.id == grand }?.parentID)
        XCTAssertTrue(store.setTagParent(id: grand, parentID: root))
        XCTAssertEqual(store.data.tags.first { $0.id == grand }?.parentID, root)
    }

    func testTagHierarchyTraversal() {
        let root = TaskTag(name: "R", color: "#fff")
        var mid = TaskTag(name: "M", color: "#fff"); mid.parentID = root.id
        var leaf = TaskTag(name: "L", color: "#fff"); leaf.parentID = mid.id
        let other = TaskTag(name: "O", color: "#fff")
        let tags = [root, mid, leaf, other]
        XCTAssertEqual(TagHierarchy.roots(in: tags).map(\.id).sorted { "\($0)" < "\($1)" }.count, 2)
        XCTAssertEqual(TagHierarchy.children(of: root.id, in: tags).map(\.id), [mid.id])
        XCTAssertEqual(TagHierarchy.descendants(of: root.id, in: tags).map(\.id), [mid.id, leaf.id])
        XCTAssertEqual(TagHierarchy.ancestors(of: leaf.id, in: tags).map(\.id), [mid.id, root.id])
        XCTAssertTrue(TagHierarchy.isDescendant(leaf.id, of: root.id, in: tags))
        XCTAssertFalse(TagHierarchy.isDescendant(root.id, of: leaf.id, in: tags))
        // Navigation policy: parent matches direct + descendant-tagged tasks.
        let direct = TaskItem(title: "d", tagIDs: [root.id])
        let nested = TaskItem(title: "n", tagIDs: [leaf.id])
        let unrelated = TaskItem(title: "u", tagIDs: [other.id])
        XCTAssertTrue(SmartListEligibility.taskMatchesTag(direct, tagID: root.id, tags: tags))
        XCTAssertTrue(SmartListEligibility.taskMatchesTag(nested, tagID: root.id, tags: tags))
        XCTAssertFalse(SmartListEligibility.taskMatchesTag(unrelated, tagID: root.id, tags: tags))
        XCTAssertTrue(SmartListEligibility.taskMatchesTag(nested, tagID: leaf.id, tags: tags))
        XCTAssertFalse(SmartListEligibility.taskMatchesTag(direct, tagID: leaf.id, tags: tags))
    }

    // MARK: - Merge and delete

    @MainActor func testMergeTagsRewritesRefsAndReparents() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let parent = store.createTag(name: "Parent", color: "#fff")
        let source = store.createTag(name: "Source", color: "#111", parentID: parent)
        let child = store.createTag(name: "Child", color: "#222", parentID: source)
        let target = store.createTag(name: "Target", color: "#333")
        let taskID = store.createTask(title: "T")
        if var t = store.data.tasks.first(where: { $0.id == taskID }) { t.tagIDs = [source, target]; store.updateTask(t) }
        store.settings.defaultTagID = source
        guard let templateID = store.saveTemplate(from: taskID) else { return XCTFail("template") }
        let filterID = store.createFilter(TaskFilter(name: "F", tagIDs: [source, target]))
        XCTAssertTrue(store.mergeTags(source: source, target: target))
        XCTAssertNil(store.data.tags.first { $0.id == source })
        XCTAssertEqual(Set(store.data.tasks.first { $0.id == taskID }?.tagIDs ?? []), [target])
        let template = try XCTUnwrap(store.data.templates.first { $0.id == templateID })
        XCTAssertEqual(template.tagIDs, [target])
        XCTAssertEqual(store.data.filters.first { $0.id == filterID }?.tagIDs, [target])
        XCTAssertEqual(store.settings.defaultTagID, target)
        XCTAssertEqual(store.data.tags.first { $0.id == child }?.parentID, target)
        XCTAssertFalse(store.mergeTags(source: source, target: target))
        XCTAssertFalse(store.mergeTags(source: target, target: target))
        XCTAssertFalse(store.mergeTags(source: target, target: UUID()))
    }

    @MainActor func testMergeIntoDescendantStaysAcyclic() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let source = store.createTag(name: "S", color: "#fff")
        let mid = store.createTag(name: "M", color: "#fff", parentID: source)
        let target = store.createTag(name: "T", color: "#fff", parentID: mid)
        let sibling = store.createTag(name: "Sib", color: "#fff", parentID: source)
        XCTAssertTrue(store.mergeTags(source: source, target: target))
        let tags = store.data.tags
        XCTAssertNil(tags.first { $0.id == source })
        // Target takes the source's (top-level) slot; the chain re-homes.
        XCTAssertNil(tags.first { $0.id == target }?.parentID)
        XCTAssertEqual(tags.first { $0.id == sibling }?.parentID, target)
        XCTAssertEqual(tags.first { $0.id == mid }?.parentID, nil)
        // No cycles anywhere.
        for tag in tags {
            var seen = Set([tag.id]); var cursor = tag.parentID; var hops = 0
            while let current = cursor, hops <= tags.count {
                XCTAssertTrue(seen.insert(current).inserted)
                cursor = tags.first { $0.id == current }?.parentID
                hops += 1
            }
        }
    }

    @MainActor func testDeleteTagCleansEverywhereAndPromotes() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let parent = store.createTag(name: "P", color: "#fff")
        let gone = store.createTag(name: "G", color: "#fff", parentID: parent)
        let child = store.createTag(name: "C", color: "#fff", parentID: gone)
        let taskID = store.createTask(title: "T")
        if var t = store.data.tasks.first(where: { $0.id == taskID }) { t.tagIDs = [gone]; store.updateTask(t) }
        guard let templateID = store.saveTemplate(from: taskID) else { return XCTFail("template") }
        let filterID = store.createFilter(TaskFilter(name: "F", tagIDs: [gone]))
        store.settings.defaultTagID = gone
        store.deleteTag(id: gone)
        XCTAssertNil(store.data.tags.first { $0.id == gone })
        XCTAssertTrue(store.data.tasks.first { $0.id == taskID }?.tagIDs.isEmpty == true)
        XCTAssertTrue(store.data.templates.first { $0.id == templateID }?.tagIDs.isEmpty == true)
        // Saved-filter criteria keep the dead ID as no-match (pruning would
        // broaden the filter); the swept task itself matches nothing.
        XCTAssertEqual(store.data.filters.first { $0.id == filterID }?.tagIDs, [gone])
        let kept = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        XCTAssertFalse(kept.matches(try XCTUnwrap(store.data.tasks.first { $0.id == taskID }), lists: store.data.lists))
        XCTAssertNil(store.settings.defaultTagID)
        XCTAssertEqual(store.data.tags.first { $0.id == child }?.parentID, parent)
        store.deleteTag(id: UUID()) // no-op, no crash
    }

    // MARK: - Filters

    func testLegacyFilterDecodesWithUnchangedMeaning() throws {
        let filterID = UUID()
        let json = """
        {"id":"\(filterID.uuidString)","name":"Old","listIDs":[],"tagIDs":[],
         "priority":"high","dateRule":"today","status":"active","keyword":"hi"}
        """.data(using: .utf8)!
        let filter = try JSONDecoder().decode(TaskFilter.self, from: json)
        XCTAssertEqual(filter.priorities, [.high])
        XCTAssertEqual(filter.dateRules, [.today])
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 8; comps.hour = 12
        let now = cal.date(from: comps)!
        let match = TaskItem(title: "hi there", dueDate: cal.date(byAdding: .hour, value: -1, to: now), priority: .high)
        XCTAssertTrue(filter.matches(match, now: now, calendar: cal))
        let wrong = TaskItem(title: "hi there", dueDate: cal.date(byAdding: .hour, value: -1, to: now), priority: .low)
        XCTAssertFalse(filter.matches(wrong, now: now, calendar: cal))
    }

    func testMultiCriteriaBaseAndOrPolicy() {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 8; comps.hour = 12
        let now = cal.date(from: comps)!
        let due = cal.date(byAdding: .hour, value: 1, to: now)!
        // Base AND across dimensions: every set dimension must pass.
        let filter = TaskFilter(name: "F", tagIDs: [], priorities: [.high, .low], dateRules: [.today, .tomorrow],
                                kinds: [.task, .note], tagMode: .all)
        let ok = TaskItem(title: "T", dueDate: due, priority: .low)
        XCTAssertTrue(filter.matches(ok, now: now, calendar: cal))
        // …while values inside one dimension OR.
        let badPriority = TaskItem(title: "T", dueDate: due, priority: .medium)
        XCTAssertFalse(filter.matches(badPriority, now: now, calendar: cal))
        let note = TaskItem(title: "T", kind: .note, dueDate: due, priority: .high)
        XCTAssertTrue(filter.matches(note, now: now, calendar: cal))
        let kindOnly = TaskFilter(name: "K", kinds: [.note])
        XCTAssertFalse(kindOnly.matches(ok, now: now, calendar: cal))
    }

    func testTagModes() {
        let a = UUID(), b = UUID()
        let both = TaskItem(title: "B", tagIDs: [a, b])
        let one = TaskItem(title: "O", tagIDs: [a])
        let none = TaskItem(title: "N", tagIDs: [])
        XCTAssertTrue(TaskFilter(name: "A", tagIDs: [a], tagMode: .any).matches(both))
        XCTAssertTrue(TaskFilter(name: "A", tagIDs: [a, b], kinds: [], tagMode: .all).matches(both))
        XCTAssertFalse(TaskFilter(name: "A", tagIDs: [a, b], kinds: [], tagMode: .all).matches(one))
        XCTAssertTrue(TaskFilter(name: "A", kinds: [], tagMode: .none).matches(none))
        XCTAssertFalse(TaskFilter(name: "A", kinds: [], tagMode: .none).matches(one))
        XCTAssertTrue(TaskFilter(name: "A", kinds: [], tagMode: .anyTagged).matches(one))
        XCTAssertFalse(TaskFilter(name: "A", kinds: [], tagMode: .anyTagged).matches(none))
    }

    func testWeekMonthRepeatingCustomRules() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday start
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 4; comps.hour = 12 // a Wednesday
        let now = cal.date(from: comps)!
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now)! }
        // Week of Nov 2–8 (Mon–Sun).
        XCTAssertTrue(TaskFilter.dateRuleMatches(.thisWeek, task: TaskItem(title: "T", dueDate: day(-1)), now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.thisWeek, task: TaskItem(title: "T", dueDate: day(-3)), now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.nextWeek, task: TaskItem(title: "T", dueDate: day(6)), now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.lastWeek, task: TaskItem(title: "T", dueDate: day(-3)), now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.thisMonth, task: TaskItem(title: "T", dueDate: day(20)), now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.thisMonth, task: TaskItem(title: "T", dueDate: day(30)), now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.lastMonth, task: TaskItem(title: "T", dueDate: day(-4)), now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.repeating, task: TaskItem(title: "T", recurrence: .daily), now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.repeating, task: TaskItem(title: "T"), now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.thisWeek, task: TaskItem(title: "T"), now: now, calendar: cal))
        // Custom range is day-inclusive on both ends.
        let from = day(-1), to = day(1)
        XCTAssertTrue(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T", dueDate: from), customFrom: from, customTo: to, now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T", dueDate: to), customFrom: from, customTo: to, now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T", dueDate: day(2)), customFrom: from, customTo: to, now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T", dueDate: day(9)), customFrom: from, customTo: nil, now: now, calendar: cal))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T", dueDate: day(-9)), customFrom: nil, customTo: to, now: now, calendar: cal))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.custom, task: TaskItem(title: "T"), customFrom: from, customTo: to, now: now, calendar: cal))
    }

    func testFilterRuleJSONRoundTrip() throws {
        // The exact document shape the QA fixture generator emits.
        let json = """
        {"type":"and","children":[{"type":"or","children":[{"type":"condition","condition":{"kind":"priority","priority":"high"}},{"type":"condition","condition":{"kind":"date","dateRule":"today"}}]},{"type":"not","child":{"type":"condition","condition":{"kind":"noTags"}}}]}
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(FilterRule.self, from: json)
        if case .and(let top) = rule { XCTAssertEqual(top.count, 2) } else { return XCTFail("root") }
        let filter = TaskFilter(name: "R", priorities: [.high], dateRules: [.custom],
                                customDateFrom: Date(timeIntervalSince1970: 1_000_000),
                                customDateTo: Date(timeIntervalSince1970: 2_000_000),
                                isPinned: true, ruleRoot: rule)
        let back = try JSONDecoder().decode(TaskFilter.self, from: JSONEncoder().encode(filter))
        XCTAssertEqual(filter, back)
    }

    func testRuleEvaluationSemantics() {
        let tagged = TaskItem(title: "match me urgent", tagIDs: [], priority: .high)
        let plain = TaskItem(title: "nothing", priority: .low)
        let cond = { (kind: FilterConditionKind) in FilterRule.condition(FilterCondition(kind: kind)) }
        // Empty groups match everything; NOT inverts.
        XCTAssertTrue(TaskFilter.evaluate(.and([]), task: plain, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        XCTAssertTrue(TaskFilter.evaluate(.or([]), task: plain, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(.not(.and([])), task: plain, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        // AND/OR/NOT composition.
        let rule = FilterRule.and([
            .or([.condition(FilterCondition(kind: .priority, priority: .high)),
                 .condition(FilterCondition(kind: .keyword, keyword: "match"))]),
            .not(.condition(FilterCondition(kind: .noTags)))
        ])
        var withTag = tagged; withTag.tagIDs = [UUID()]
        XCTAssertTrue(TaskFilter.evaluate(rule, task: withTag, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(rule, task: tagged, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(rule, task: plain, filter: TaskFilter(name: "F"), lists: [], now: Date(), calendar: .current))
        _ = cond
    }

    @MainActor func testRuleModeReplacesCriteriaAndGuardsTrash() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let taskID = store.createTask(title: "keep keyword", body: "secret")
        let rule = FilterRule.condition(FilterCondition(kind: .keyword, keyword: "keep"))
        let filterID = store.createFilter(TaskFilter(name: "R", status: .completed, keyword: "zzz-unmatched", ruleRoot: rule))
        let filter = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == taskID })
        // Criteria (keyword/status) are ignored in rule mode; the task matches.
        XCTAssertTrue(filter.matches(task, lists: store.data.lists))
        store.trashTask(id: taskID)
        let trashed = try XCTUnwrap(store.data.tasks.first { $0.id == taskID })
        XCTAssertFalse(filter.matches(trashed, lists: store.data.lists))
    }

    @MainActor func testExplicitListSelectionOverridesExclusion() throws {
        let (store, url) = self.store(); defer { cleanup(url) }
        let archivedID = store.createList(name: "Old", color: "#fff")
        // Create inside, then archive: the store layer refuses every move
        // INTO an archived list (updateTask and moveTasksToList alike), so a
        // resident can only predate the archive.
        let taskID = store.createTask(title: "T", listID: archivedID)
        XCTAssertTrue(store.setListArchived(id: archivedID, archived: true))
        if var t = store.data.tasks.first(where: { $0.id == taskID }) { t.listID = archivedID; store.updateTask(t) }
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == taskID })
        XCTAssertEqual(task.listID, archivedID)
        XCTAssertFalse(TaskFilter(name: "Broad").matches(task, lists: store.data.lists))
        XCTAssertTrue(TaskFilter(name: "Explicit", listIDs: [archivedID]).matches(task, lists: store.data.lists))
    }
}
