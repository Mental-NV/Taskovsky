import XCTest
import TaskovskyDomain

final class MobileContractTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!; value.firstWeekday = 2
        return value
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var now: Date { date("2026-11-09T12:00:00Z") }
    private func ids(_ tasks: [TaskItem]) -> [UUID] { tasks.map(\.id) }

    func testEndReminderTracksTimedDurationAndKeepsExistingReminderPolicy() throws {
        let start = now, due = start + 3_600
        let task = TaskItem(title: "Workshop", dueDate: due, hasDueTime: true, reminderDate: due,
                            reminderFollowsSchedule: false, scheduledDuration: .init(start: start, end: due))
        let settings = AppSettings()
        var draft = TaskScheduleEdit(task: task, settings: settings, calendar: calendar, now: now)
        XCTAssertEqual(draft.timedDurationEnd, due)
        draft.remindsAtEnd = true
        let enabled = try draft.applying(to: task, settings: settings)
        XCTAssertEqual(enabled.effectiveReminderDates, [due])
        XCTAssertEqual(enabled.reminderDates, task.reminderDates)
        XCTAssertTrue(enabled.endReminderEnabled)

        draft = TaskScheduleEdit(task: enabled, settings: settings, calendar: calendar, now: now)
        draft.setEnd(due + 900)
        let edited = try draft.applying(to: enabled, settings: settings)
        XCTAssertEqual(edited.effectiveReminderDates, [due, due + 900])
        XCTAssertEqual(edited.endReminderDate, due + 900)
        let movedStart = try XCTUnwrap(CalendarScheduling.prepared(.resizeStart(start + 900), to: edited,
                                                                   displayCalendar: calendar, settings: settings, policyCalendar: calendar))
        XCTAssertEqual(movedStart.effectiveReminderDates, edited.effectiveReminderDates)
        let movedEnd = try XCTUnwrap(CalendarScheduling.prepared(.resizeEnd(due + 1_800), to: movedStart,
                                                                 displayCalendar: calendar, settings: settings, policyCalendar: calendar))
        XCTAssertEqual(movedEnd.reminderDates, [due + 900])
        XCTAssertEqual(movedEnd.endReminderDate, due + 1_800)
        XCTAssertEqual(CalendarScheduleSnapshot(edited).restoring(on: movedEnd).effectiveReminderDates, edited.effectiveReminderDates)

        draft = TaskScheduleEdit(task: movedEnd, settings: settings, calendar: calendar, now: now)
        draft.setDuration(false, defaultMinutes: 30)
        let point = try draft.applying(to: movedEnd, settings: settings)
        XCTAssertFalse(point.endReminderEnabled)
        XCTAssertNil(point.endReminderDate)
        XCTAssertEqual(point.reminderDates, movedEnd.reminderDates)
    }

    func testEndReminderSurvivesOccurrenceOverrideAndFollowsTheNextCycle() throws {
        let due = now + 3_600
        var task = TaskItem(title: "Daily workshop", dueDate: due, hasDueTime: true, recurrence: .daily,
                            scheduledDuration: .init(start: now, end: due))
        task.endReminderEnabled = true
        let settings = AppSettings()
        let shifted = try XCTUnwrap(CalendarScheduling.prepared(.move(start: now + 900, allDay: false), to: task,
                                                                displayCalendar: calendar, settings: settings,
                                                                policyCalendar: calendar, scope: .currentOccurrence, in: [task]))
        XCTAssertEqual(shifted.endReminderDate, due + 900)
        let encoded = try JSONEncoder().encode(WorkspaceData(tasks: [shifted]))
        let reloaded = try XCTUnwrap(JSONDecoder().decode(WorkspaceData.self, from: encoded).tasks.first)
        let restored = try XCTUnwrap(CalendarScheduling.prepared(.restoreOccurrence, to: reloaded,
                                                                  displayCalendar: calendar, settings: settings,
                                                                  policyCalendar: calendar, in: [reloaded]))
        XCTAssertEqual(restored.endReminderDate, due)
        let next = try XCTUnwrap(CalendarScheduling.prepared(.skipOccurrence, to: reloaded,
                                                              displayCalendar: calendar, settings: settings,
                                                              policyCalendar: calendar, in: [reloaded]))
        XCTAssertEqual(next.endReminderDate, due + 86_400)
        XCTAssertEqual(next.effectiveReminderDates, [due + 86_400])
    }

    func testTaskCountdownUsesCivilDaysAndUpdatesTimedDeadlines() {
        let timed = TaskItem(title: "Timed", dueDate: now + 90 * 60, hasDueTime: true)
        XCTAssertEqual(TaskDueCountdown.label(for: timed, now: now, calendar: calendar), "1h 30m left")
        XCTAssertEqual(TaskDueCountdown.label(for: timed, now: now + 60, calendar: calendar), "1h 29m left")
        XCTAssertEqual(TaskDueCountdown.label(for: timed, now: now + 90 * 60, calendar: calendar), "Due now")
        XCTAssertEqual(TaskDueCountdown.label(for: timed, now: now + 91 * 60, calendar: calendar), "1m overdue")
        let beforeDST = date("2026-03-07T05:00:00Z")
        let afterDST = date("2026-03-09T04:00:00Z")
        let allDay = TaskItem(title: "Civil date", dueDate: afterDST, timeZoneID: "America/New_York")
        XCTAssertEqual(TaskDueCountdown.label(for: allDay, now: beforeDST, calendar: calendar), "2 days left")
        XCTAssertEqual(TaskDueCountdown.label(for: allDay, now: afterDST + 90, calendar: calendar), "Due today")
        XCTAssertEqual(TaskDueCountdown.label(for: allDay, now: afterDST + 86_400, calendar: calendar), "1 day overdue")
        let nearMidnight = date("2026-11-10T23:45:00Z")
        let later = TaskItem(title: "Tomorrow in minutes", dueDate: nearMidnight + 1_800, hasDueTime: true)
        XCTAssertEqual(TaskDueCountdown.label(for: later, now: nearMidnight, calendar: calendar), "30m left")
        var finished = timed
        finished.completedAt = now
        XCTAssertNil(TaskDueCountdown.label(for: finished, now: now, calendar: calendar))
        XCTAssertNil(TaskDueCountdown.label(for: TaskItem(title: "Undated"), now: now, calendar: calendar))
    }

    func testScopedBoardWeekDateMovePreservesInclusiveSpanAndTimedDueClock() throws {
        let days = CalendarDates.days(from: now, count: 7, calendar: calendar)
        let range = TaskItem(title: "Workshop", dueDate: days[2],
                             scheduledDuration: .init(start: days[0], end: days[2], isAllDay: true))
        let overdue = TaskItem(title: "Past", dueDate: days[0].addingTimeInterval(-86_400))
        let timedDue = days[1].addingTimeInterval(14 * 3_600 + 7 * 60)
        let timed = TaskItem(title: "Review", dueDate: timedDue, hasDueTime: true,
                             scheduledDuration: .init(start: timedDue.addingTimeInterval(-3_600), end: timedDue, isAllDay: false))
        let done = TaskItem(title: "Finished", dueDate: days[0], completedAt: now)
        let note = TaskItem(title: "Notes", kind: .note, dueDate: days[0])
        let board = ScopedBoardProjection(destination: .week, grouping: .date,
                                          in: WorkspaceData(tasks: [range, overdue, timed, done, note]),
                                          now: now, calendar: calendar)
        XCTAssertEqual(board.columns.map(\.id), [.overdue] + days.map(ScopedBoardColumn.ID.date))
        XCTAssertEqual(board.columns[0].tasks.map(\.id), [overdue.id])
        XCTAssertEqual(board.columns[3].tasks.map(\.id), [range.id])
        XCTAssertNil(board.move(range.id, to: .overdue))
        XCTAssertNil(board.move(done.id, to: .date(days[3])))
        XCTAssertNil(board.move(note.id, to: .date(days[3])))
        guard case .schedule(let rangeMove) = board.move(range.id, to: .date(days[3])),
              case .schedule(let timedMove) = board.move(timed.id, to: .date(days[3])) else {
            return XCTFail("Expected calendar moves")
        }
        let movedRange = try XCTUnwrap(CalendarScheduling.applying(rangeMove, to: range, displayCalendar: calendar))
        XCTAssertEqual(movedRange.dueDate, days[3])
        XCTAssertEqual(movedRange.scheduledDuration?.start, days[1])
        XCTAssertEqual(movedRange.scheduledDuration?.end, days[3])
        XCTAssertEqual(movedRange.scheduledDuration?.isAllDay, true)
        let movedTimed = try XCTUnwrap(CalendarScheduling.applying(timedMove, to: timed, displayCalendar: calendar))
        let expectedDue = days[3].addingTimeInterval(14 * 3_600 + 7 * 60)
        XCTAssertEqual(movedTimed.dueDate, expectedDue)
        XCTAssertEqual(movedTimed.scheduledDuration?.start, expectedDue.addingTimeInterval(-3_600))
    }

    func testScopedBoardFolderAndTagListMovesStayWithinAvailableColumns() {
        let folder = ListFolder(name: "Projects")
        let tag = TaskTag(name: "Design", color: "#334455")
        let work = TaskList(name: "Work", color: "#334455", folderID: folder.id)
        let upcoming = TaskList(name: "Upcoming", color: "#334455", folderID: folder.id, showsInSmartLists: false)
        let archive = TaskList(name: "Old", color: "#334455", folderID: folder.id, isArchived: true)
        let personal = TaskList(name: "Personal", color: "#334455")
        let source = TaskItem(title: "Sketch", listID: work.id, tagIDs: [tag.id])
        let old = TaskItem(title: "Old sketch", listID: archive.id, tagIDs: [tag.id])
        let other = TaskItem(title: "Other", listID: personal.id)
        let data = WorkspaceData(tasks: [source, old, other], lists: [work, upcoming, archive, personal],
                                 tags: [tag], folders: [folder])
        let folderBoard = ScopedBoardProjection(destination: .folder(folder.id), grouping: .list, in: data,
                                                now: now, calendar: calendar)
        XCTAssertEqual(folderBoard.columns.map(\.id), [.list(work.id), .list(upcoming.id)])
        XCTAssertEqual(folderBoard.columns.flatMap(\.tasks).map(\.id), [source.id])
        XCTAssertNil(folderBoard.move(source.id, to: .list(personal.id)))
        guard case .list(let target) = folderBoard.move(source.id, to: .list(upcoming.id)) else {
            return XCTFail("Expected a list move")
        }
        XCTAssertEqual(target, upcoming.id)
        let tagBoard = ScopedBoardProjection(destination: .tag(tag.id), grouping: .list, in: data,
                                             now: now, calendar: calendar)
        XCTAssertEqual(tagBoard.columns.map(\.id), [.list(nil), .list(work.id), .list(upcoming.id), .list(personal.id)])
        XCTAssertEqual(tagBoard.columns.flatMap(\.tasks).map(\.id), [source.id])
        XCTAssertNil(tagBoard.move(old.id, to: .list(work.id)))
        guard case .list(let inbox) = tagBoard.move(source.id, to: .list(nil)) else {
            return XCTFail("Expected an Inbox move")
        }
        XCTAssertNil(inbox)
    }

    func testTaskSectionsRetainOrderedGroupsAndKeepTasksWhenRemoved() throws {
        let list = TaskList(name: "Reading", color: "#334455")
        let parent = TaskItem(title: "Novel", listID: list.id)
        let child = TaskItem(title: "Chapter", body: "Keep this draft", listID: list.id, parentID: parent.id)
        let first = TaskSection(name: "  Novels  ")
        let second = TaskSection(name: "History")
        var data = WorkspaceData(tasks: [parent, child], lists: [list])
        func apply(_ operation: TaskSectionChange.Operation) -> Bool? {
            TaskSectionChange(listID: list.id, operation: operation).apply(to: &data, now: now)
        }
        XCTAssertEqual(apply(.create(first)), true)
        XCTAssertEqual(apply(.create(second)), true)
        XCTAssertEqual(data.lists[0].sections.map(\.name), ["Novels", "History"])
        XCTAssertEqual(apply(.rename(second.id, name: "Modern history")), true)
        XCTAssertEqual(apply(.reorder(second.id, relativeTo: first.id, after: false)), true)
        XCTAssertEqual(apply(.reorder(second.id, relativeTo: first.id, after: false)), false)
        XCTAssertEqual(apply(.assign(taskID: parent.id, sectionID: first.id)), true)
        XCTAssertNil(apply(.assign(taskID: child.id, sectionID: second.id)))
        let groups = TaskSectionGroup.project([child], for: data.lists[0], in: data)
        XCTAssertEqual(groups.map(\.id), [nil, second.id, first.id])
        XCTAssertEqual(groups.last?.tasks.map(\.id), [child.id])

        XCTAssertEqual(apply(.remove(first.id)), true)
        XCTAssertEqual(data.tasks.map(\.id), [parent.id, child.id])
        XCTAssertNil(data.tasks[0].sectionID)
        XCTAssertEqual(data.tasks[1], child)
        XCTAssertEqual(data.tasks[0].updatedAt, now)
        data.lists[0].isArchived = true
        XCTAssertNil(apply(.remove(second.id)))
    }

    func testSectionCaptureAndBatchMoveValidateTargetsBeforeSaving() throws {
        let list = TaskList(name: "Work", color: "#445566")
        let other = TaskList(name: "Personal", color: "#556677")
        let section = TaskSection(name: "Planning")
        let first = TaskItem(title: "First", listID: list.id)
        let second = TaskItem(title: "Second", listID: list.id)
        var data = WorkspaceData(tasks: [first, second], lists: [list, other])
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .create(section)).apply(to: &data, now: now), true)

        let invalid = TaskSectionChange(listID: list.id, operation: .assignTasks([first.id, UUID()], sectionID: section.id))
        XCTAssertNil(invalid.apply(to: &data, now: now))
        XCTAssertEqual(data.tasks, [first, second])
        let valid = TaskSectionChange(listID: list.id, operation: .assignTasks([first.id, second.id], sectionID: section.id))
        XCTAssertEqual(valid.apply(to: &data, now: now), true)
        XCTAssertEqual(data.tasks.map(\.sectionID), [section.id, section.id])

        let settings = AppSettings()
        var input = TaskCaptureInput.start(destination: .list(list.id), workspace: data,
                                           settings: settings, now: now, calendar: calendar)
        input.title = "New in Planning"
        input.sectionID = section.id
        let created = try input.task(id: UUID(), now: now, workspace: data, settings: settings, calendar: calendar)
        XCTAssertEqual(created.sectionID, section.id)
        input.listID = other.id
        XCTAssertNil(input.sectionID)
        input.sectionID = section.id
        XCTAssertThrowsError(try input.task(id: UUID(), now: now, workspace: data, settings: settings, calendar: calendar))
    }

    func testTaskSectionListCopyRemapsMembershipAndCrossListMovesClearIt() throws {
        let list = TaskList(name: "Work", color: "#445566")
        let other = TaskList(name: "Personal", color: "#556677")
        let section = TaskSection(name: "Drafts")
        let root = TaskItem(title: "Outline", listID: list.id)
        let child = TaskItem(title: "Gather references", listID: list.id, parentID: root.id)
        var data = WorkspaceData(tasks: [root, child], lists: [list, other])
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .create(section)).apply(to: &data, now: now), true)
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .assign(taskID: root.id, sectionID: section.id)).apply(to: &data, now: now), true)
        let copyID = UUID()
        XCTAssertTrue(ListOrganization.duplicateList(list.id, copyID: copyID, in: &data, now: now))
        let copy = try XCTUnwrap(data.lists.first { $0.id == copyID })
        let copiedSection = try XCTUnwrap(copy.sections.first)
        XCTAssertNotEqual(copiedSection.id, section.id)
        XCTAssertEqual(copiedSection.name, section.name)
        let copied = data.tasks.filter { $0.listID == copyID }
        XCTAssertEqual(copied.first?.sectionID, copiedSection.id)
        XCTAssertEqual(copied.last?.parentID, copied.first?.id)

        data.tasks[0].listID = other.id
        XCTAssertNil(data.tasks[0].sectionID)
        ListOrganization.deleteList(copyID, in: &data, now: now)
        XCTAssertTrue(data.tasks.filter { copied.map(\.id).contains($0.id) }.allSatisfy { $0.listID == nil && $0.sectionID == nil })
    }

    func testListSectionsUseAProtectedCollectionAndLegacyFilesStayReadable() throws {
        let list = TaskList(name: "Work", color: "#445566")
        var data = WorkspaceData(lists: [list])
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        func encoded() throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(data)) as? [String: Any])
        }
        let legacy = try encoder.encode(data)
        XCTAssertTrue(try encoded()["tasks"] is [Any])
        XCTAssertEqual(try decoder.decode(WorkspaceData.self, from: legacy), data)
        let section = TaskSection(name: "Planning")
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .create(section)).apply(to: &data, now: now), true)
        var protected = try encoded()
        let envelope = try XCTUnwrap(protected["tasks"] as? [String: Any])
        XCTAssertEqual(envelope["format"] as? String, "listSectionsV1")
        XCTAssertEqual(try decoder.decode(WorkspaceData.self, from: encoder.encode(data)), data)
        protected["tasks"] = envelope["records"]
        let unprotected = try JSONSerialization.data(withJSONObject: protected)
        XCTAssertThrowsError(try decoder.decode(WorkspaceData.self, from: unprotected))
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .remove(section.id)).apply(to: &data, now: now), true)
        XCTAssertTrue(try encoded()["tasks"] is [Any])
    }

    func testTaskTimelineScopesKeepUndatedTasksAndExcludeArchivedLists() throws {
        let folder = ListFolder(name: "Project")
        let list = TaskList(name: "Plan", color: "#334455", folderID: folder.id)
        let other = TaskList(name: "Review", color: "#556677", folderID: folder.id)
        let archived = TaskList(name: "Archived", color: "#333333", folderID: folder.id, isArchived: true)
        let outside = TaskList(name: "Elsewhere", color: "#111111")
        let anchor = calendar.startOfDay(for: now)
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: anchor))
        let far = try XCTUnwrap(calendar.date(byAdding: .day, value: 30, to: anchor))
        let point = TaskItem(title: "Milestone", listID: list.id, dueDate: anchor)
        let range = TaskItem(title: "Delivery", listID: other.id, dueDate: next,
                             scheduledDuration: .init(start: anchor, end: next, isAllDay: true))
        let undated = TaskItem(title: "Arrange", listID: list.id)
        let history = TaskItem(title: "Old undated", listID: list.id, completedAt: now)
        let hidden = TaskItem(title: "Archived date", listID: archived.id, dueDate: anchor)
        let unrelated = TaskItem(title: "Unrelated date", listID: outside.id, dueDate: next)
        let later = TaskItem(title: "Future", listID: list.id, dueDate: far)
        let filter = TaskFilter(name: "Review", listIDs: [other.id, archived.id])
        let data = WorkspaceData(tasks: [point, range, undated, history, hidden, unrelated, later],
                                 lists: [list, other, archived, outside], filters: [filter], folders: [folder])
        let window = TaskTimelineScale.day.window(focus: now, calendar: calendar)
        let regular = TaskTimelineProjection(scope: .list(list.id), data: data, window: window, now: now)
        XCTAssertEqual(regular.rows.map(\.id), [point.id])
        XCTAssertEqual(regular.undated.map(\.id), [undated.id])
        XCTAssertTrue(try XCTUnwrap(regular.rows.first).isPoint)
        let grouped = TaskTimelineProjection(scope: .folder(folder.id), data: data, window: window, now: now)
        XCTAssertEqual(Set(grouped.rows.map(\.id)), [point.id, range.id])
        XCTAssertEqual(grouped.undated.map(\.id), [undated.id])
        let filtered = TaskTimelineProjection(scope: .filter(filter.id), data: data, window: window, now: now)
        let bar = try XCTUnwrap(filtered.rows.first)
        XCTAssertEqual(filtered.rows.map(\.id), [range.id])
        XCTAssertEqual(bar.start, 0)
        XCTAssertEqual(bar.end, 2)
        XCTAssertFalse(bar.isPoint)
        XCTAssertTrue(TaskTimelineProjection(scope: .folder(UUID()), data: data, window: window, now: now).rows.isEmpty)
    }

    func testTimelineZoomKeepsFractionalDayUnderViewportAnchor() {
        let standard = TaskTimelineZoom.standard
        let zoom = standard.scaled(by: 1.5)
        XCTAssertEqual(zoom.percent, 150)
        XCTAssertEqual(zoom.scaled(by: 100).percent, 300)
        XCTAssertFalse(zoom.scaled(by: 100).canZoomIn)
        XCTAssertEqual(zoom.scaled(by: 0.001).percent, 75)
        XCTAssertFalse(zoom.scaled(by: 0.001).canZoomOut)
        XCTAssertEqual(zoom.scaled(by: .infinity), zoom)
        let anchor = TaskTimelineZoomAnchor(contentX: 233, dayWidth: 18, viewportX: 91)
        let scaledOrigin = anchor.viewportOrigin(contentStart: 12, dayWidth: 27)
        XCTAssertEqual((scaledOrigin + 91 - 12) / 27, 233.0 / 18.0, accuracy: 0.000001)
    }

    func testTimelineColorOptionsKeepMembershipAndSchedule() throws {
        let list = TaskList(name: "Work", color: "#314159")
        let tag = TaskTag(name: "Review", color: "#209080")
        let date = calendar.startOfDay(for: now)
        let task = TaskItem(title: "Draft", listID: list.id, tagIDs: [tag.id], dueDate: date, priority: .high)
        let untagged = TaskItem(title: "Decide", listID: list.id, dueDate: date)
        let data = WorkspaceData(tasks: [task, untagged], lists: [list], tags: [tag])
        let window = TaskTimelineScale.day.window(focus: date, calendar: calendar)
        let projected = CalendarColorMode.allCases.map {
            TaskTimelineProjection(scope: .list(list.id), data: data, window: window, now: now, colorBy: $0)
        }
        let marked = try projected.map { projection in try XCTUnwrap(projection.rows.first { $0.id == task.id }) }
        XCTAssertEqual(marked.map { $0.entry.color }, ["#314159", "#209080", "#E65757"])
        XCTAssertTrue(marked.allSatisfy { $0.start == 0 && $0.isPoint })
        XCTAssertEqual(projected[1].rows.first { $0.id == untagged.id }?.entry.color, "#314159")
    }

    func testTimelineArrangeUsesCivilDatesAndSnapsTimeAcrossDST() throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let day = try XCTUnwrap(local.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let window = TaskTimelineScale.day.window(focus: day, calendar: local)
        let task = TaskItem(title: "Undated")
        let next = try XCTUnwrap(local.date(byAdding: .day, value: 1, to: day))
        let week = try XCTUnwrap(window.arrange(at: 1.4, scale: .week))
        let allDay = try XCTUnwrap(CalendarScheduling.applying(week, to: task, displayCalendar: local))
        XCTAssertEqual(allDay.dueDate, next)
        XCTAssertFalse(allDay.hasDueTime)
        XCTAssertNil(allDay.scheduledDuration)
        let quarter = try XCTUnwrap(local.date(bySettingHour: 15, minute: 15, second: 0, of: day))
        let x = window.offset(of: quarter.addingTimeInterval(240))
        let precise = try XCTUnwrap(window.arrange(at: x, scale: .day))
        let timed = try XCTUnwrap(CalendarScheduling.applying(precise, to: task, displayCalendar: local))
        XCTAssertEqual(timed.dueDate, quarter)
        XCTAssertTrue(timed.hasDueTime)
        XCTAssertNil(timed.scheduledDuration)
        XCTAssertNil(window.arrange(at: Double(window.dates.count), scale: .week))
        XCTAssertNil(window.arrange(at: -0.01, scale: .day))
    }

    func testTimelineGroupsByListAndInheritsSectionsFromHiddenParents() throws {
        let folder = ListFolder(name: "Launch")
        let build = TaskSection(name: "Build")
        let review = TaskSection(name: "Review")
        let first = TaskList(name: "Production", color: "#334455", folderID: folder.id)
        let second = TaskList(name: "Coordination", color: "#334455", folderID: folder.id)
        let date = calendar.startOfDay(for: now)
        let parent = TaskItem(title: "Hidden parent", listID: first.id)
        let child = TaskItem(title: "Visible child", listID: first.id, dueDate: date, parentID: parent.id)
        let buildTask = TaskItem(title: "Visible build", listID: first.id, dueDate: date)
        let unassigned = TaskItem(title: "Visible unassigned", listID: first.id, dueDate: date)
        let coordinator = TaskItem(title: "Visible coordination", listID: second.id, dueDate: date)
        let inbox = TaskItem(title: "Visible inbox", dueDate: date)
        let filter = TaskFilter(name: "Visible", keyword: "Visible")
        var data = WorkspaceData(tasks: [child, parent, buildTask, unassigned, coordinator, inbox], lists: [second, first],
                                 filters: [filter], folders: [folder])
        let changes: [TaskSectionChange.Operation] = [
            .create(build), .create(review), .assign(taskID: parent.id, sectionID: review.id),
            .assign(taskID: buildTask.id, sectionID: build.id)
        ]
        for change in changes {
            XCTAssertEqual(TaskSectionChange(listID: first.id, operation: change).apply(to: &data, now: now), true)
        }
        let window = TaskTimelineScale.day.window(focus: date, calendar: calendar)
        let scoped = TaskTimelineProjection(scope: .list(first.id), data: data, window: window, now: now)
        XCTAssertEqual(scoped.groups.compactMap(\.title), ["No Section", "Build", "Review"])
        XCTAssertEqual(scoped.groups.flatMap(\.rows).map(\.id), [unassigned.id, buildTask.id, child.id])
        let folderProjection = TaskTimelineProjection(scope: .folder(folder.id), data: data, window: window, now: now)
        XCTAssertEqual(folderProjection.groups.compactMap(\.title),
                       ["Coordination", "Production · No Section", "Production · Build", "Production · Review"])
        let filtered = TaskTimelineProjection(scope: .filter(filter.id), data: data, window: window, now: now)
        XCTAssertEqual(filtered.groups.first?.rows.map(\.id), [inbox.id])
        XCTAssertEqual(filtered.groups.last?.rows.map(\.id), [child.id])
    }

    func testTimelineDragPreservesCivilSpanAndSnapsTimedDayEdits() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))
        let list = TaskList(name: "Workshop", color: "#314159")
        let span = TaskItem(title: "Three days", listID: list.id, dueDate: end,
                            scheduledDuration: .init(start: start, end: end, isAllDay: true))
        let timedStart = try XCTUnwrap(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: end))
        let timedEnd = timedStart.addingTimeInterval(3_600)
        var timed = TaskItem(title: "One hour", listID: list.id, dueDate: timedEnd,
                             scheduledDuration: .init(start: timedStart, end: timedEnd))
        timed.hasDueTime = true
        var data = WorkspaceData(); data.lists = [list]; data.tasks = [span, timed]
        let window = TaskTimelineScale.day.window(focus: start, calendar: calendar)
        let rows = TaskTimelineProjection(scope: .list(list.id), data: data, window: window, now: start).rows
        let spanRow = try XCTUnwrap(rows.first { $0.id == span.id })
        let timedRow = try XCTUnwrap(rows.first { $0.id == timed.id })

        XCTAssertEqual(window.captureDay(at: 1.99), calendar.date(byAdding: .day, value: 1, to: start))
        XCTAssertNil(window.captureDay(at: Double(window.dates.count)))
        XCTAssertNil(window.adjust(.move, entry: spanRow.entry, by: 0.49, scale: .week))
        XCTAssertNil(window.adjust(.move, entry: spanRow.entry, by: -1, scale: .week))
        let move = try XCTUnwrap(window.adjust(.move, entry: spanRow.entry, by: 1, scale: .week))
        let moved = try XCTUnwrap(CalendarScheduling.applying(move.operation, to: span, displayCalendar: calendar))
        XCTAssertEqual(moved.scheduledDuration?.start, calendar.date(byAdding: .day, value: 1, to: start))
        XCTAssertEqual(moved.dueDate, calendar.date(byAdding: .day, value: 1, to: end))
        let resize = try XCTUnwrap(window.adjust(.resizeEnd, entry: spanRow.entry, by: -2, scale: .week))
        let resized = try XCTUnwrap(CalendarScheduling.applying(resize.operation, to: span, displayCalendar: calendar))
        XCTAssertEqual(resized.dueDate, start)
        XCTAssertEqual(resized.scheduledDuration?.start, start)

        let timedMove = try XCTUnwrap(window.adjust(.move, entry: timedRow.entry, by: 0.022, scale: .day))
        XCTAssertEqual(timedMove.date, timedStart.addingTimeInterval(1_800))
        let movedTime = try XCTUnwrap(CalendarScheduling.applying(timedMove.operation, to: timed, displayCalendar: calendar))
        XCTAssertEqual(movedTime.scheduledDuration?.end, timedEnd.addingTimeInterval(1_800))
        let coarseResize = try XCTUnwrap(window.adjust(.resizeEnd, entry: timedRow.entry, by: 1, scale: .week))
        XCTAssertEqual(calendar.component(.hour, from: coarseResize.date), 10)
        XCTAssertEqual(calendar.component(.day, from: coarseResize.date), 10)
    }

    func testTaskTimelineTicksAndFractionsFollowCivilDaysAcrossDST() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let focus = date("2026-03-07T17:00:00Z")
        let window = TaskTimelineScale.day.window(focus: focus, calendar: local)
        let days = window.dates
        XCTAssertEqual(window.marks, days)
        XCTAssertEqual(window.offset(of: days[2]), 2)
        XCTAssertEqual(days[2].timeIntervalSince(days[1]), 23 * 3600)
        XCTAssertEqual(window.offset(of: days[1].addingTimeInterval(11.5 * 3600)), 1.5, accuracy: 0.0001)
        let interval = try XCTUnwrap(window.interval)
        XCTAssertEqual(window.offset(of: interval.end), 14)
        XCTAssertEqual(window.date(at: 1.5), days[1].addingTimeInterval(11.5 * 3600))
        XCTAssertEqual(window.date(at: 14), interval.end)
        XCTAssertNil(window.date(at: -1))
        XCTAssertNil(window.date(at: .infinity))
        let task = TaskItem(title: "Spans window", listID: nil, dueDate: days[3],
                            scheduledDuration: .init(start: days[0].addingTimeInterval(-3_600), end: days[3], isAllDay: false))
        let filter = TaskFilter(name: "Everything", status: .all)
        let data = WorkspaceData(tasks: [task], filters: [filter])
        let row = try XCTUnwrap(TaskTimelineProjection(scope: .filter(filter.id), data: data, window: window, now: focus).rows.first)
        XCTAssertEqual(row.start, 0)
        XCTAssertEqual(row.end, 3)
        XCTAssertTrue(row.continuesBefore)
        XCTAssertFalse(row.continuesAfter)
        let weeks = TaskTimelineScale.week.window(focus: focus, calendar: local)
        XCTAssertEqual(weeks.marks.count, 8)
        XCTAssertTrue(weeks.marks.allSatisfy { local.component(.weekday, from: $0) == local.firstWeekday })
        let months = TaskTimelineScale.month.window(focus: focus, calendar: local)
        XCTAssertEqual(months.marks.map { local.component(.month, from: $0) }, [3, 4, 5, 6, 7, 8])
        XCTAssertTrue(months.marks.allSatisfy { local.component(.day, from: $0) == 1 })
    }

    func testTimedStartResizeKeepsDueAndReminderProvenance() throws {
        let start = date("2026-11-09T10:00:00Z")
        let due = start.addingTimeInterval(300)
        let reminder = due.addingTimeInterval(-900)
        let original = TaskItem(title: "Short range", dueDate: due, hasDueTime: true, reminderDate: reminder,
                                timeZoneID: "UTC", scheduledDuration: .init(start: start, end: due))
        func prepare(_ target: Date, for task: TaskItem) -> TaskItem? {
            CalendarScheduling.prepared(.resizeStart(target), to: task, displayCalendar: calendar,
                                        settings: .init(), policyCalendar: calendar)
        }
        XCTAssertEqual(prepare(start, for: original), original)
        var zero = original
        zero.scheduledDuration?.start = due
        XCTAssertEqual(prepare(due, for: zero), zero)
        let changed = try XCTUnwrap(prepare(due, for: original))
        var expected = original
        expected.scheduledDuration?.start = due.addingTimeInterval(-900)
        XCTAssertEqual(changed, expected)
        XCTAssertNil(prepare(.distantPast, for: TaskItem(title: "Point", dueDate: due, hasDueTime: true)))
        XCTAssertNil(prepare(Date(timeIntervalSinceReferenceDate: .infinity), for: original))
    }

    func testTimedStartResizeUsesTrueVisibleEdgeAndOccurrenceBaseline() throws {
        let day = date("2026-11-09T00:00:00Z")
        let start = day.addingTimeInterval(6 * 3600 + 30 * 60)
        let due = day.addingTimeInterval(9 * 3600)
        let task = TaskItem(title: "Early range", dueDate: due, hasDueTime: true, recurrence: .daily,
                            scheduledDuration: .init(start: start, end: due))
        let range = try XCTUnwrap(CalendarDates.interval(for: [day], calendar: calendar))
        let projection = TaskCalendarProjection.project(data: WorkspaceData(tasks: [task]), range: range,
                                                         options: .init(), calendar: calendar)
        let visible = try XCTUnwrap(CalendarTimedLayout.placements(entries: projection.entries, day: day,
                                                                   calendar: calendar, window: .init()).first)
        XCTAssertFalse(visible.startIsVisible)
        XCTAssertTrue(visible.endIsVisible)
        let expanded = try XCTUnwrap(CalendarTimedLayout.placements(entries: projection.entries, day: day,
                                                                    calendar: calendar, window: .full).first)
        XCTAssertTrue(expanded.startIsVisible)
        let target = expanded.startResizeTarget(deltaMinutes: 31, day: day, calendar: calendar, window: .full)
        XCTAssertEqual(target, day.addingTimeInterval(7 * 3600))
        let changed = try XCTUnwrap(CalendarScheduling.prepared(.resizeStart(target), to: task,
            displayCalendar: calendar, settings: .init(), policyCalendar: calendar, scope: .currentOccurrence))
        XCTAssertEqual(changed.scheduledDuration?.start, target)
        XCTAssertEqual(changed.dueDate, due)
        let restored = try XCTUnwrap(CalendarScheduling.prepared(.restoreOccurrence, to: changed,
            displayCalendar: calendar, settings: .init(), policyCalendar: calendar))
        XCTAssertEqual(CalendarScheduleSnapshot(restored), CalendarScheduleSnapshot(task))
    }

    func testAllDayResizeUsesInclusiveDisplayDateAndPreservesCivilStart() throws {
        var taskCalendar = calendar
        taskCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var display = calendar
        display.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let start = taskCalendar.startOfDay(for: date("2026-03-07T18:00:00Z"))
        let end = try XCTUnwrap(taskCalendar.date(byAdding: .day, value: 2, to: start))
        let task = TaskItem(title: "DST retreat", dueDate: end, timeZoneID: taskCalendar.timeZone.identifier,
                            scheduledDuration: .init(start: start, end: end, isAllDay: true))
        let first = CalendarDates.civilDay(start, from: taskCalendar, to: display)
        let days = CalendarDates.days(from: first, count: 6, calendar: display)
        let range = try XCTUnwrap(CalendarDates.interval(for: days, calendar: display))
        let result = TaskCalendarProjection.project(data: WorkspaceData(tasks: [task]), range: range,
                                                     options: .init(), calendar: display)
        var entry = try XCTUnwrap(result.entries.first)
        XCTAssertTrue(entry.canResizeAllDayRange)
        XCTAssertNil(entry.allDayResizeTarget(on: days[2], calendar: display))
        let before = try XCTUnwrap(display.date(byAdding: .day, value: -1, to: first))
        XCTAssertEqual(entry.allDayResizeTarget(on: before, calendar: display), first)
        let next = try XCTUnwrap(entry.allDayResizeTarget(on: days[3], calendar: display))
        let resized = try XCTUnwrap(CalendarScheduling.prepared(.resizeEnd(next), to: task, displayCalendar: display,
                                                                 settings: .init(), policyCalendar: taskCalendar))
        XCTAssertEqual(resized.scheduledDuration?.start, start)
        XCTAssertEqual(resized.scheduledDuration?.end, taskCalendar.date(byAdding: .day, value: 3, to: start))
        XCTAssertEqual(resized.dueDate, resized.scheduledDuration?.end)
        XCTAssertFalse(resized.hasDueTime)
        entry.isProjected = true
        XCTAssertNil(entry.allDayResizeTarget(on: days[4], calendar: display))
    }

    func testAllDayStartResizeKeepsDueDayAndReminderProvenanceAcrossDST() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var display = calendar
        display.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let start = local.startOfDay(for: date("2026-03-07T18:00:00Z"))
        let end = try XCTUnwrap(local.date(byAdding: .day, value: 2, to: start))
        var task = TaskItem(title: "DST retreat", dueDate: end, timeZoneID: local.timeZone.identifier,
                            scheduledDuration: .init(start: start, end: end, isAllDay: true))
        task.reminderDates = [end.addingTimeInterval(-3600), end.addingTimeInterval(-1800)]
        task.reminderFollowsSchedule = true
        let first = CalendarDates.civilDay(start, from: local, to: display)
        let days = CalendarDates.days(from: first, count: 4, calendar: display)
        let range = try XCTUnwrap(CalendarDates.interval(for: days, calendar: display))
        var entry = try XCTUnwrap(TaskCalendarProjection.project(data: WorkspaceData(tasks: [task]), range: range,
                                                                  options: .init(), calendar: display).entries.first)
        XCTAssertNil(entry.allDayResizeTarget(on: first, edge: .start, calendar: display))
        XCTAssertEqual(entry.allDayResizeTarget(on: days[3], edge: .start, calendar: display), days[2])
        func resize(_ day: Date, task: TaskItem) -> TaskItem? {
            CalendarScheduling.prepared(.resizeStart(day), to: task, displayCalendar: display,
                                        settings: .init(), policyCalendar: local)
        }
        let changed = try XCTUnwrap(resize(days[1], task: task))
        let expected = try XCTUnwrap(local.date(byAdding: .day, value: 1, to: start))
        XCTAssertEqual(changed.scheduledDuration, .init(start: expected, end: end, isAllDay: true))
        XCTAssertEqual(end.timeIntervalSince(expected), 23 * 3600)
        XCTAssertEqual(changed.dueDate, task.dueDate)
        XCTAssertEqual(changed.timeZoneID, task.timeZoneID)
        XCTAssertFalse(changed.hasDueTime)
        XCTAssertEqual(changed.reminderDates, task.reminderDates)
        XCTAssertEqual(changed.reminderFollowsSchedule, task.reminderFollowsSchedule)
        XCTAssertEqual(resize(days[3], task: task)?.scheduledDuration, .init(start: end, end: end, isAllDay: true))
        XCTAssertEqual(resize(first, task: task).map(CalendarScheduleSnapshot.init), CalendarScheduleSnapshot(task))
        XCTAssertNil(resize(days[1], task: TaskItem(title: "Point", dueDate: end)))
        entry.isProjected = true
        XCTAssertNil(entry.allDayResizeTarget(on: days[1], edge: .start, calendar: display))
    }

    func testMonthWeekSpansContinueAndOverflowByDate() throws {
        let first = date("2026-11-09T00:00:00Z")
        let dates = CalendarDates.days(from: first, count: 14, calendar: calendar)
        func range(_ title: String, from start: Int, through end: Int) -> TaskItem {
            TaskItem(title: title, dueDate: dates[end],
                     scheduledDuration: .init(start: dates[start], end: dates[end], isAllDay: true))
        }
        let retreat = range("Retreat", from: 4, through: 8)
        let review = range("Review", from: 5, through: 7)
        let point = TaskItem(title: "Call", dueDate: dates[5])
        let data = WorkspaceData(tasks: [retreat, review, point])
        let interval = try XCTUnwrap(CalendarDates.interval(for: dates, calendar: calendar))
        let entries = TaskCalendarProjection.project(data: data, range: interval, options: .init(), calendar: calendar).entries
        let firstWeek = CalendarMonthWeekLayout(entries: entries, dates: Array(dates.prefix(7)), capacity: 1, calendar: calendar)
        XCTAssertEqual(firstWeek.spans.map(\.entry.taskID), [retreat.id])
        XCTAssertEqual(firstWeek.spans.map(\.firstDay), [4])
        XCTAssertEqual(firstWeek.spans.map(\.dayCount), [3])
        XCTAssertEqual(firstWeek.spans.map(\.continuesAfter), [true])
        XCTAssertEqual(firstWeek.days.map(\.hiddenCount), [0, 0, 0, 0, 0, 2, 1])
        XCTAssertEqual(firstWeek.days[5].entries.count, 3)
        XCTAssertEqual(firstWeek.days[5].slots, [nil])

        let secondWeek = CalendarMonthWeekLayout(entries: entries, dates: Array(dates.suffix(7)), capacity: 2, calendar: calendar)
        XCTAssertEqual(secondWeek.spans.map(\.entry.taskID), [retreat.id, review.id])
        XCTAssertEqual(secondWeek.spans.map(\.firstDay), [0, 0])
        XCTAssertEqual(secondWeek.spans.map(\.dayCount), [2, 1])
        XCTAssertEqual(secondWeek.spans.map(\.continuesBefore), [true, true])
        XCTAssertTrue(secondWeek.days.allSatisfy { $0.hiddenCount == 0 })
        let roomy = CalendarMonthWeekLayout(entries: entries, dates: Array(dates.prefix(7)), capacity: 3, calendar: calendar)
        XCTAssertEqual(roomy.days[5].slots.map { $0?.taskID }, [nil, nil, point.id])
    }

    func testAllDaySpansReuseLanesAndClipAtCivilDayBoundaries() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let first = local.startOfDay(for: date("2026-03-07T17:00:00Z"))
        let days = CalendarDates.days(from: first, count: 4, calendar: local)
        let before = try XCTUnwrap(local.date(byAdding: .day, value: -2, to: first))
        func range(_ title: String, from start: Date, through end: Date) -> TaskItem {
            TaskItem(title: title, dueDate: end, timeZoneID: local.timeZone.identifier,
                     scheduledDuration: .init(start: start, end: end, isAllDay: true))
        }
        let clipped = range("Clipped", from: before, through: days[1])
        let crossing = range("Crossing", from: days[1], through: days[2])
        let adjacent = range("Adjacent", from: days[2], through: days[2])
        let timed = TaskItem(title: "Timed", dueDate: days[1].addingTimeInterval(3_600), hasDueTime: true)
        let data = WorkspaceData(tasks: [adjacent, crossing, timed, clipped])
        let interval = try XCTUnwrap(CalendarDates.interval(for: days, calendar: local))
        XCTAssertEqual(interval.duration, 4 * 86_400 - 3_600)
        let entries = TaskCalendarProjection.project(data: data, range: interval, options: .init(), calendar: local).entries
        let placements = CalendarAllDayLayout.placements(entries: entries, days: days, calendar: local)
        XCTAssertEqual(placements.map { $0.entry.taskID }, [clipped.id, crossing.id, adjacent.id])
        XCTAssertEqual(placements.map(\.firstDay), [0, 1, 2])
        XCTAssertEqual(placements.map(\.dayCount), [2, 2, 1])
        XCTAssertEqual(placements.map(\.lane), [0, 1, 0])
        XCTAssertEqual(placements.map(\.continuesBefore), [true, false, false])
        XCTAssertFalse(placements.contains(where: \.continuesAfter))
        let partial = CalendarAllDayLayout.placements(entries: entries, days: Array(days.prefix(2)), calendar: local)
        XCTAssertEqual(partial.map(\.dayCount), [2, 1])
        XCTAssertEqual(partial.map(\.continuesAfter), [false, true])
    }

    func testTimelineZoomKeepsWallTimeAndBoundsTheScale() {
        let standard = CalendarTimelineScale.standard
        let expanded = standard.stepped(zoomingIn: true)
        XCTAssertEqual(standard.percentage, 100)
        XCTAssertEqual(expanded.pointsPerHour, 60)
        XCTAssertEqual(expanded.stepped(zoomingIn: false), standard)
        XCTAssertEqual(standard.scaled(by: .nan), standard)
        XCTAssertEqual(standard.scaled(by: 0), standard)
        let minimum = standard.scaled(by: 0.01)
        let maximum = standard.scaled(by: 100)
        XCTAssertEqual(minimum.pointsPerHour, 32)
        XCTAssertEqual(maximum.pointsPerHour, 104)
        XCTAssertFalse(minimum.canZoomOut)
        XCTAssertFalse(maximum.canZoomIn)

        let window = CalendarHourlyWindow()
        let hour = standard.hour(at: 6.25 * standard.pointsPerHour)
        for scale in [minimum, standard, expanded, maximum] {
            let displayedOffset = scale.offset(at: hour)
            XCTAssertEqual(window.minute(atOffset: scale.hour(at: displayedOffset) * 60), 13 * 60 + 15)
        }
    }

    func testAllDayRowsAreOptionalAndBounded() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var options = try decoder.decode(TaskCalendarOptions.self, from: Data("{}".utf8))
        XCTAssertNil(options.allDayRows)
        let original = try JSONSerialization.jsonObject(with: encoder.encode(options)) as? [String: Any]
        XCTAssertNil(original?["allDayRows"])

        options.allDayRows = 4
        XCTAssertEqual(try decoder.decode(TaskCalendarOptions.self, from: encoder.encode(options)), options)
        options.allDayRows = -1
        XCTAssertEqual(options.allDayRows, 1)
        options.allDayRows = Int.max
        XCTAssertEqual(options.allDayRows, 12)
        options.allDayRows = nil
        XCTAssertEqual(options, try decoder.decode(TaskCalendarOptions.self, from: Data("{}".utf8)))
    }

    func testMonthZoomUsesCivilWeeksAndPaginatesWithoutGaps() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let focus = date("2026-03-06T17:00:00Z")
        let options = TaskCalendarOptions()
        let zoom = CalendarMonthZoom.full.adjusted(magnification: 1.6).adjusted(zoomingIn: true)
        XCTAssertEqual(zoom, .twoWeeks)
        XCTAssertEqual(zoom.itemLimit, 6)
        XCTAssertEqual(zoom.adjusted(magnification: 1.05), zoom)
        XCTAssertEqual(zoom.adjusted(magnification: 0.6), .threeWeeks)
        XCTAssertEqual(CalendarMonthZoom.oneWeek.adjusted(zoomingIn: true), .oneWeek)
        let visible = CalendarDates.visibleDays(focus: focus, mode: .month, options: options, calendar: local, monthZoom: zoom)
        XCTAssertEqual(visible.count, 14)
        XCTAssertEqual(visible.first, date("2026-03-02T05:00:00Z"))
        let interval = try XCTUnwrap(CalendarDates.interval(for: visible, calendar: local))
        XCTAssertEqual(interval.duration, 14 * 86_400 - 3600)
        let next = CalendarDates.navigate(focus, direction: 1, mode: .month, options: options, calendar: local, monthZoom: zoom)
        XCTAssertEqual(next, interval.end)
        XCTAssertEqual(CalendarDates.navigate(next, direction: -1, mode: .month, options: options, calendar: local, monthZoom: zoom), visible.first)
        let normal = CalendarDates.visibleDays(focus: focus, mode: .month, options: options, calendar: local)
        XCTAssertGreaterThan(normal.count, visible.count)
        let week = CalendarDates.visibleDays(focus: focus, mode: .week, options: options, calendar: local, monthZoom: zoom)
        XCTAssertEqual(week.count, 7)
    }

    func testMonthBrowseWindowKeepsCivilWeeksAndRebasesAtBothEdges() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let anchor = date("2026-03-02T05:00:00Z")
        let window = CalendarMonthBrowseWindow(around: anchor, calendar: local)
        let days = window.days(calendar: local)
        XCTAssertEqual(days.count, 119)
        XCTAssertEqual(days[56], anchor)
        XCTAssertEqual(days[63], date("2026-03-09T04:00:00Z"))
        XCTAssertEqual(window.keeping(days[14], in: local), window)
        XCTAssertEqual(window.keeping(days[77], in: local), window)
        for edge in [days[7], days[84]] {
            let shifted = window.keeping(edge, in: local)
            XCTAssertNotEqual(shifted, window)
            XCTAssertEqual(shifted.days(calendar: local)[56], edge)
        }
        let distant = date("2027-01-04T05:00:00Z")
        XCTAssertEqual(window.keeping(distant, in: local).days(calendar: local)[56], distant)
        XCTAssertEqual(CalendarMonthBrowseWindow.focus(forWeek: date("2026-12-28T05:00:00Z"), calendar: local),
                       date("2027-01-01T05:00:00Z"))
        XCTAssertEqual(CalendarMonthBrowseWindow.focus(forWeek: anchor, calendar: local), anchor)
    }

    func testDescriptionHeadingFoldsKeepNestedStateAndExactVisibleFormatting() throws {
        let text = "Parent\nCafé\nChild\ne\u{301} 🧩 hidden\nPeer\nVisible 🧩\nLast"
        let string = text as NSString
        func heading(_ name: String, _ level: Int) -> RichBlockRun {
            let range = string.paragraphRange(for: string.range(of: name))
            return RichBlockRun(location: range.location, length: range.length, heading: level)
        }
        let peer = string.range(of: "Visible 🧩")
        let hidden = string.range(of: "hidden")
        let rich = RichBody(text: text, runs: [
            .init(location: 0, length: string.length, bold: true),
            .init(location: hidden.location, length: hidden.length, link: "https://example.invalid/hidden"),
            .init(location: peer.location, length: peer.length, italic: true),
        ], blocks: [heading("Parent", 1), heading("Child", 2), heading("Peer", 1), heading("Last", 1)])
        let preview = try XCTUnwrap(RichDescriptionPreview(body: text, rich: rich))
        let headings = preview.foldableHeadings
        XCTAssertEqual(headings.map(\.title), ["Parent", "Child", "Peer"])
        let parent = headings[0].id, child = headings[1].id
        let folded = preview.readingView(collapsed: [parent, child])
        XCTAssertEqual(folded.headings.map(\.title), ["Parent", "Peer"])
        XCTAssertTrue(RichBody.sameCodeUnits(folded.preview.text, "Parent\nPeer\nVisible 🧩\nLast"))
        XCTAssertFalse(folded.preview.inline.contains { $0.link != nil })
        let visible = try XCTUnwrap(folded.preview.inline.first { $0.italic })
        XCTAssertEqual((folded.preview.text as NSString).substring(with: NSRange(location: visible.location, length: visible.length)), "Visible 🧩")
        XCTAssertTrue(try XCTUnwrap(RichDescriptionPreview(body: folded.preview.text, rich: folded.preview.displayRichBody)).matches(folded.preview))
        let reopened = preview.readingView(collapsed: [child])
        XCTAssertEqual(reopened.headings.map(\.id), headings.map(\.id))
        XCTAssertTrue(RichBody.sameCodeUnits(reopened.preview.text, "Parent\nCafé\nChild\nPeer\nVisible 🧩\nLast"))
        XCTAssertTrue(RichBody.sameCodeUnits(preview.readingView(collapsed: []).preview.text, text))
    }

    func testTimestampSortDistinguishesCreatedModifiedAndRetainsEqualOrder() {
        let first = TaskItem(title: "First", createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(200))
        let second = TaskItem(title: "Second", createdAt: now, updatedAt: now)
        let tied = TaskItem(title: "Tied", createdAt: first.createdAt, updatedAt: first.updatedAt)
        let tasks = [first, second, tied]
        XCTAssertEqual(TaskTimestampSort(rawValue: "Created"), .createdNewest)
        XCTAssertEqual(tasks.sorted(by: TaskTimestampSort.createdNewest.precedes).map(\.id), [second.id, first.id, tied.id])
        XCTAssertEqual(tasks.sorted(by: TaskTimestampSort.createdOldest.precedes).map(\.id), [first.id, tied.id, second.id])
        XCTAssertEqual(tasks.sorted(by: TaskTimestampSort.modifiedNewest.precedes).map(\.id), [first.id, tied.id, second.id])
        XCTAssertEqual(tasks.sorted(by: TaskTimestampSort.modifiedOldest.precedes).map(\.id), [second.id, first.id, tied.id])
        XCTAssertFalse(TaskSortPolicy.canReorder(TaskTimestampSort.modifiedNewest.rawValue))
    }

    func testTaskCreationDayGroupsUseLocalMidnightAndKeepIncomingRowOrder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Moscow"))
        let midnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        let priorDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: midnight))
        let older = TaskItem(title: "Older", dueDate: midnight, createdAt: midnight.addingTimeInterval(-1))
        let atMidnight = TaskItem(title: "Midnight", createdAt: midnight)
        let later = TaskItem(title: "Later", createdAt: midnight.addingTimeInterval(60))
        let input = [later, older, atMidnight]
        let newestGroups = TaskCreationDayGroup.group(input, calendar: calendar, sort: .modifiedOldest)
        XCTAssertEqual(newestGroups.map(\.day), [midnight, priorDay])
        XCTAssertEqual(newestGroups.map { $0.tasks.map(\.id) }, [[later.id, atMidnight.id], [older.id]])
        let oldestGroups = TaskCreationDayGroup.group(input, calendar: calendar, sort: .createdOldest)
        XCTAssertEqual(oldestGroups.map(\.day), [priorDay, midnight])
        XCTAssertEqual(oldestGroups.last?.tasks.map(\.id), [later.id, atMidnight.id])
        XCTAssertTrue(TaskCreationDayGroup.group([], calendar: calendar, sort: nil).isEmpty)
    }

    func testCalendarIconChoicesSeparateTasksAndNotesWithoutChangingEntries() throws {
        let task = TaskItem(title: "Task", dueDate: now, hasDueTime: true)
        let note = TaskItem(title: "Note", kind: .note, dueDate: now, hasDueTime: true)
        let data = WorkspaceData(tasks: [task, note])
        let range = DateInterval(start: now.addingTimeInterval(-3600), duration: 7200)
        var options = TaskCalendarOptions()
        let entries = TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar).entries
        let taskEntry = try XCTUnwrap(entries.first { $0.taskID == task.id })
        let noteEntry = try XCTUnwrap(entries.first { $0.taskID == note.id })
        XCTAssertTrue(options.showsIcon(for: taskEntry))
        XCTAssertTrue(options.showsIcon(for: noteEntry))
        options.showTaskIcons = false
        XCTAssertFalse(options.showsIcon(for: taskEntry))
        XCTAssertTrue(options.showsIcon(for: noteEntry))
        options.showItemIcons = false
        XCTAssertFalse(options.showsIcon(for: taskEntry))
        XCTAssertFalse(options.showsIcon(for: noteEntry))
        options.showItemIcons = true
        options.showTaskIcons = true
        options.showNoteIcons = false
        XCTAssertTrue(options.showsIcon(for: taskEntry))
        XCTAssertFalse(options.showsIcon(for: noteEntry))
        XCTAssertEqual(TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar).entries, entries)
    }

    func testAdjustedFoldCutoffsKeepWallTimeAndCannotCross() throws {
        let original = CalendarFoldedHours()
        XCTAssertEqual(original.moving(.early, by: -0.4), original)
        XCTAssertEqual(original.moving(.early, by: -1), .init(earlyEnd: 6, lateStart: 21))
        XCTAssertEqual(original.moving(.early, to: 24).earlyEnd, 20)
        XCTAssertEqual(original.moving(.late, to: 0).lateStart, 8)
        XCTAssertEqual(original.moving(.late, by: .infinity), original)
        let cutoffs = CalendarFoldedHours(earlyEnd: 6, lateStart: 22)
        var window = CalendarHourlyWindow(foldedHours: cutoffs)
        XCTAssertEqual(window.hours, 6..<22)
        XCTAssertEqual(window.minute(atOffset: 30), 390)
        let day = date("2026-11-09T00:00:00Z")
        let task = TaskItem(title: "Early", dueDate: date("2026-11-09T06:30:00Z"), hasDueTime: true)
        let range = DateInterval(start: day, duration: 86400)
        let entries = TaskCalendarProjection.project(data: WorkspaceData(tasks: [task]), range: range,
            options: .init(), calendar: calendar).entries
        XCTAssertEqual(window.itemCount(in: .early, entries: entries, days: [day], calendar: calendar), 0)
        XCTAssertEqual(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: window).count, 1)
        XCTAssertFalse(window.canAdjustFolds)
        window.toggle(.early)
        XCTAssertFalse(window.canAdjustFolds)
        window.toggle(.late)
        XCTAssertTrue(window.canAdjustFolds)
        let updated = window.using(.init(earlyEnd: 8, lateStart: 20))
        XCTAssertEqual(updated.hours, 0..<24)
        XCTAssertEqual(updated.itemCount(in: .early, entries: entries, days: [day], calendar: calendar), 1)
    }

    func testFoldedHoursKeepWallTimeAndClipOnlyTheDisplayedSegments() throws {
        let day = date("2026-11-09T00:00:00Z")
        let early = TaskItem(title: "Early", dueDate: date("2026-11-09T06:45:00Z"), hasDueTime: true)
        let start = date("2026-11-09T20:30:00Z"), end = date("2026-11-09T21:30:00Z")
        let crossing = TaskItem(title: "Crossing", dueDate: end, hasDueTime: true,
                                scheduledDuration: .init(start: start, end: end))
        let interval = DateInterval(start: day, end: date("2026-11-10T00:00:00Z"))
        let entries = TaskCalendarProjection.project(data: WorkspaceData(tasks: [early, crossing]), range: interval,
            options: TaskCalendarOptions(), calendar: calendar).entries
        var window = CalendarHourlyWindow()
        XCTAssertEqual(window.hours, 7..<21)
        XCTAssertEqual(window.minute(atOffset: 20), 435)
        XCTAssertEqual(window.minute(atOffset: 900), 1260)
        XCTAssertEqual(window.itemCount(in: .early, entries: entries, days: [day], calendar: calendar), 1)
        XCTAssertEqual(window.itemCount(in: .late, entries: entries, days: [day], calendar: calendar), 1)
        let folded = CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: window)
        XCTAssertEqual(folded.map(\.entry.taskID), [crossing.id])
        let part = try XCTUnwrap(folded.first)
        XCTAssertEqual(part.startMinute, 1230)
        XCTAssertEqual(part.endMinute, 1260)
        XCTAssertEqual(part.resizeMinute, 1290)
        XCTAssertFalse(part.endIsVisible)
        XCTAssertEqual(part.entry.end, end)

        window.toggle(.late)
        let late = try XCTUnwrap(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: window).first)
        XCTAssertTrue(late.endIsVisible)
        XCTAssertEqual(late.endMinute, 1290)
        window.toggle(.early)
        XCTAssertEqual(window.hours, 0..<24)
        XCTAssertEqual(window.minute(atOffset: 20), 15)
        XCTAssertEqual(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: window).count, 2)
    }

    func testAgendaExtensionUsesLocalMonthBoundariesAndKeepsExistingDays() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let focus = date("2026-03-06T18:00:00Z")
        let options = TaskCalendarOptions()
        var window = CalendarAgendaWindow()
        let initial = CalendarDates.visibleDays(focus: focus, mode: .agenda, options: options, calendar: local)
        XCTAssertEqual(initial.count, 30)
        XCTAssertEqual(CalendarDates.interval(for: initial, calendar: local)?.end, date("2026-04-05T04:00:00Z"))
        window.extend()
        let extended = CalendarDates.visibleDays(focus: focus, mode: .agenda, options: options, calendar: local, agendaWindow: window)
        XCTAssertEqual(Array(extended.prefix(initial.count)), initial)
        XCTAssertEqual(CalendarDates.interval(for: extended, calendar: local)?.end, date("2026-10-05T04:00:00Z"))
        for _ in 0..<8 { window.extend() }
        XCTAssertFalse(window.canExtend)
        let bounded = CalendarDates.visibleDays(focus: focus, mode: .agenda, options: options, calendar: local, agendaWindow: window)
        XCTAssertEqual(CalendarDates.interval(for: bounded, calendar: local)?.end, date("2028-04-05T04:00:00Z"))
        XCTAssertEqual(CalendarDates.visibleDays(focus: focus, mode: .week, options: options, calendar: local, agendaWindow: window).count, 7)
    }

    func testSkipOccurrenceUsesTheSeriesBaselineAndPreservesTheOpenTask() throws {
        let due = date("2026-11-09T09:00:00Z"), next = date("2026-11-10T09:00:00Z")
        let rule = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days, maxOccurrences: 2)
        let task = TaskItem(title: "Recurring", dueDate: due, hasDueTime: true, reminderDate: due - 900,
                            checklist: [.init(title: "Keep checked", isCompleted: true)], reminderFollowsSchedule: false,
                            customRecurrence: rule, scheduledDuration: .init(start: due - 1_800, end: due))
        let settings = AppSettings()
        let moved = try XCTUnwrap(CalendarScheduling.prepared(.setPoint(date: date("2026-11-30T09:00:00Z"), allDay: false),
            to: task, displayCalendar: calendar, settings: settings, policyCalendar: calendar, scope: .currentOccurrence))
        let advanced = try XCTUnwrap(CalendarScheduling.prepared(.skipOccurrence, to: moved,
            displayCalendar: calendar, settings: settings, policyCalendar: calendar))
        XCTAssertEqual(advanced.id, moved.id)
        XCTAssertEqual(advanced.title, moved.title)
        XCTAssertEqual(advanced.checklist, moved.checklist)
        XCTAssertNil(advanced.completedAt)
        XCTAssertNil(advanced.originalOccurrenceSchedule)
        XCTAssertEqual(advanced.dueDate, next)
        XCTAssertEqual(advanced.scheduledDuration, .init(start: next - 1_800, end: next))
        XCTAssertEqual(advanced.reminderDates, [next - 900])
        XCTAssertEqual(advanced.occurrenceIndex, 2)
        XCTAssertFalse(CalendarScheduling.canSkipCurrentOccurrence(advanced, in: [advanced], calendar: calendar))
        XCTAssertNil(CalendarScheduling.prepared(.skipOccurrence, to: moved, displayCalendar: calendar,
            settings: settings, policyCalendar: calendar, scope: .currentOccurrence))

        let undo = CalendarScheduleUndo(taskID: task.id, before: CalendarScheduleSnapshot(moved),
                                        after: CalendarScheduleSnapshot(advanced), operation: .skipOccurrence)
        var renamed = advanced
        renamed.title = "Later title"
        let restored = try XCTUnwrap(undo.restoring(on: renamed, lists: [], tasks: [renamed]))
        XCTAssertEqual(restored.title, renamed.title)
        XCTAssertEqual(CalendarScheduleSnapshot(restored), CalendarScheduleSnapshot(moved))
        var successor = TaskItem(title: "Later occurrence", dueDate: next + 86_400)
        successor.recurrenceSourceID = task.id
        XCTAssertFalse(CalendarScheduling.canSkipCurrentOccurrence(moved, in: [moved, successor], calendar: calendar))
        XCTAssertNil(undo.restoring(on: renamed, lists: [], tasks: [renamed, successor]))
    }

    func testSkipOccurrenceKeepsMonthlyAnchorAndUsesTheForecastCompletionAnchor() throws {
        let settings = AppSettings()
        func skip(_ task: TaskItem) throws -> TaskItem {
            try XCTUnwrap(CalendarScheduling.prepared(.skipOccurrence, to: task, displayCalendar: calendar,
                settings: settings, policyCalendar: calendar))
        }
        let jan31 = date("2026-01-31T09:00:00Z")
        let task = TaskItem(title: "Monthly", dueDate: jan31, hasDueTime: true, recurrence: .monthly)
        let february = try skip(task)
        XCTAssertEqual(february.dueDate, date("2026-02-28T09:00:00Z"))
        XCTAssertEqual(february.recurrenceAnchorDay, 31)
        XCTAssertEqual(try skip(february).dueDate, date("2026-03-31T09:00:00Z"))

        let completion = TaskItem(title: "After completion", dueDate: jan31, hasDueTime: true,
                                  customRecurrence: .init(anchor: .completionDate, interval: 2, unit: .days))
        let next = try skip(completion)
        XCTAssertEqual(next.dueDate, date("2026-02-02T09:00:00Z"))
        XCTAssertNil(next.recurrenceNominalDate)
    }

    func testCurrentOccurrenceMoveKeepsEarlierForecastsAndDistinctOverlappingCards() throws {
        let due = date("2026-11-09T09:00:00Z")
        let next = date("2026-11-16T09:00:00Z")
        let task = TaskItem(title: "Weekly", dueDate: due, hasDueTime: true, recurrence: .weekly)
        var options = TaskCalendarOptions()
        options.showRepeatCycles = true
        let range = DateInterval(start: date("2026-11-16T00:00:00Z"), end: date("2026-11-17T00:00:00Z"))
        let moved = try XCTUnwrap(CalendarScheduling.prepared(.setPoint(date: date("2026-11-30T09:00:00Z"), allDay: false),
            to: task, displayCalendar: calendar, settings: AppSettings(), policyCalendar: calendar, scope: .currentOccurrence))
        XCTAssertEqual(moved.originalOccurrenceSchedule?.due, due)
        let future = TaskCalendarProjection.project(data: WorkspaceData(tasks: [moved]), range: range, options: options, calendar: calendar)
        XCTAssertEqual(future.entries.map(\.due), [next])
        XCTAssertEqual(future.entries.map(\.isProjected), [true])

        let overlapping = try XCTUnwrap(CalendarScheduling.prepared(.setPoint(date: next, allDay: false), to: moved,
            displayCalendar: calendar, settings: AppSettings(), policyCalendar: calendar, scope: .currentOccurrence))
        XCTAssertEqual(overlapping.originalOccurrenceSchedule?.due, due)
        let cards = TaskCalendarProjection.project(data: WorkspaceData(tasks: [overlapping]), range: range, options: options, calendar: calendar)
        XCTAssertEqual(Set(cards.entries.map(\.isProjected)), [true, false])
        XCTAssertEqual(Set(cards.entries.map(\.id)).count, 2)
    }

    func testCurrentOccurrenceResizeDoesNotChangeSuccessorOrItsSubtreeOffsets() throws {
        let due = date("2026-06-01T09:00:00Z"), next = date("2026-07-31T09:00:00Z")
        let range = TaskDurationRange(start: due.addingTimeInterval(-1800), end: due)
        var root = TaskItem(title: "Recurring range", dueDate: due, hasDueTime: true, reminderDate: due.addingTimeInterval(-900),
                            reminderFollowsSchedule: false,
                            customRecurrence: .init(anchor: .dueDate, interval: 2, unit: .months,
                                                    includesLastDayOfMonth: true, skipWeekends: true),
                            occurrenceIndex: 2, scheduledDuration: range,
                            recurrenceNominalDate: date("2026-05-31T09:00:00Z"))
        let child = TaskItem(title: "Child", dueDate: due.addingTimeInterval(1800), hasDueTime: true, parentID: root.id)
        let changed = date("2026-06-01T11:00:00Z")
        root = try XCTUnwrap(CalendarScheduling.prepared(.resizeEnd(changed), to: root, displayCalendar: calendar,
            settings: AppSettings(), policyCalendar: calendar, scope: .currentOccurrence))
        XCTAssertEqual(root.dueDate, changed)
        XCTAssertEqual(root.reminderDates, [changed.addingTimeInterval(-900)])
        var lifecycle = TaskLifecycle(data: WorkspaceData(tasks: [root, child]))
        XCTAssertTrue(try lifecycle.apply(.complete, to: root.id, now: changed, calendar: calendar))
        let successor = try XCTUnwrap(lifecycle.data.tasks.first { $0.recurrenceSourceID == root.id })
        let successorChild = try XCTUnwrap(lifecycle.data.tasks.first { $0.recurrenceSourceID == child.id })
        XCTAssertEqual(successor.dueDate, next)
        XCTAssertEqual(successor.occurrenceIndex, 3)
        XCTAssertEqual(successor.scheduledDuration, .init(start: next.addingTimeInterval(-1800), end: next))
        XCTAssertEqual(successor.reminderDates, [next.addingTimeInterval(-900)])
        XCTAssertNil(successor.originalOccurrenceSchedule)
        XCTAssertEqual(successorChild.parentID, successor.id)
        XCTAssertEqual(successorChild.dueDate, next.addingTimeInterval(1800))
        XCTAssertEqual(lifecycle.data.tasks.first { $0.id == root.id }?.dueDate, changed)
    }

    func testReopenedPredecessorWithStoredSuccessorCannotAddAnotherOccurrenceForecast() throws {
        let due = date("2026-11-09T09:00:00Z")
        let next = date("2026-11-16T09:00:00Z")
        let moved = date("2026-11-10T09:00:00Z")
        let task = TaskItem(title: "Weekly", dueDate: due, hasDueTime: true, recurrence: .weekly)
        let exception = try XCTUnwrap(CalendarScheduling.prepared(.setPoint(date: moved, allDay: false), to: task,
            displayCalendar: calendar, settings: AppSettings(), policyCalendar: calendar, scope: .currentOccurrence))
        var first = TaskLifecycle(data: WorkspaceData(tasks: [exception]))
        XCTAssertTrue(try first.apply(.complete, to: task.id, now: moved, calendar: calendar))
        var afterReload = TaskLifecycle(data: first.data)
        XCTAssertTrue(try afterReload.apply(.reopen, to: task.id, now: moved, calendar: calendar))
        let reopened = try XCTUnwrap(afterReload.data.tasks.first { $0.id == task.id })
        let successor = try XCTUnwrap(afterReload.data.tasks.first { $0.recurrenceSourceID == task.id })
        XCTAssertEqual(reopened.dueDate, moved)
        XCTAssertFalse(CalendarScheduling.canRescheduleCurrentOccurrence(reopened, in: afterReload.data.tasks))
        XCTAssertNil(CalendarScheduling.prepared(.restoreOccurrence, to: reopened, displayCalendar: calendar,
            settings: AppSettings(), policyCalendar: calendar, in: afterReload.data.tasks))
        XCTAssertTrue(CalendarScheduling.canRescheduleCurrentOccurrence(successor, in: afterReload.data.tasks))

        var options = TaskCalendarOptions()
        options.showRepeatCycles = true
        let range = DateInterval(start: next, end: date("2026-11-24T00:00:00Z"))
        let projection = TaskCalendarProjection.project(data: afterReload.data, range: range, options: options, calendar: calendar)
        XCTAssertEqual(projection.entries.map(\.due), [next, date("2026-11-23T09:00:00Z")])
        XCTAssertEqual(projection.entries.map(\.taskID), [successor.id, successor.id])
    }

    func testRichEditPreservesCodeUnitsAndMovesUntouchedParagraphStyles() throws {
        let source = "e\u{301} 🧩\nSecond"
        let original = RichBody(text: source, runs: [.init(location: 0, length: 5, bold: true)],
                                blocks: [.init(location: 0, length: 6, list: .checklist, checked: true),
                                         .init(location: 6, length: 6, heading: 2)])
        let edited = try RichBodyEdit.applying([.replace(NSRange(location: 3, length: 2), with: "🚀🚀", style: .inherit)],
                                               to: source, rich: original)
        XCTAssertTrue(RichBody.sameCodeUnits(edited.text, "e\u{301} 🚀🚀\nSecond"))
        XCTAssertEqual(edited.runs, [.init(location: 0, length: 7, bold: true)])
        XCTAssertEqual(edited.blocks, [.init(location: 0, length: 8, list: .checklist, checked: true),
                                       .init(location: 8, length: 6, heading: 2)])
        XCTAssertNotNil(RichDescriptionPreview(body: edited.text, rich: edited))
    }

    func testRichEditRetainsAdjacentStylesWithoutExtendingALinkAtItsBoundary() throws {
        let source = "Link right"
        let link = "https://example.test/link"
        let original = RichBody(text: source, runs: [
            .init(location: 0, length: 4, bold: true, link: link),
            .init(location: 5, length: 5, underline: true),
        ])
        let edited = try RichBodyEdit.applying([
            .replace(NSRange(location: 4, length: 0), with: "!", style: .inherit),
            .toggle(.italic, NSRange(location: 0, length: 2)),
        ], to: source, rich: original)
        XCTAssertEqual(edited.text, "Link! right")
        XCTAssertEqual(edited.runs, [
            .init(location: 0, length: 2, bold: true, italic: true, link: link),
            .init(location: 2, length: 2, bold: true, link: link),
            .init(location: 4, length: 1, bold: true),
            .init(location: 6, length: 5, underline: true),
        ])
        XCTAssertThrowsError(try RichBodyEdit.applying([.setLink("file:///tmp/x", NSRange(location: 0, length: 1))],
                                                     to: edited.text, rich: edited)) { error in
            XCTAssertEqual(error as? RichBodyEditError, .invalidLink)
        }
    }

    func testRichParagraphSelectionExcludesTheFollowingParagraphAndPreservesItsStyle() throws {
        let source = "First\nSecond\n\n"
        let original = RichBody(text: source, blocks: [.init(location: 6, length: 7, heading: 3)])
        let edited = try RichBodyEdit.applying([
            .paragraph(.list(.checklist), NSRange(location: 0, length: 6)),
            .paragraph(.checklistChecked(true), NSRange(location: 0, length: 0)),
            .paragraph(.horizontalRule(true), NSRange(location: 13, length: 1)),
        ], to: source, rich: original)
        XCTAssertTrue(RichBody.sameCodeUnits(edited.text, source))
        XCTAssertEqual(edited.blocks, [
            .init(location: 0, length: 6, list: .checklist, checked: true),
            .init(location: 6, length: 7, heading: 3),
            .init(location: 13, length: 1, rule: true),
        ])
    }

    func testRichEditSplitsChecklistParagraphWithoutCopyingCheckedState() throws {
        let source = "ABCD\nNext"
        let original = RichBody(text: source, blocks: [
            .init(location: 0, length: 5, heading: 2, quote: true, list: .checklist, checked: true),
            .init(location: 5, length: 4, list: .bullet),
        ])
        let split = try RichBodyEdit.applying([.replace(NSRange(location: 2, length: 0), with: "\n", style: .inherit)],
                                              to: source, rich: original)
        XCTAssertEqual(split.text, "AB\nCD\nNext")
        XCTAssertEqual(split.blocks, [
            .init(location: 0, length: 3, heading: 2, quote: true, list: .checklist, checked: true),
            .init(location: 3, length: 3, quote: true, list: .checklist),
            .init(location: 6, length: 4, list: .bullet),
        ])
        let atStart = try RichBodyEdit.applying([.replace(NSRange(location: 0, length: 0), with: "\n", style: .inherit)],
                                                to: source, rich: original)
        XCTAssertEqual(atStart.blocks, [
            .init(location: 0, length: 1, quote: true, list: .checklist),
            .init(location: 1, length: 5, heading: 2, quote: true, list: .checklist, checked: true),
            .init(location: 6, length: 4, list: .bullet),
        ])
    }

    func testRichEditPlainPasteShiftsUnrelatedLinkAndDoesNotInheritStyle() throws {
        let source = "A 🧩 B"
        let target = "https://example.test/task"
        let original = RichBody(text: source, runs: [
            .init(location: 0, length: 4, bold: true),
            .init(location: 5, length: 1, link: target),
        ])
        let edited = try RichBodyEdit.applying([.replace(NSRange(location: 2, length: 2), with: "e\u{301}\n", style: .plain)],
                                               to: source, rich: original)
        XCTAssertTrue(RichBody.sameCodeUnits(edited.text, "A e\u{301}\n B"))
        XCTAssertEqual(edited.runs, [
            .init(location: 0, length: 2, bold: true),
            .init(location: 6, length: 1, link: target),
        ])
    }

    func testRichClipboardClipsSelectionAndChecksExactPlainPayload() throws {
        let source = "Title\ne\u{301} 🧩\nNext"
        let string = source as NSString
        let first = string.paragraphRange(for: NSRange(location: 0, length: 1))
        let emoji = string.range(of: "🧩")
        let next = string.paragraphRange(for: string.range(of: "Next"))
        let body = RichBody(text: source,
                            runs: [.init(location: emoji.location, length: emoji.length,
                                         bold: true, link: "file:///private/unsupported")],
                            blocks: [.init(location: first.location, length: first.length, heading: 2),
                                     .init(location: next.location, length: next.length, quote: true)])
        let selection = NSRange(location: 0, length: next.location + 2)
        let fragment = try XCTUnwrap(RichBodyClipboard.fragment(from: body, selection: selection))
        XCTAssertTrue(RichBody.sameCodeUnits(fragment.text, "Title\ne\u{301} 🧩\nNe"))
        XCTAssertEqual(fragment.blocks, [body.blocks[0]])
        XCTAssertEqual(fragment.runs, [.init(location: emoji.location, length: 2, bold: true)])
        let bytes = try XCTUnwrap(RichBodyClipboard.encode(fragment))
        XCTAssertEqual(RichBodyClipboard.decode(bytes, matching: fragment.text), fragment)
        XCTAssertNil(RichBodyClipboard.decode(bytes, matching: "Title\né 🧩\nNe"))
        XCTAssertNil(RichBodyClipboard.decode(Data(#"{"version":99,"fragment":{"text":"x"}}"#.utf8), matching: "x"))
        XCTAssertNil(RichBodyClipboard.fragment(from: body, selection: NSRange(location: emoji.location + 1, length: 1)))
    }

    func testSavedRichListContinuesAndExitsWithoutChangingNeighboringContent() throws {
        let first = "First 🧩\r\n"
        let second = "Second\r\n"
        let text = first + second + "After"
        let start = first.utf16.count
        let body = RichBody(text: text, runs: [.init(location: 6, length: 2, bold: true)], blocks: [
            .init(location: 0, length: start, list: .numbered),
            .init(location: start, length: second.utf16.count, list: .numbered)
        ])
        let split = try XCTUnwrap(RichMarkdownTyping.listContinuation(for: "\n", at: NSRange(location: 8, length: 0), in: body))
        let splitBody = try RichBodyEdit.applying([split.edit], to: text, rich: body)
        XCTAssertEqual(splitBody.text, first + "\r\n" + second + "After")
        XCTAssertEqual(splitBody.runs, body.runs)
        XCTAssertEqual(RichDescriptionPreview(body: splitBody.text, rich: splitBody)?.paragraphs.map(\.marker),
                       [.number(1), .number(2), .number(3), nil])
        let exit = try XCTUnwrap(RichMarkdownTyping.listContinuation(for: "\n", at: split.caret, in: splitBody))
        let exited = try RichBodyEdit.applying([exit.edit], to: splitBody.text, rich: splitBody)
        XCTAssertEqual(exited.text, splitBody.text)
        XCTAssertEqual(RichDescriptionPreview(body: exited.text, rich: exited)?.paragraphs.map(\.marker),
                       [.number(1), nil, .number(1), nil])

        for style: RichListStyle in [.bullet, .numbered, .checklist] {
            let list = RichBody(text: "Finish", blocks: [.init(location: 0, length: 6, list: style, checked: style == .checklist ? true : nil)])
            let append = try XCTUnwrap(RichMarkdownTyping.listContinuation(for: "\n", at: NSRange(location: 6, length: 0), in: list))
            let opened = try RichBodyEdit.applying([append.edit], to: list.text, rich: list)
            XCTAssertEqual(opened.text, "Finish\n\n")
            XCTAssertEqual(opened.blocks.map(\.list), [style, style])
            XCTAssertEqual(opened.blocks.map(\.checked), [list.blocks[0].checked, nil])
            let fill = try XCTUnwrap(RichMarkdownTyping.listContinuation(for: "Next", at: append.caret, in: opened))
            let filled = try RichBodyEdit.applying([fill.edit], to: opened.text, rich: opened)
            XCTAssertEqual(filled.text, "Finish\nNext")
            XCTAssertEqual(filled.blocks.map(\.list), [style, style])
            let exitBlank = try XCTUnwrap(RichMarkdownTyping.listContinuation(for: "\n", at: append.caret, in: opened))
            let plainTail = try RichBodyEdit.applying([exitBlank.edit], to: opened.text, rich: opened)
            XCTAssertEqual(plainTail.text, "Finish\n")
            XCTAssertEqual(plainTail.blocks.count, 1)
            XCTAssertNil(RichMarkdownTyping.listContinuation(for: "P", at: exitBlank.caret, in: plainTail))
        }
    }

    func testListIconExtractsOnlyOneWholeEmojiAndHonorsExplicitChoice() {
        for icon in ["👩🏽‍💻", "🇬🇧", "1️⃣", "🏳️‍🌈", "❤️"] {
            let result = ListIcon.resolvingName(" \(icon)  Research ", symbol: nil, previousName: nil)
            XCTAssertEqual(result.name, "Research")
            XCTAssertTrue(result.symbol?.utf16.elementsEqual(icon.utf16) == true)
        }
        XCTAssertNil(ListIcon.emoji("1"))
        XCTAssertNil(ListIcon.emoji("©"))
        XCTAssertNil(ListIcon.emoji("🧪📚"))
        XCTAssertNil(ListIcon.emoji("list.bullet"))
        let unchanged = ListIcon.resolvingName("🧩 Legacy", symbol: nil, previousName: "🧩 Legacy")
        XCTAssertEqual(unchanged.name, "🧩 Legacy")
        XCTAssertNil(unchanged.symbol)
        let explicit = ListIcon.resolvingName("🧩 Renamed", symbol: "star", previousName: "Legacy")
        XCTAssertEqual(explicit.name, "🧩 Renamed")
        XCTAssertEqual(explicit.symbol, "star")
        let onlyEmoji = ListIcon.resolvingName(" 🧩 ", symbol: nil, previousName: nil)
        XCTAssertEqual(onlyEmoji.name, "🧩")
        XCTAssertNil(onlyEmoji.symbol)
    }

    func testTypedMarkdownInlineKeepsUnicodeAndExistingStyles() throws {
        let text = "**e\u{301} 🧩**"
        let interior = "e\u{301} 🧩"
        let body = RichBody(text: text, runs: [.init(location: 2, length: 2, underline: true)],
                            blocks: [.init(location: 0, length: text.utf16.count, heading: 2)])
        let range = NSRange(location: text.utf16.count, length: 0)
        let change = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: range, in: body))
        let actual = try RichBodyEdit.applying([change.edit], to: body.text, rich: body)
        XCTAssertTrue(RichBody.sameCodeUnits(actual.text, interior + " "))
        XCTAssertEqual(change.caret, NSRange(location: interior.utf16.count + 1, length: 0))
        XCTAssertEqual(actual.runs, [.init(location: 0, length: 2, bold: true, underline: true),
                                     .init(location: 2, length: interior.utf16.count - 2, bold: true)])
        XCTAssertEqual(actual.blocks, [.init(location: 0, length: actual.text.utf16.count, heading: 2)])
        for (source, format) in [("*italic*", RichInlineFormat.italic), ("==marked==", .highlight), ("~~cut~~", .strikethrough)] {
            let original = RichBody(text: source)
            let caret = NSRange(location: source.utf16.count, length: 0)
            let typed = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: caret, in: original))
            let formatted = try RichBodyEdit.applying([typed.edit], to: source, rich: original)
            let run = try XCTUnwrap(formatted.runs.first)
            XCTAssertEqual(run.italic, format == .italic)
            XCTAssertEqual(run.highlight, format == .highlight)
            XCTAssertEqual(run.strikethrough, format == .strikethrough)
        }
        for literal in ["x*word*", "\\**escaped**", "***nested***", "`**code**`", "```text\n**code**"] {
            let caret = NSRange(location: literal.utf16.count, length: 0)
            XCTAssertNil(RichMarkdownTyping.change(for: " ", at: caret, in: RichBody(text: literal)))
        }
        XCTAssertNil(RichMarkdownTyping.change(for: " ", at: NSRange(location: range.location - 1, length: 1), in: body))
    }

    func testTypedMarkdownArmsParagraphUpgradesBulletAndPreservesCRLF() throws {
        var body = RichBody(text: "Lead\r\n-\r\nTail", blocks: [.init(location: 9, length: 4, quote: true)])
        func apply(_ change: RichMarkdownTyping.Change) throws {
            body = try RichBodyEdit.applying([change.edit], to: body.text, rich: body)
        }
        let bullet = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: NSRange(location: 7, length: 0), in: body))
        try apply(bullet)
        XCTAssertEqual(body.text, "Lead\r\n\r\nTail")
        let bulletArm = try XCTUnwrap(bullet.armedParagraph)
        let checkbox = try XCTUnwrap(bulletArm.inserting("[ ]", at: bullet.caret, in: body))
        try apply(checkbox)
        XCTAssertEqual(body.blocks.first?.list, .bullet)
        let checklist = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: checkbox.caret, in: body))
        try apply(checklist)
        let checklistArm = try XCTUnwrap(checklist.armedParagraph)
        XCTAssertNil(checklistArm.inserting("wrong", at: NSRange(location: 0, length: 0), in: body))
        try apply(XCTUnwrap(checklistArm.inserting("Work", at: checklist.caret, in: body)))
        XCTAssertEqual(body.text, "Lead\r\nWork\r\nTail")
        XCTAssertEqual(body.blocks, [.init(location: 6, length: 6, list: .checklist), .init(location: 12, length: 4, quote: true)])

        body = RichBody(text: "Above\r\n--\r\nBelow")
        let rule = try XCTUnwrap(RichMarkdownTyping.change(for: "-", at: NSRange(location: 9, length: 0), in: body))
        try apply(rule)
        XCTAssertEqual(body.text, "Above\r\n\r\nBelow")
        XCTAssertEqual(body.blocks, [.init(location: 7, length: 2, rule: true)])
        XCTAssertEqual(rule.caret.location, 9)
        for (marker, block) in [("######", RichBlockRun(location: 0, length: 1, heading: 6)),
                                ("1.", .init(location: 0, length: 1, list: .numbered)),
                                (">", .init(location: 0, length: 1, quote: true))] {
            body = RichBody(text: marker)
            let prefix = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: NSRange(location: marker.utf16.count, length: 0), in: body))
            try apply(prefix)
            XCTAssertEqual(body.text, "")
            let arm = try XCTUnwrap(prefix.armedParagraph)
            try apply(XCTUnwrap(arm.inserting("X", at: prefix.caret, in: body)))
            XCTAssertEqual(body.blocks, [block])
        }
    }

    func testPlainClipboardRecognizesSupportedMarkdownAndKeepsExactUnicode() throws {
        let text = "## Plan **e\u{301} 🧩**\r\n- First\n1. Open\n2. Review\n> Reference\nVisit https://example.test/task. *literal*"
        let expected = "Plan e\u{301} 🧩\r\nFirst\nOpen\nReview\nReference\nVisit https://example.test/task. *literal*"
        let fragment = try XCTUnwrap(RichBodyClipboard.formattedPlainText(text, replacing: NSRange(), in: ""))
        XCTAssertTrue(RichBody.sameCodeUnits(fragment.text, expected))
        let preview = try XCTUnwrap(RichDescriptionPreview(body: expected, rich: fragment))
        XCTAssertEqual(preview.paragraphs.first?.heading, 2)
        XCTAssertEqual(preview.paragraphs.compactMap(\.marker), [.bullet, .number(1), .number(2)])
        XCTAssertTrue(preview.paragraphs[4].quote)
        XCTAssertEqual(preview.inline.map { (expected as NSString).substring(with: NSRange(location: $0.location, length: $0.length)) },
                       ["e\u{301} 🧩", "https://example.test/task"])
        XCTAssertTrue(preview.inline[0].bold)
        XCTAssertEqual(preview.inline[1].link, "https://example.test/task")
        XCTAssertEqual(try RichBodyEdit.applying([.paste(NSRange(), fragment: fragment)], to: "", rich: nil), fragment)
    }

    func testPlainClipboardPreservesFencesAndLiteralSameEditorText() throws {
        let literal = "```text\n# **code**\nhttps://example.test\n```\n    - **code**\n- [ ] Unchecked\n- [x] Checked\n*italic* \\**escaped** `**code**`"
        XCTAssertNil(RichBodyClipboard.formattedPlainText(literal, replacing: NSRange(), in: ""))
        let styled = try XCTUnwrap(RichBodyClipboard.formattedPlainText(literal + "\n# Heading", replacing: NSRange(), in: ""))
        XCTAssertEqual(styled.text, literal + "\nHeading")
        XCTAssertEqual(styled.blocks.count, 1)
        XCTAssertTrue(styled.runs.isEmpty)
        let plain = RichBody(text: "# Intentionally literal **text**")
        let encoded = try XCTUnwrap(RichBodyClipboard.encode(plain))
        XCTAssertEqual(RichBodyClipboard.decode(encoded, matching: plain.text), plain)
    }

    func testRichHighlightColorsPreserveInlineStylesAndProtectClipboardAndWorkspace() throws {
        let text = "e\u{301}🧩 yellow"
        let first = NSRange(location: 0, length: 4)
        let second = NSRange(location: 5, length: 6)
        let rich = RichBody(text: text, runs: [
            .init(location: first.location, length: first.length, bold: true, code: true),
            .init(location: second.location, length: second.length, highlight: true),
        ])
        let colored = try RichBodyEdit.applying([.setHighlight(.blue, first), .setHighlight(.pink, first)], to: text, rich: rich)
        XCTAssertTrue(RichBody.sameCodeUnits(colored.text, text))
        XCTAssertEqual(colored.runs.map(\.effectiveHighlight), [.pink, .yellow])
        XCTAssertTrue(colored.runs[0].bold && colored.runs[0].code)
        XCTAssertNil(colored.runs[1].highlightColor)
        let removed = try RichBodyEdit.applying([.setHighlight(nil, first)], to: text, rich: colored)
        XCTAssertEqual(removed, rich)

        let payload = try XCTUnwrap(RichBodyClipboard.encode(colored))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 3)
        let decoded = try XCTUnwrap(RichBodyClipboard.decode(payload, matching: text))
        XCTAssertEqual(decoded, colored)
        let pasted = try RichBodyEdit.applying([.paste(NSRange(location: 0, length: 5), fragment: decoded)],
                                               to: "Prior", rich: nil)
        XCTAssertEqual(pasted, colored)
        object["version"] = 1
        XCTAssertNil(RichBodyClipboard.decode(try JSONSerialization.data(withJSONObject: object), matching: text))

        let workspace = WorkspaceData(tasks: [.init(title: "Highlighted", body: text, richBody: colored)])
        let bytes = try JSONEncoder().encode(workspace)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual((saved["tasks"] as? [String: Any])?["format"] as? String, "richHighlightColorsV1")
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: bytes), workspace)
        let legacy = WorkspaceData(tasks: [.init(title: "Yellow", body: text, richBody: rich)])
        let legacyBytes = try JSONEncoder().encode(legacy)
        let legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyBytes) as? [String: Any])
        XCTAssertNotNil(legacyObject["tasks"] as? [[String: Any]])
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: legacyBytes), legacy)
    }

    func testFencedCodePastePreservesExactBytesAndSeparateBlockIdentity() throws {
        let first = "  let value = **e\u{301} 🧩**\r\n\tprint(value)\r\n"
        let second = "# literal\r\n"
        let source = "```\r\n" + first + "```\r\n```\r\n" + second + "```"
        let fragment = try XCTUnwrap(RichBodyClipboard.formattedPlainText(source, replacing: NSRange(), in: ""))
        let body = try RichBodyEdit.applying([.paste(NSRange(), fragment: fragment)], to: "", rich: nil)
        XCTAssertTrue(RichBody.sameCodeUnits(body.text, first + second))
        XCTAssertTrue(body.runs.isEmpty)
        let preview = try XCTUnwrap(RichDescriptionPreview(body: body.text, rich: body))
        XCTAssertEqual(preview.codeBlocks.map(\.text), [first, second])
        XCTAssertNil(RichMarkdownTyping.change(for: " ", at: NSRange(location: first.utf16.count + 1, length: 0), in: body))
        let encoded = try XCTUnwrap(RichBodyClipboard.encode(body))
        let pasted = try XCTUnwrap(RichBodyClipboard.decode(encoded, matching: body.text))
        XCTAssertNotEqual(pasted.blocks[0].codeBlockID, body.blocks[0].codeBlockID)
        XCTAssertEqual(pasted.blocks[0].codeBlockID, pasted.blocks[1].codeBlockID)
        XCTAssertNotEqual(pasted.blocks[1].codeBlockID, pasted.blocks[2].codeBlockID)
        XCTAssertNil(RichBodyClipboard.formattedPlainText("```\nbody", replacing: NSRange(), in: ""))
        XCTAssertNil(RichBodyClipboard.formattedPlainText("```\n```", replacing: NSRange(), in: ""))
        XCTAssertNil(RichBodyClipboard.formattedPlainText("```\nbody\n```", replacing: NSRange(location: 3, length: 0), in: "pre"))
    }

    func testTypedCodeFenceContinuesAndClosesBeforeExistingText() throws {
        let initial = "Before\r\n```\r\nAfter"
        var body = RichBody(text: initial)
        var caret = NSRange(location: "Before\r\n```".utf16.count, length: 0)
        func pressReturn() throws {
            let change = try XCTUnwrap(RichMarkdownTyping.change(for: "\n", at: caret, in: body))
            body = try RichBodyEdit.applying([change.edit], to: body.text, rich: body)
            caret = change.caret
        }
        func type(_ text: String) throws {
            body = try RichBodyEdit.applying([.replace(caret, with: text, style: .inherit)], to: body.text, rich: body)
            caret.location += text.utf16.count
        }
        try pressReturn()
        XCTAssertTrue(RichBody.sameCodeUnits(body.text, "Before\r\n\r\nAfter"))
        let blockID = try XCTUnwrap(body.blocks.first?.codeBlockID)
        XCTAssertTrue(body.isInCodeParagraph(at: caret.location))
        try type("  let é = 🧩")
        try pressReturn()
        try type("#")
        XCTAssertNil(RichMarkdownTyping.change(for: " ", at: caret, in: body))
        try type(" literal")
        try pressReturn()
        try type("```swift")
        try pressReturn()
        try type("```")
        try pressReturn()
        XCTAssertFalse(body.isInCodeParagraph(at: caret.location))
        try type("#")
        let heading = try XCTUnwrap(RichMarkdownTyping.change(for: " ", at: caret, in: body))
        body = try RichBodyEdit.applying([heading.edit], to: body.text, rich: body)
        caret = heading.caret
        let content = try XCTUnwrap(heading.armedParagraph?.inserting("P", at: caret, in: body))
        body = try RichBodyEdit.applying([content.edit], to: body.text, rich: body)
        caret = content.caret
        try type("lain")
        let code = "  let é = 🧩\r\n# literal\r\n```swift\r\n"
        XCTAssertTrue(RichBody.sameCodeUnits(body.text, "Before\r\n" + code + "Plain\r\nAfter"))
        XCTAssertEqual(body.blocks.compactMap(\.codeBlockID), [blockID, blockID, blockID])
        XCTAssertEqual(body.blocks.last?.heading, 1)
        XCTAssertEqual(try XCTUnwrap(RichDescriptionPreview(body: body.text, rich: body)).codeBlocks.map(\.text), [code])
    }

    func testTypedCodeFenceHandlesFinalAndLiteralParagraphs() throws {
        let raw = RichBody(text: "```")
        let start = try XCTUnwrap(RichMarkdownTyping.change(for: "\n", at: NSRange(location: 3, length: 0), in: raw))
        let opened = try RichBodyEdit.applying([start.edit], to: raw.text, rich: raw)
        XCTAssertEqual(start.caret, NSRange(location: 0, length: 0))
        XCTAssertEqual(opened.text, "\n")
        XCTAssertTrue(opened.isInCodeParagraph(at: 0))
        let final = RichBody(text: "print()", blocks: [.init(location: 0, length: 7, codeBlockID: UUID())])
        let next = try XCTUnwrap(RichMarkdownTyping.change(for: "\n", at: NSRange(location: 7, length: 0), in: final))
        let continued = try RichBodyEdit.applying([next.edit], to: final.text, rich: final)
        XCTAssertEqual(continued.text, "print()\n\n")
        XCTAssertTrue(continued.isInCodeParagraph(at: next.caret.location))
        let closing = try RichBodyEdit.applying([.replace(next.caret, with: "```", style: .inherit)], to: continued.text, rich: continued)
        let finish = try XCTUnwrap(RichMarkdownTyping.change(for: "\n", at: NSRange(location: 11, length: 0), in: closing))
        let closed = try RichBodyEdit.applying([finish.edit], to: closing.text, rich: closing)
        XCTAssertEqual(closed.text, "print()\n")
        XCTAssertFalse(closed.isInCodeParagraph(at: finish.caret.location))
        for literal in [" ```", "```swift", "x```", "~~~", "```swift\n```"] {
            let caret = NSRange(location: literal.utf16.count, length: 0)
            XCTAssertNil(RichMarkdownTyping.change(for: "\n", at: caret, in: RichBody(text: literal)))
        }
    }

    func testCodeBlockStyleCanClearAndWorkspaceProtectsTheCompanion() throws {
        let text = "echo a\necho b\nPlain"
        let selected = NSRange(location: 0, length: 14)
        let plain = RichBody(text: text)
        let edit = try XCTUnwrap(RichBodyEdit.togglingCodeBlock(in: plain, selection: selected))
        let styled = try RichBodyEdit.applying([edit], to: text, rich: nil)
        let merged = try RichBodyEdit.applying([.replace(NSRange(location: 6, length: 1), with: "; ", style: .inherit)],
                                               to: text, rich: styled)
        let preview = try XCTUnwrap(RichDescriptionPreview(body: merged.text, rich: merged))
        XCTAssertEqual(preview.codeBlocks.map(\.text), ["echo a; echo b\n"])
        let clear = try XCTUnwrap(RichBodyEdit.togglingCodeBlock(in: styled, selection: selected))
        let cleared = try RichBodyEdit.applying([clear], to: text, rich: styled)
        XCTAssertEqual(cleared, plain)

        let workspace = WorkspaceData(tasks: [TaskItem(title: "Snippet", body: text, richBody: styled)])
        let bytes = try JSONEncoder().encode(workspace)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var envelope = try XCTUnwrap(object["tasks"] as? [String: Any])
        XCTAssertEqual(envelope["format"] as? String, "richCodeBlocksV1")
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: bytes), workspace)
        envelope["format"] = "listSectionsV1"
        object["tasks"] = envelope
        XCTAssertThrowsError(try JSONDecoder().decode(WorkspaceData.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testPlainClipboardOnlyConvertsCompleteDestinationParagraphs() throws {
        let range = NSRange(location: 7, length: 0)
        let destination = "Before after"
        let fragment = try XCTUnwrap(RichBodyClipboard.formattedPlainText("# Joined\n> Independent\n- Joined", replacing: range,
                                                                         in: destination))
        XCTAssertEqual(fragment.text, "# Joined\nIndependent\n- Joined")
        let pasted = try RichBodyEdit.applying([.paste(range, fragment: fragment)], to: destination, rich: nil)
        XCTAssertEqual(pasted.text, "Before # Joined\nIndependent\n- Joinedafter")
        XCTAssertEqual(pasted.blocks.count, 1)
        XCTAssertTrue(pasted.blocks[0].quote)
    }

    func testRichPasteReplacesWholeStyledParagraphAndKeepsFollowingBlock() throws {
        let body = RichBody(text: "Old\nNeighbor",
                            runs: [.init(location: 4, length: 8, italic: true)],
                            blocks: [.init(location: 0, length: 4, heading: 1),
                                     .init(location: 4, length: 8, quote: true)])
        let fragment = RichBody(text: "Plan\nTask\n",
                                runs: [.init(location: 0, length: 4, bold: true)],
                                blocks: [.init(location: 0, length: 5, heading: 3),
                                         .init(location: 5, length: 5, list: .checklist, checked: true)])
        let edit = RichBodyEdit.paste(NSRange(location: 0, length: 4), fragment: fragment)
        let replay = try JSONDecoder().decode(RichBodyEdit.self, from: JSONEncoder().encode(edit))
        let result = try RichBodyEdit.applying([replay], to: body.text, rich: body)
        XCTAssertEqual(result.text, "Plan\nTask\nNeighbor")
        XCTAssertEqual(result.blocks, fragment.blocks + [.init(location: 10, length: 8, quote: true)])
        XCTAssertEqual(result.runs, fragment.runs + [.init(location: 10, length: 8, italic: true)])
    }

    func testRichPasteKeepsDestinationParagraphWhenItJoinsExistingText() throws {
        let body = RichBody(text: "Note", blocks: [.init(location: 0, length: 4, heading: 2)])
        let fragment = RichBody(text: "X", runs: [.init(location: 0, length: 1, italic: true)],
                                blocks: [.init(location: 0, length: 1, list: .bullet)])
        let result = try RichBodyEdit.applying([.paste(NSRange(location: 2, length: 0), fragment: fragment)],
                                                to: body.text, rich: body)
        XCTAssertEqual(result.text, "NoXte")
        XCTAssertEqual(result.blocks, [.init(location: 0, length: 5, heading: 2)])
        XCTAssertEqual(result.runs, [.init(location: 2, length: 1, italic: true)])
        let invalid = RichBody(text: "X", runs: [.init(location: 0, length: 1, link: "javascript:bad")])
        XCTAssertThrowsError(try RichBodyEdit.applying([.paste(NSRange(location: 0, length: 0), fragment: invalid)],
                                                        to: body.text, rich: body))
    }

    func testRichEditNativeDeltaPreservesExactScalarBoundaries() throws {
        let original = "e\u{301} 🧩 text"
        let replacement = "é 🚀 text"
        let operation = try XCTUnwrap(RichBodyEdit.replacement(from: original, to: replacement, style: .inherit))
        let result = try RichBodyEdit.applying([operation], to: original, rich: nil)
        XCTAssertTrue(RichBody.sameCodeUnits(result.text, replacement))
        let emojiOnly = try XCTUnwrap(RichBodyEdit.replacement(from: "🚀", to: "🚁", style: .inherit))
        let emojiResult = try RichBodyEdit.applying([emojiOnly], to: "🚀", rich: nil)
        XCTAssertEqual(emojiResult.text, "🚁")
        XCTAssertNil(RichBodyEdit.replacement(from: replacement, to: replacement, style: .inherit))
    }

    func testRichEditNativeRangeKeepsIdenticalTextOnTheCorrectSideOfFormatting() throws {
        let source = "aaa"
        let original = RichBody(text: source, runs: [.init(location: 1, length: 2, bold: true)])
        let inserted = try XCTUnwrap(RichBodyEdit.replacement(from: source, to: "aaaa", style: .inherit,
                                                              replacing: NSRange(location: 1, length: 0)))
        let insertion = try RichBodyEdit.applying([inserted], to: source, rich: original)
        XCTAssertEqual(insertion.runs, [.init(location: 2, length: 2, bold: true)])

        let deleted = try XCTUnwrap(RichBodyEdit.replacement(from: source, to: "aa", style: .inherit,
                                                             replacing: NSRange(location: 0, length: 1)))
        let deletion = try RichBodyEdit.applying([deleted], to: source, rich: original)
        XCTAssertEqual(deletion.runs, [.init(location: 0, length: 2, bold: true)])
    }

    func testRichEditRefusesAmbiguousOrMalformedRangesBeforeChangingText() throws {
        let source = "🧩\nNext"
        let valid = RichBody(text: source, blocks: [.init(location: 0, length: 3, quote: true)])
        let attempts: [(RichBodyEdit, RichBodyEditError)] = [
            (.toggle(.bold, NSRange(location: 1, length: 1)), .invalidRange),
            (.replace(NSRange(location: 2, length: 1), with: "", style: .inherit), .styledParagraphBoundary),
            (.paragraph(.horizontalRule(true), NSRange(location: 0, length: 0)), .invalidParagraph),
        ]
        for (edit, expected) in attempts {
            XCTAssertThrowsError(try RichBodyEdit.applying([edit], to: source, rich: valid)) {
                XCTAssertEqual($0 as? RichBodyEditError, expected)
            }
        }
        let invalid = RichBody(text: source, runs: [.init(location: 1, length: 1, bold: true)])
        XCTAssertThrowsError(try RichBodyEdit.applying([.clearInline(NSRange(location: 0, length: 2))],
                                                     to: source, rich: invalid)) {
            XCTAssertEqual($0 as? RichBodyEditError, .invalidSource)
        }
    }

    func testSummaryPresetsRoundTripEveryOptionAndPreserveIdentity() throws {
        let start = date("2026-10-12T03:00:00Z")
        let options = SummaryReportOptions(period: .custom, customStart: start, customEnd: now,
                                           listIDs: [UUID(), TaskFilter.inboxListID], status: .wontDo,
                                           grouping: .date, fields: [.progress, .completionDate], nextPeriod: true,
                                           tagIDs: [UUID(), UUID()], priorities: [.none, .high], sort: .title)
        var presets = try XCTUnwrap(SummaryReportPresets(stored: Data()))
        XCTAssertFalse(presets.save(" \n", options: options))
        XCTAssertTrue(presets.save("  November review ", options: options))
        XCTAssertFalse(presets.save("november review", options: options))
        XCTAssertTrue(presets.save("Daily", options: SummaryReportOptions(period: .today, customStart: start, customEnd: start)))
        let saved = try XCTUnwrap(presets.entries.first)
        XCTAssertEqual(saved.name, "November review")
        XCTAssertFalse(presets.rename(saved.id, to: "DAILY"))
        XCTAssertFalse(presets.rename(UUID(), to: "Unknown"))
        XCTAssertTrue(presets.rename(saved.id, to: "October–November review"))

        let bytes = try presets.encoded()
        var reloaded = try XCTUnwrap(SummaryReportPresets(stored: bytes))
        XCTAssertEqual(reloaded, presets)
        XCTAssertEqual(reloaded.entries.first?.id, saved.id)
        XCTAssertEqual(reloaded.entries.first?.options, options)
        XCTAssertEqual(reloaded.entries.first?.name, "October–November review")
        let relative = try XCTUnwrap(reloaded.entries.last?.options)
        XCTAssertNotEqual(relative.interval(now: start, calendar: calendar), relative.interval(now: now, calendar: calendar))
        XCTAssertEqual(options.interval(now: start, calendar: calendar), options.interval(now: now, calendar: calendar))
        reloaded.remove(saved.id)
        XCTAssertEqual(reloaded.entries.map(\.name), ["Daily"])
        XCTAssertNil(SummaryReportPresets(stored: Data("{\"entries\":[{}]}".utf8)))
    }

    func testSummaryUsesPeriodHistoryAndExplicitArchiveSelection() {
        let archived = TaskList(name: "Archive", color: "#123456", isArchived: true)
        let excluded = TaskList(name: "Excluded", color: "#123456", showsInSmartLists: false)
        let done = TaskItem(title: "Finished", dueDate: date("2026-11-04T08:00:00Z"), completedAt: now)
        let archive = TaskItem(title: "Archived report item", listID: archived.id, dueDate: now, completedAt: now)
        let excludedTask = TaskItem(title: "Excluded report item", listID: excluded.id, dueDate: now, completedAt: now)
        let note = TaskItem(title: "Report note", kind: .note, dueDate: now)
        let trash = TaskItem(title: "Trashed report item", dueDate: now, deletedAt: now)
        let data = WorkspaceData(tasks: [done, archive, excludedTask, note, trash], lists: [archived, excluded])
        var options = SummaryReportOptions(period: .today, customStart: now, customEnd: now, status: .completed, fields: [])
        let report = SummaryReport.generate(from: data, options: options, now: now, calendar: calendar)
        XCTAssertEqual(report.text, "Summary · " + report.range + "\n\nCompleted\n- Finished")
        options.listIDs = [archived.id, excluded.id]
        options.grouping = .list
        let explicit = SummaryReport.generate(from: data, options: options, now: now, calendar: calendar)
        XCTAssertEqual(explicit.text, "Summary · " + explicit.range +
            "\n\nArchive\n- Archived report item\n\nExcluded\n- Excluded report item")
    }

    func testSummaryCustomDaysAndNextPeriodRespectExclusiveEnd() {
        let start = date("2026-11-08T00:00:00Z"), end = date("2026-11-10T00:00:00Z")
        let tag = TaskTag(name: "Planning", color: "#123456")
        let current = TaskItem(title: "Review", body: "A composed e\u{301}\nSecond line", tagIDs: [tag.id],
                               dueDate: end.addingTimeInterval(-1), priority: .high)
        let next = TaskItem(title: "Next", dueDate: end)
        let future = TaskItem(title: "Future", dueDate: date("2026-11-12T00:00:00Z"))
        let options = SummaryReportOptions(period: .custom, customStart: now, customEnd: start, fields: [.tags, .priority, .description], nextPeriod: true)
        XCTAssertEqual(options.interval(now: now, calendar: calendar), DateInterval(start: start, end: end))
        let report = SummaryReport.generate(from: WorkspaceData(tasks: [current, next, future], tags: [tag]),
                                            options: options, now: now, calendar: calendar)
        let expected = "Summary · " + report.range +
            "\n\nUndone\n- Review (#Planning · High priority)\n  A composed e\u{301}\n  Second line" +
            "\n\nNext Period Tasks\n- Next"
        XCTAssertTrue(RichBody.sameCodeUnits(report.text, expected))
    }

    func testSummaryUsesReportZoneForHeadingsAndFloatingDueDates() {
        var reportCalendar = calendar
        reportCalendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        let boundary = date("2026-11-09T11:30:00Z")
        let floating = TaskItem(title: "Floating", dueDate: boundary, hasDueTime: true)
        let explicit = TaskItem(title: "New York", dueDate: boundary, hasDueTime: true,
                                timeZoneID: "America/New_York")
        let options = SummaryReportOptions(period: .today, customStart: boundary, customEnd: boundary,
                                           grouping: .date, fields: [.date])
        let report = SummaryReport.generate(from: WorkspaceData(tasks: [floating, explicit]), options: options,
                                            now: boundary, calendar: reportCalendar)
        let heading = boundary.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                          calendar: reportCalendar, timeZone: reportCalendar.timeZone))
        XCTAssertEqual(reportCalendar.component(.day, from: boundary), 10)
        XCTAssertEqual(report.range, "\(heading) – \(heading)")
        XCTAssertTrue(report.text.contains("\n\(heading)\n"))

        func due(in zone: TimeZone) -> String {
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            let day = formatter.string(from: boundary)
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return day + " " + formatter.string(from: boundary)
        }
        let newYork = TimeZone(identifier: "America/New_York")!
        let suffix = newYork.abbreviation(for: boundary) ?? newYork.identifier
        XCTAssertTrue(report.text.contains("- Floating (\(due(in: reportCalendar.timeZone)))"))
        XCTAssertTrue(report.text.contains("- New York (\(due(in: newYork)) \(suffix))"))
    }

    func testSummaryCaptureKeepsExactTextAndBypassesCreationDefaults() throws {
        let list = TaskList(name: "Work", color: "#123456")
        let tag = TaskTag(name: "Planning", color: "#123456")
        var settings = AppSettings()
        settings.defaultListID = list.id
        settings.defaultTagID = tag.id
        settings.defaultDate = .today
        settings.defaultPriority = .high
        let text = "Summary\nA composed e\u{301} and #Planning tomorrow."
        let input = TaskCaptureInput.summaryNote(title: "Summary tomorrow #Planning", body: text)
        let note = try input.task(id: UUID(), now: now, workspace: WorkspaceData(lists: [list], tags: [tag]), settings: settings, calendar: calendar)
        XCTAssertTrue(RichBody.sameCodeUnits(note.body, text))
        XCTAssertEqual(note.title, "Summary tomorrow #Planning")
        XCTAssertEqual(note.kind, .note)
        XCTAssertNil(note.listID)
        XCTAssertNil(note.dueDate)
        XCTAssertEqual(note.priority, .none)
        XCTAssertTrue(note.tagIDs.isEmpty)
        XCTAssertTrue(note.reminderDates.isEmpty)
    }

    func testTodayAndWeekIncludeOverdueWhileSavedDatesStayBounded() {
        let overdue = TaskItem(title: "Overdue", dueDate: date("2026-11-01T10:00:00Z"))
        let today = TaskItem(title: "Today", dueDate: date("2026-11-09T10:00:00Z"))
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: date("2026-11-10T10:00:00Z"))
        let boundary = TaskItem(title: "Outside week", dueDate: date("2026-11-16T00:00:00Z"))
        let data = WorkspaceData(tasks: [overdue, today, tomorrow, boundary])
        XCTAssertEqual(ids(TaskDestination.today.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id])
        XCTAssertEqual(ids(TaskDestination.week.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id, tomorrow.id])
        let filter = TaskFilter(name: "Today", dateRule: .today)
        XCTAssertFalse(filter.matches(overdue, lists: [], now: now, calendar: calendar))
        XCTAssertTrue(filter.matches(today, lists: [], now: now, calendar: calendar))
    }

    func testHistoryAndArchiveExceptionsArePreserved() {
        let archived = TaskList(name: "Archived", color: "#000000", isArchived: true)
        let excluded = TaskList(name: "Excluded", color: "#000000", showsInSmartLists: false)
        let hidden = TaskItem(title: "Hidden", listID: excluded.id)
        var history = TaskItem(title: "Archived history", listID: archived.id); history.completedAt = now
        var trashed = TaskItem(title: "Trashed"); trashed.deletedAt = now
        let data = WorkspaceData(tasks: [hidden, history, trashed], lists: [archived, excluded])
        XCTAssertTrue(TaskDestination.all.matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.completed.matchingTasks(in: data, now: now, calendar: calendar)), [history.id])
        XCTAssertEqual(ids(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: true, now: now, calendar: calendar)), [history.id])
        XCTAssertTrue(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.trash.matchingTasks(in: data, now: now, calendar: calendar)), [trashed.id])
    }

    func testParentTagNavigationDiffersFromSelectedTagFilter() {
        let parent = TaskTag(name: "Parent", color: "#000000")
        let child = TaskTag(name: "Child", color: "#000000", parentID: parent.id)
        var task = TaskItem(title: "Child tagged"); task.tagIDs = [child.id]
        let data = WorkspaceData(tasks: [task], tags: [parent, child])
        XCTAssertEqual(ids(TaskDestination.tag(parent.id).matchingTasks(in: data, now: now, calendar: calendar)), [task.id])
        XCTAssertFalse(TaskFilter(name: "Direct tag", tagIDs: [parent.id]).matches(task, lists: [], now: now, calendar: calendar))
    }

    func testMissingFilterRemainsEmptyAndExistingFilterUsesOwnStatus() {
        var task = TaskItem(title: "History"); task.completedAt = now
        let filter = TaskFilter(name: "Completed", status: .completed)
        let data = WorkspaceData(tasks: [task], filters: [filter])
        XCTAssertTrue(TaskDestination.filter(UUID()).matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.filter(filter.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar)), [task.id])
    }

    func testTaskZoneDefinesRelativeDateMembership() {
        var task = TaskItem(title: "Tokyo tomorrow", dueDate: date("2026-11-09T16:00:00Z"))
        task.timeZoneID = "Asia/Tokyo"
        let data = WorkspaceData(tasks: [task])
        XCTAssertFalse(TaskDestination.today.includes(task, data: data, now: now, calendar: calendar))
        XCTAssertTrue(TaskDestination.tomorrow.includes(task, data: data, now: now, calendar: calendar))
    }

    func testLegacyMonthAndLeapAnchorsSurvivePureExtraction() {
        let feb = LegacyRecurrence.nextDate(after: date("2026-01-31T10:00:00Z"), rule: .monthly, anchorDay: 31, calendar: calendar)!
        XCTAssertEqual(feb, date("2026-02-28T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: feb, rule: .monthly, anchorDay: 31, calendar: calendar), date("2026-03-31T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2024-02-29T10:00:00Z"), rule: .yearly, anchorDay: 29, anchorMonth: 2, calendar: calendar), date("2025-02-28T10:00:00Z"))
    }

    func testLegacyDailyKeepsWallClockAcrossDST() {
        var local = calendar; local.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2026-03-07T14:00:00Z"), rule: .daily, calendar: local), date("2026-03-08T13:00:00Z"))
    }

    func testPlainRichIdentityAndPreciseScheduleRemainPortable() {
        let composed = "é", decomposed = "e\u{301}"
        XCTAssertNil(RichBody(text: composed).valid(for: decomposed))
        var task = TaskItem(title: "Precise", dueDate: now)
        task.hasDueTime = true
        task.scheduledDuration = TaskDurationRange(start: now.addingTimeInterval(-301.125), end: now, isAllDay: false)
        let draft = CalendarScheduleDraft(task: task, focus: now, hourly: true, calendar: calendar)
        XCTAssertNil(draft.operation)
        XCTAssertEqual(draft.start, task.scheduledDuration?.start)
    }
}

extension MobileContractTests {
    func testRichPreviewKeepsExactTextAndProjectsParagraphDecorations() throws {
        let body = "Title\nFirst 🧩\nSecond\nPlain e\u{301}\nThird\nChecked\n\nQuote"
        let text = body as NSString
        func block(_ phrase: String, heading: Int? = nil, quote: Bool = false,
                   list: RichListStyle? = nil, checked: Bool? = nil) -> RichBlockRun {
            let range = text.paragraphRange(for: text.range(of: phrase))
            return .init(location: range.location, length: range.length, heading: heading, quote: quote, list: list, checked: checked)
        }
        let emoji = text.range(of: "🧩")
        let rich = RichBody(text: body, runs: [.init(location: emoji.location, length: emoji.length, bold: true, highlight: true)],
                            blocks: [block("Title", heading: 6), block("First", list: .numbered), block("Second", list: .numbered),
                                     block("Third", list: .numbered), block("Checked", list: .checklist, checked: true),
                                     .init(location: text.range(of: "\n\n").location + 1, length: 1, rule: true),
                                     block("Quote", quote: true)])
        let preview = try XCTUnwrap(RichDescriptionPreview(body: body, rich: rich))
        XCTAssertTrue(RichBody.sameCodeUnits(preview.text, body))
        XCTAssertEqual(preview.inline, rich.runs)
        XCTAssertEqual(preview.paragraphs.map(\.marker), [nil, .number(1), .number(2), nil, .number(1), .checklist(checked: true), nil, nil])
        XCTAssertEqual(preview.paragraphs.first?.heading, 6)
        XCTAssertEqual(preview.paragraphs.last?.quote, true)
        XCTAssertTrue(preview.paragraphs[6].rule)
        XCTAssertEqual(preview.paragraphs.map { text.substring(with: $0.range) }.joined().utf16.map { $0 }, Array(body.utf16))
    }

    func testRichPreviewRefusesWrongMirroredTextAndMalformedUTF16Ranges() {
        let body = "e\u{301} 🧩"
        let rich = RichBody(text: body, runs: [.init(location: 0, length: 2, bold: true)])
        XCTAssertNil(RichDescriptionPreview(body: "é 🧩", rich: rich))
        for run in [RichInlineRun(location: 0, length: .max, bold: true),
                    .init(location: -1, length: 2, bold: true),
                    .init(location: 3, length: 1, bold: true),
                    .init(location: 4, length: 1, bold: true)] {
            XCTAssertNil(RichDescriptionPreview(body: body, rich: RichBody(text: body, runs: [run])))
        }
        let malformed = RichBody(text: body, blocks: [.init(location: 0, length: 2, heading: 7)])
        XCTAssertNil(RichDescriptionPreview(body: body, rich: malformed))
    }
}

extension MobileContractTests {
    func testTaskProgressFollowsChecklistAndNewRecurrenceResetsManualValue() throws {
        let original = TaskItem(title: "Project", dueDate: now, recurrence: .daily)
        let manual = try XCTUnwrap(TaskMetadataChange.progress(73).applying(to: original, availableTags: []))
        XCTAssertEqual(manual.progressPercent, 73)
        XCTAssertNil(manual.completedAt)
        XCTAssertNil(try TaskMetadataChange.progress(73).applying(to: manual, availableTags: []))
        XCTAssertThrowsError(try TaskMetadataChange.progress(101).applying(to: manual, availableTags: [])) {
            XCTAssertEqual($0 as? TaskMetadataValidation, .invalidProgress)
        }

        let steps = [ChecklistItem(title: "Plan", isCompleted: true), .init(title: "Prepare"), .init(title: "Review")]
        let checklist = try XCTUnwrap(TaskMetadataChange.checklist(steps).applying(to: manual, availableTags: []))
        XCTAssertEqual(checklist.progressPercent, 33)
        XCTAssertFalse(checklist.canEditManualProgress)
        XCTAssertThrowsError(try TaskMetadataChange.progress(40).applying(to: checklist, availableTags: [])) {
            XCTAssertEqual($0 as? TaskMetadataValidation, .unavailableProgress)
        }
        let restored = try XCTUnwrap(TaskMetadataChange.checklist([]).applying(to: checklist, availableTags: []))
        XCTAssertEqual(restored, manual)

        let child = try XCTUnwrap(TaskMetadataChange.progress(30).applying(
            to: TaskItem(title: "Child", parentID: manual.id), availableTags: []))
        var lifecycle = TaskLifecycle(data: WorkspaceData(tasks: [manual, child]))
        XCTAssertTrue(lifecycle.toggleComplete(id: manual.id, now: now, calendar: calendar))
        XCTAssertEqual(lifecycle.data.tasks.first(where: { $0.id == manual.id })?.progressPercent, 73)
        XCTAssertEqual(lifecycle.data.tasks.first(where: { $0.recurrenceSourceID == manual.id })?.progressPercent, 0)
        XCTAssertEqual(lifecycle.data.tasks.first(where: { $0.recurrenceSourceID == child.id })?.progressPercent, 0)
        XCTAssertTrue(lifecycle.reopenTask(id: manual.id, now: now + 1))
        XCTAssertEqual(lifecycle.data.tasks.first(where: { $0.id == manual.id })?.progressPercent, 73)
    }

    func testTaskProgressProtectsNewDataAndClearingRestoresLegacyEncoding() throws {
        let task = TaskItem(title: "A task")
        let legacy = WorkspaceData(tasks: [task])
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let oldBytes = try encoder.encode(legacy)
        XCTAssertEqual(try decoder.decode(WorkspaceData.self, from: oldBytes).tasks.first?.progressPercent, 0)

        let progress = try XCTUnwrap(TaskMetadataChange.progress(100).applying(to: task, availableTags: []))
        XCTAssertNil(progress.completedAt)
        let workspace = WorkspaceData(tasks: [progress])
        let bytes = try encoder.encode(workspace)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var envelope = try XCTUnwrap(object["tasks"] as? [String: Any])
        XCTAssertEqual(envelope["format"] as? String, "taskProgressV1")
        XCTAssertEqual(try decoder.decode(WorkspaceData.self, from: bytes), workspace)
        var records = try XCTUnwrap(envelope["records"] as? [[String: Any]])
        object["tasks"] = records
        XCTAssertThrowsError(try decoder.decode(WorkspaceData.self, from: JSONSerialization.data(withJSONObject: object)))
        records[0]["manualProgress"] = -1
        envelope["records"] = records
        object["tasks"] = envelope
        XCTAssertThrowsError(try decoder.decode(WorkspaceData.self, from: JSONSerialization.data(withJSONObject: object)))

        let cleared = try XCTUnwrap(TaskMetadataChange.progress(0).applying(to: progress, availableTags: []))
        XCTAssertEqual(cleared, task)
        let reopenedLegacy = try encoder.encode(WorkspaceData(tasks: [cleared]))
        XCTAssertNotNil((try JSONSerialization.jsonObject(with: reopenedLegacy) as? [String: Any])?["tasks"] as? [[String: Any]])
    }
}

extension MobileContractTests {
    func testSummaryCombinesParentTagPriorityAndListAndShowsIndependentFields() throws {
        let work = TaskList(name: "Work", color: "#445566")
        let parent = TaskTag(name: "Planning", color: "#445566")
        let child = TaskTag(name: "Nested", color: "#445566", parentID: parent.id)
        var manual = TaskItem(title: "Zeta", listID: work.id, tagIDs: [child.id], dueDate: now, priority: .high)
        manual = try XCTUnwrap(TaskMetadataChange.progress(40).applying(to: manual, availableTags: [parent, child]))
        manual.completedAt = now
        let checklist = TaskItem(title: "Alpha", listID: work.id, tagIDs: [parent.id], dueDate: now, priority: .high,
                                 checklist: [.init(title: "A", isCompleted: true), .init(title: "B"),
                                             .init(title: "C"), .init(title: "D")])
        let mismatched = [
            TaskItem(title: "Other list", tagIDs: [child.id], dueDate: now, priority: .high),
            TaskItem(title: "Other tag", listID: work.id, dueDate: now, priority: .high),
            TaskItem(title: "Other priority", listID: work.id, tagIDs: [parent.id], dueDate: now, priority: .medium),
        ]
        let data = WorkspaceData(tasks: [manual, checklist] + mismatched, lists: [work], tags: [parent, child])
        let opts = SummaryReportOptions(period: .today, customStart: now, customEnd: now, listIDs: [work.id],
                                        grouping: .list, fields: [.completionDate, .status, .progress],
                                        tagIDs: [parent.id], priorities: [.high], sort: .title)
        let report = SummaryReport.generate(from: data, options: opts, now: now, calendar: calendar)
        let day = now.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
        XCTAssertEqual(report.text, "Summary · " + report.range +
                       "\n\nWork\n- Alpha (Undone · 25% progress)\n- Zeta (Finished " + day + " · Completed · 40% progress)")
        XCTAssertEqual(data.tasks.first, manual)
    }

    func testSummarySortingKeepsTiesAndAppliesToUpcomingTasks() {
        let tomorrow = calendar.startOfDay(for: now) + 86_400
        let data = WorkspaceData(tasks: [
            .init(title: "First Low", dueDate: now, priority: .low),
            .init(title: "First High", dueDate: now - 60, priority: .high),
            .init(title: "Second High", dueDate: now + 60, priority: .high),
            .init(title: "Upcoming Low", dueDate: tomorrow + 60, priority: .low),
            .init(title: "Upcoming High", dueDate: tomorrow + 900, priority: .high),
        ])
        var opts = SummaryReportOptions(period: .today, customStart: now, customEnd: now,
                                        fields: [], nextPeriod: true, sort: .priority)
        func output() -> String { SummaryReport.generate(from: data, options: opts, now: now, calendar: calendar).text }
        XCTAssertTrue(output().contains("\n- First High\n- Second High\n- First Low\n\nNext Period Tasks\n- Upcoming High\n- Upcoming Low"))
        opts.sort = .date
        XCTAssertTrue(output().contains("\n- First High\n- First Low\n- Second High\n\nNext Period Tasks\n- Upcoming Low\n- Upcoming High"))
        opts.sort = .workspace
        XCTAssertTrue(output().contains("\n- First Low\n- First High\n- Second High\n"))
    }
}


extension MobileContractTests {
    func testBatchMetadataAndMovePreserveUnownedFieldsAndRejectInvalidSelections() throws {
        let source = TaskList(name: "Source", color: "#445566")
        let target = TaskList(name: "Target", color: "#556677")
        let archived = TaskList(name: "Archived", color: "#667788", isArchived: true)
        let tag = TaskTag(name: "Review", color: "#445566")
        let unknownTag = UUID()
        let root = TaskItem(title: "Root", body: "Styled", listID: source.id, tagIDs: [unknownTag], dueDate: now,
                            richBody: .init(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
        var child = TaskItem(title: "Child", listID: source.id, tagIDs: [tag.id])
        child.parentID = root.id
        let locked = TaskItem(title: "Archived", listID: archived.id)
        let workspace = WorkspaceData(tasks: [child, root, locked], lists: [source, target, archived], tags: [tag])
        let engine = TaskLifecycle(data: workspace)
        func edit(_ ids: [UUID], _ action: TaskBatchEdit.Action, _ baseline: TaskLifecycle) throws -> TaskLifecycle? {
            try TaskBatchEdit(ids: ids, action: action).applying(to: baseline, settings: AppSettings(), now: now + 1, calendar: calendar)
        }

        let changed = try XCTUnwrap(edit([child.id, root.id], .priority(.high), engine))
        var expectedRoot = root
        var expectedChild = child
        expectedRoot.priority = .high
        expectedRoot.updatedAt = now + 1
        expectedChild.priority = .high
        expectedChild.updatedAt = now + 1
        XCTAssertEqual(changed.data.tasks, [expectedChild, expectedRoot, locked])
        XCTAssertNil(try edit([root.id, child.id], .priority(.high), changed))
        XCTAssertThrowsError(try edit([root.id, UUID()], .priority(.high), engine))
        XCTAssertThrowsError(try edit([root.id, root.id], .priority(.high), engine))
        XCTAssertThrowsError(try edit([root.id, locked.id], .priority(.high), engine))
        XCTAssertThrowsError(try edit([root.id, child.id], .move(archived.id), engine))
        XCTAssertThrowsError(try edit([root.id, child.id], .tags([UUID()], remove: false), engine))
        let tagged = try XCTUnwrap(edit([root.id, child.id], .tags([tag.id], remove: false), changed))
        XCTAssertEqual(tagged.data.tasks.map(\.tagIDs), [[tag.id], [unknownTag, tag.id], []])
        let untagged = try XCTUnwrap(edit([root.id, child.id], .tags([tag.id], remove: true), tagged))
        XCTAssertEqual(untagged.data.tasks.map(\.tagIDs), [[], [unknownTag], []])
        let moved = try XCTUnwrap(edit([root.id, locked.id], .move(target.id), untagged))
        XCTAssertEqual(moved.data.tasks.map(\.listID), [target.id, target.id, target.id])
        XCTAssertEqual(moved.data.tasks.first?.parentID, root.id)
        XCTAssertEqual(engine.data, workspace)
    }

    func testBatchScheduleUsesCalendarShapeAndRejectsWholeSelectionOnInvalidMember() throws {
        let due = date("2026-11-09T12:30:00Z")
        let reminder = due - 900
        let timed = TaskItem(title: "Timed", dueDate: due, hasDueTime: true, reminderDate: reminder,
                             recurrence: .daily, scheduledDuration: .init(start: due - 3_600, end: due))
        let undated = TaskItem(title: "Undated")
        let invalid = TaskItem(title: "Unknown zone", timeZoneID: "Not/AZone")
        let data = WorkspaceData(tasks: [timed, undated, invalid])
        let engine = TaskLifecycle(data: data), settings = AppSettings()
        let day = date("2026-11-12T00:00:00Z")
        let move = TaskBatchEdit(ids: [timed.id, undated.id], action: .schedule(day))
        let result = try XCTUnwrap(move.applying(to: engine, settings: settings, now: now, calendar: calendar))
        let relocated = result.data.tasks[0]
        XCTAssertEqual(relocated.dueDate, due + 3 * 86_400)
        XCTAssertEqual(relocated.scheduledDuration?.start, due + 3 * 86_400 - 3_600)
        XCTAssertEqual(relocated.reminderDates, [reminder + 3 * 86_400])
        XCTAssertEqual(relocated.recurrence, .daily)
        XCTAssertEqual(result.data.tasks[1].dueDate, day)
        XCTAssertFalse(result.data.tasks[1].hasDueTime)
        XCTAssertEqual(result.data.tasks[2], invalid)
        let unsafe = TaskBatchEdit(ids: [timed.id, invalid.id], action: .schedule(day))
        XCTAssertThrowsError(try unsafe.applying(to: engine, settings: settings, now: now, calendar: calendar)) {
            XCTAssertEqual($0 as? TaskBatchRefusal, .invalidSchedule)
        }
        let clear = TaskBatchEdit(ids: [timed.id, undated.id], action: .schedule(nil))
        let cleared = try XCTUnwrap(clear.applying(to: result, settings: settings, now: now, calendar: calendar))
        XCTAssertTrue(cleared.data.tasks.prefix(2).allSatisfy {
            $0.dueDate == nil && $0.scheduledDuration == nil && $0.reminderDates.isEmpty && !$0.isRepeating
        })
        XCTAssertEqual(engine.data, data)
    }

    func testBatchPostponePreservesTimedShapesRemindersAndFutureCadenceAcrossClockChange() throws {
        let zone = "America/New_York"
        let due = date("2026-11-01T05:30:15Z") + 0.25
        let start = due - 2_700
        let originalReminder = due - 600
        var range = TaskItem(title: "Repeating range", body: "Keep this body", dueDate: due, hasDueTime: true,
                             reminderDate: originalReminder, recurrence: .daily, timeZoneID: zone,
                             scheduledDuration: .init(start: start, end: due))
        range.reminderFollowsSchedule = false
        let pointDue = due + 300
        var point = TaskItem(title: "Point", dueDate: pointDue, hasDueTime: true)
        point.reminderFollowsSchedule = true
        let untouched = TaskItem(title: "All day", dueDate: due)
        let data = WorkspaceData(tasks: [point, range, untouched])
        let settings = AppSettings()
        let edit = TaskBatchEdit(ids: [range.id, point.id], action: .postpone)
        let lifecycle = TaskLifecycle(data: data)
        let changed = try XCTUnwrap(edit.applying(to: lifecycle, settings: settings, now: now, calendar: calendar))
        let postponedRange = changed.data.tasks[1]
        XCTAssertEqual(postponedRange.dueDate, due + 3_600)
        XCTAssertEqual(postponedRange.scheduledDuration, .init(start: start + 3_600, end: due + 3_600))
        XCTAssertEqual(postponedRange.reminderDates, [originalReminder + 3_600])
        XCTAssertEqual(postponedRange.reminderFollowsSchedule, false)
        XCTAssertEqual(postponedRange.originalOccurrenceSchedule?.due, due)
        XCTAssertEqual(postponedRange.recurrence, .daily)
        XCTAssertEqual(postponedRange.timeZoneID, zone)
        XCTAssertEqual(postponedRange.body, range.body)
        let local = TaskCalendarProjection.taskCalendar(range, fallback: calendar)
        let window = DateInterval(start: due + 12 * 3_600, duration: 24 * 3_600)
        var options = TaskCalendarOptions()
        options.showRepeatCycles = true
        let before = TaskCalendarProjection.project(data: data, range: window, options: options, calendar: local)
        let after = TaskCalendarProjection.project(data: changed.data, range: window, options: options, calendar: local)
        XCTAssertFalse(before.entries.isEmpty)
        XCTAssertEqual(after.entries, before.entries)
        XCTAssertEqual(changed.data.tasks[0].dueDate, pointDue + 3_600)
        XCTAssertNil(changed.data.tasks[0].scheduledDuration)
        XCTAssertEqual(changed.data.tasks[0].reminderDates, TaskSchedulePolicy.defaultReminderDates(
            due: pointDue + 3_600, hasTime: true, settings: settings, calendar: calendar))
        XCTAssertEqual(changed.data.tasks[0].reminderFollowsSchedule, true)
        XCTAssertEqual(changed.data.tasks[2], untouched)
        XCTAssertEqual(changed.data.tasks.count, data.tasks.count)
        let repeated = try XCTUnwrap(edit.applying(to: changed, settings: settings, now: now + 1, calendar: calendar))
        XCTAssertEqual(repeated.data.tasks[1].dueDate, due + 7_200)
        XCTAssertEqual(repeated.data.tasks[1].originalOccurrenceSchedule, postponedRange.originalOccurrenceSchedule)
    }

    func testBatchPostponeRejectsIneligibleMembersAndUsesSavedCalendarSources() throws {
        let work = TaskList(name: "Work", color: "#445566")
        let home = TaskList(name: "Home", color: "#556677")
        let archived = TaskList(name: "Archived", color: "#667788", isArchived: true)
        let timed = TaskItem(title: "Timed", listID: work.id, dueDate: now, hasDueTime: true)
        let excluded = TaskItem(title: "Excluded source", listID: home.id, dueDate: now, hasDueTime: true)
        let allDay = TaskItem(title: "All-day", listID: work.id, dueDate: now)
        let undated = TaskItem(title: "Undated", listID: work.id)
        let note = TaskItem(title: "Note", listID: work.id, kind: .note, dueDate: now, hasDueTime: true)
        let invalidRange = TaskItem(title: "Invalid range", listID: work.id, dueDate: now, hasDueTime: true,
                                    scheduledDuration: .init(start: now - 600, end: now + 600))
        let invalidZone = TaskItem(title: "Invalid zone", listID: work.id, dueDate: now, hasDueTime: true,
                                   timeZoneID: "Not/AZone")
        let locked = TaskItem(title: "Archived", listID: archived.id, dueDate: now, hasDueTime: true)
        let predecessor = TaskItem(title: "Reopened", listID: work.id, dueDate: now, hasDueTime: true, recurrence: .daily)
        var successor = TaskItem(title: "Successor", listID: home.id, dueDate: now + 86_400, hasDueTime: true, recurrence: .daily)
        successor.recurrenceSourceID = predecessor.id
        var history = timed
        history.id = UUID()
        history.completedAt = now
        var removed = timed
        removed.id = UUID()
        removed.deletedAt = now
        var wontDo = timed
        wontDo.id = UUID()
        wontDo.wontDoAt = now
        let incompatible = [allDay, undated, note, invalidRange, invalidZone, locked, predecessor, history, removed, wontDo]
        let data = WorkspaceData(tasks: [timed, excluded, successor] + incompatible, lists: [work, home, archived])
        let lifecycle = TaskLifecycle(data: data)
        for task in incompatible {
            XCTAssertFalse(TaskBatchEdit.Kind.postpone.isAvailable(for: [timed, task], in: data), task.title)
            let edit = TaskBatchEdit(ids: [timed.id, task.id], action: .postpone)
            XCTAssertThrowsError(try edit.applying(to: lifecycle, settings: AppSettings(), now: now, calendar: calendar), task.title)
        }
        var options = TaskCalendarOptions()
        options.selectOnlyList(work.id)
        XCTAssertEqual(TaskBatchEdit.calendarPostponeCandidates(in: data, options: options).map(\.id), [timed.id])
        XCTAssertEqual(lifecycle.data, data)
    }

    func testBatchLifecycleOrdersParentBeforeSelectedChildAndDoesNotSpawnTwice() throws {
        let parent = TaskItem(title: "Parent", dueDate: now, recurrence: .daily)
        var child = TaskItem(title: "Child", dueDate: now, recurrence: .daily)
        child.parentID = parent.id
        let other = TaskItem(title: "Other")
        let engine = TaskLifecycle(data: WorkspaceData(tasks: [child, other, parent]))
        let selected = [child.id, parent.id]
        let complete = TaskBatchEdit(ids: selected, action: .complete)
        let finished = try XCTUnwrap(complete.applying(to: engine, settings: AppSettings(), now: now, calendar: calendar))
        XCTAssertEqual(finished.data.tasks.count, 5)
        XCTAssertEqual(finished.data.tasks.filter { $0.completedAt == now }.map(\.id), [child.id, parent.id])
        XCTAssertEqual(finished.data.tasks.filter { $0.recurrenceSourceID == child.id }.count, 1)
        XCTAssertNil(try complete.applying(to: finished, settings: AppSettings(), now: now, calendar: calendar))
        let trash = TaskBatchEdit(ids: selected, action: .trash)
        var removed = try XCTUnwrap(trash.applying(to: engine, settings: AppSettings(), now: now, calendar: calendar))
        XCTAssertEqual(removed.data.trashCascades.count, 1)
        XCTAssertEqual(removed.data.trashCascades.first?.parentID, parent.id)
        XCTAssertTrue(removed.restoreTask(id: parent.id, now: now + 1))
        XCTAssertTrue(removed.data.tasks.allSatisfy { $0.deletedAt == nil })
        XCTAssertEqual(removed.data.tasks[1], other)
    }
}

extension MobileContractTests {
    func testCalendarCardDetailsFollowDisplayZoneWithoutChangingProjection() throws {
        var display = calendar
        display.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Moscow"))
        let work = TaskList(name: "Work", color: "#445566")
        let start = date("2026-11-09T20:00:00Z"), end = date("2026-11-09T21:30:00Z")
        let timed = TaskItem(title: "Late workshop", listID: work.id, dueDate: end, hasDueTime: true,
                             timeZoneID: "America/New_York", scheduledDuration: .init(start: start, end: end))
        let point = TaskItem(title: "Point", dueDate: date("2026-11-09T08:00:00Z"), hasDueTime: true)
        let allDay = TaskItem(title: "All-day note", kind: .note, dueDate: now)
        let data = WorkspaceData(tasks: [timed, point, allDay], lists: [work])
        let range = DateInterval(start: now - 86_400, duration: 3 * 86_400)
        let baseline = TaskCalendarProjection.project(data: data, range: range, options: .init(), calendar: display)
        var options = TaskCalendarOptions()
        options.showDetails = true
        let projected = TaskCalendarProjection.project(data: data, range: range, options: options, calendar: display)
        XCTAssertEqual(projected.entries, baseline.entries)
        let locale = Locale(identifier: "en_GB")
        let names = [work.id: work.name]
        func details(_ id: UUID) throws -> CalendarEntryDetails {
            let entry = try XCTUnwrap(projected.entries.first { $0.taskID == id })
            return .init(entry: entry, listNames: names, calendar: display, locale: locale)
        }
        let workshop = try details(timed.id)
        XCTAssertEqual(workshop.compact, "23:00")
        XCTAssertTrue(workshop.text.contains("23:00") && workshop.text.contains("0:30") && workshop.text.hasSuffix(" · Work"))
        XCTAssertTrue(workshop.text.contains("9 Nov") && workshop.text.contains("10 Nov"))
        XCTAssertEqual(try details(point.id).text, "11:00 · Inbox")
        XCTAssertEqual(try details(allDay.id).text, "All day · Inbox")
        var missing = try XCTUnwrap(projected.entries.first { $0.taskID == allDay.id })
        missing.listID = UUID()
        XCTAssertEqual(CalendarEntryDetails(entry: missing, listNames: names, calendar: display).text, "All day · List unavailable")
    }
}
