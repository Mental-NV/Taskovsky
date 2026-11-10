#!/usr/bin/env python3
"""Read-only audit of neutral XCTest QA folders, never a normal workspace."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import re
from pathlib import Path
import subprocess
import uuid

CAPTURE_TITLES = {
    "testCaptureCalendarContextAndDurableTask": "Local calendar capture",
    "testCaptureRecoveryDoesNotAutosubmitAndSavesOnce": "Recovered capture",
    "testCaptureConfirmsAfterWriteThrow": "Confirmed local capture",
    "testCaptureStyledTemplateProtectsBodyAndInstantiates": "Template project",
    "testCaptureNoteWithListPriorityAndExistingTag": "Local capture note",
    "testCaptureRecognitionShowsRemovableCandidates": "Local capture tomorrow #Planning #Unlisted",
    "testCaptureCreatesFirstTaskInEmptyWorkspace": "First local task",
}
CAPTURE_NO_CREATE = {"testCaptureDirtyCancelDoesNotCreate", "testCaptureWriteFailureKeepsEditableDraft",
                     "testCaptureStaleWorkspaceRetainsDraftWithoutCreating"}
EMPTY = "testCaptureCreatesFirstTaskInEmptyWorkspace"
TEMPLATE = "testCaptureStyledTemplateProtectsBodyAndInstantiates"
NOTE = "testCaptureNoteWithListPriorityAndExistingTag"
STALE = "testCaptureStaleWorkspaceRetainsDraftWithoutCreating"

LIFECYCLE_COMPLETE = "testLifecycleCompletesRecurringTreeAndUndoFromRow"
LIFECYCLE_RESTORE = "testLifecycleTrashUndoAndRestoreAfterRelaunch"
LIFECYCLE_PURGE = "testLifecyclePurgeConfirmsOnlyTheNamedRecord"
LIFECYCLE_PIN = "testLifecyclePinWontDoAndReopenRetainThePin"
LIFECYCLE_MOVE = "testLifecycleArchivedTaskCanMoveOut"
LIFECYCLE_FAILURE = "testLifecycleWriteFailureDoesNotClaimCompletion"
LIFECYCLE = {LIFECYCLE_COMPLETE, LIFECYCLE_RESTORE, LIFECYCLE_PURGE, LIFECYCLE_PIN,
             LIFECYCLE_MOVE, LIFECYCLE_FAILURE}


SCHEDULE_DATE = "testScheduleCalendarDateEditSurvivesRelaunch"
SCHEDULE_CLEAR = "testScheduleCreatesCustomRepeatAndStagesRemoval"
SCHEDULE_ZONE = "testScheduleZoneAndManualReminderPreserveTimedWindow"
SCHEDULE_CHANGED = {SCHEDULE_DATE, SCHEDULE_CLEAR, SCHEDULE_ZONE}
SCHEDULE = SCHEDULE_CHANGED | {
    "testScheduleNestedAndOuterCancelLeaveAnUntouchedTask",
    "testScheduleWriteFailureKeepsStagedDate",
}


ARRANGE_FOCUSED = "testCalendarArrangeScopesAndSchedulesTheFocusedDay"
ARRANGE_UNDO = "testCalendarCardStagedRemovalAndScopedUndo"
ARRANGE_HOUR = "testCalendarHourDragCreatesASnappedTimedRange"
ARRANGE_DRAG = "testCalendarMonthDragMovesAnAllDayTask"
ARRANGE_RESIZE = "testCalendarTimedResizeHandleMovesTheEnd"
ARRANGE = {ARRANGE_FOCUSED, ARRANGE_UNDO, ARRANGE_HOUR, ARRANGE_DRAG, ARRANGE_RESIZE}


PREFS_STYLE = "testCalendarViewOptionsRenderAndPersistAcrossRelaunch"
PREFS_RULERS = "testCalendarRulersStageNamedZonesAndKeepFourRulerLimit"
PREFS_FAILURE = "testCalendarPreferenceSaveFailureRetainsDraft"
PREFERENCES = {PREFS_STYLE, PREFS_RULERS, PREFS_FAILURE}
PREFERENCES_FIXTURE = {PREFS_STYLE, PREFS_RULERS}
MODE_WRITES = {
    "testCalendarViews": "month",
    "testCaptureCalendarContextAndDurableTask": "day",
    ARRANGE_FOCUSED: "day",
    ARRANGE_HOUR: "day",
    ARRANGE_DRAG: "month",
    ARRANGE_RESIZE: "day",
    PREFS_STYLE: "year",
}


RICH_PREVIEW = "testRichDescriptionRendersExactTextAndSurvivesTitleEdit"
MALFORMED_RICH = "testMalformedRichDescriptionShowsItsSavedPlainBody"
RICH_CASES = {RICH_PREVIEW, MALFORMED_RICH}


METADATA_PRIORITY = "testTaskPriorityAndTagsPersistWithoutChangingDescription"
METADATA_CHECKLIST = "testEmbeddedChecklistEditsAndCalendarReflectSavedItems"
METADATA_CANCEL = "testChecklistDiscardLeavesSavedItemsIntact"
METADATA_FAILURE = "testChecklistWriteFailureKeepsDraft"
METADATA = {METADATA_PRIORITY, METADATA_CHECKLIST, METADATA_CANCEL, METADATA_FAILURE}
METADATA_CHANGED = {METADATA_PRIORITY, METADATA_CHECKLIST}
METADATA_FIXTURE = {METADATA_PRIORITY, METADATA_CHECKLIST, METADATA_CANCEL}
CHECKLIST_FIRST = "00000000-0000-0000-0000-000000000501"
CHECKLIST_SECOND = "00000000-0000-0000-0000-000000000502"
UNAVAILABLE_TAG = "00000000-0000-0000-0000-000000000599"
HIERARCHY_CREATE = "testLinkedSubtaskCreationAndIndependentCompletionPersist"
HIERARCHY_MOVE = "testLinkedSubtaskCrossListMoveExcludesDescendantsAndSurvivesRelaunch"
HIERARCHY_DETACH = "testLinkedSubtaskCanDiscardAndDetachWithoutChangingChecklist"
HIERARCHY = {HIERARCHY_CREATE, HIERARCHY_MOVE, HIERARCHY_DETACH}
ORGANIZATION_FOLDER = "testListAndFolderManagementPersistsPlacementAndUngroups"
ORGANIZATION_ARCHIVE = "testListArchiveAndSmartExclusionKeepDirectAccess"
ORGANIZATION_COPY = "testListDuplicateAndDeletePreserveTasksAndUnavailableFilter"
ORGANIZATION_FAILURE = "testListOrganizationWriteFailureKeepsDraft"
ORGANIZATION = {ORGANIZATION_FOLDER, ORGANIZATION_ARCHIVE, ORGANIZATION_COPY, ORGANIZATION_FAILURE}
SMART_LIST_CHANGE = "testSmartListVisibilityAndOrderSurviveRelaunch"
SMART_LISTS = {SMART_LIST_CHANGE, "testSmartListFailedSaveKeepsDraftAndDrawer"}
SAVED_FILTER_NORMAL = "testSavedNormalFilterCreatesMatchesAndDeletesWithoutLosingTasks"
SAVED_FILTER_ADVANCED = "testSavedAdvancedFilterBuildsNestedRuleAndReloads"
SAVED_FILTER_RENAME = "testSavedAdvancedRenameKeepsUnavailableRuleAndCancelsModeSwitch"
SAVED_FILTER_FAILURE = "testSavedFilterFailedWriteKeepsDraft"
SAVED_FILTERS = {SAVED_FILTER_NORMAL, SAVED_FILTER_ADVANCED, SAVED_FILTER_RENAME, SAVED_FILTER_FAILURE}
SEARCH_ARCHIVE = "testSearchExplicitArchiveCriteriaAndSavedFilterRoundTrip"
SEARCH_HISTORY = "testSearchBodyMatchAndCaseInsensitiveHistorySurviveRelaunch"
SEARCH_ROUTES = "testSearchChecklistAndOrganizationRoutes"
SEARCH_CASES = {SEARCH_ARCHIVE, SEARCH_HISTORY, SEARCH_ROUTES}
TEMPLATE_MANAGEMENT = "testTemplateManagerCreatesRenamesAndDeletesPlainTemplate"
TEMPLATE_APPLICATION = "testStyledTaskCanBeSavedAndAppliedAsTemplate"
TEMPLATE_CASES = {TEMPLATE_MANAGEMENT, TEMPLATE_APPLICATION}
LOCAL_SETTINGS = "testLocalSettingsCancelAndSaveAffectNewCaptureAfterRelaunch"
RICH_BODY_EDIT = "testRichDescriptionDraftRecoversAndCommitsTextWithFormatting"
RICH_INLINE_EDIT = "testRichDescriptionFormatsNativeSelectionAndAddsLink"
RICH_PLAIN_PASTE = "testRichDescriptionPlainPasteClearsFormattingFromIdenticalText"
RICH_EDITOR_CASES = {RICH_BODY_EDIT, RICH_INLINE_EDIT, RICH_PLAIN_PASTE}
SAVED_FILTER_MUTATIONS = (SAVED_FILTERS - {SAVED_FILTER_FAILURE}) | {SEARCH_ARCHIVE}
TAG_CREATE = "testTagManagerCreatesPinsAndAssignsNestedTag"
TAG_MERGE = "testTagManagerMergesIntoDescendantAndReopensMatchingFilter"
TAG_DELETE = "testTagManagerDeleteKeepsUnavailableFilterAndTasks"
TAG_REORDER = "testTagManagerReordersAndEditsWithoutSavingCanceledName"
TAG_ORGANIZATION = {TAG_CREATE, TAG_MERGE, TAG_DELETE, TAG_REORDER}
TAG_PAIR_CASES = {TAG_MERGE, TAG_DELETE}
TAG_FIXTURE_CASES = TAG_PAIR_CASES | {TAG_REORDER}
BOARD_MODE = "testBoardModeIsPerListAndSurvivesRelaunch"
BOARD_UNDO = "testBoardCompletesRecurringCardFromWontDoAndUndo"
BOARD_ARCHIVE = "testBoardArchiveDisplaysCompletedOnlyAndDisablesChanges"
BOARD_DROP = "testBoardDragMovesCardAndRefusesNote"
BOARD_CASES = {BOARD_MODE, BOARD_UNDO, BOARD_ARCHIVE, BOARD_DROP}
BOARD_ARCHIVE_ID = "00000000-0000-0000-0000-000000000105"
SUMMARY_NOTE = "testSummaryFiltersAndSavesEditedInboxNote"
SUMMARY_FAILURE = "testSummaryFailedNoteSaveRecoversWithoutSubmitting"
SUMMARY_CASES = {SUMMARY_NOTE, SUMMARY_FAILURE}
TAG_PARENT = "00000000-0000-0000-0000-000000000200"
TAG_TARGET = "00000000-0000-0000-0000-000000000201"
TAG_SIBLING = "00000000-0000-0000-0000-000000000202"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def check_capture(name, before, after):
    original, actual = json.loads(before), json.loads(after)
    require(len(actual["tasks"]) == len(original["tasks"]) + 1, name + ": expected one new task")
    created = actual["tasks"].pop(0)
    require(actual == original, name + ": an existing record changed")
    require(created["title"] == CAPTURE_TITLES[name], name + ": created title differs")
    require(created["id"] not in {t["id"] for t in original["tasks"]}, name + ": task identity was reused")
    require(created.get("deletedAt") is None and created.get("completedAt") is None and created.get("wontDoAt") is None,
            name + ": new task is not open")
    day = (datetime(2026, 11, 8, 21, tzinfo=timezone.utc) - datetime(2001, 1, 1, tzinfo=timezone.utc)).total_seconds()
    if name == NOTE:
        require(created["kind"] == "note" and created["priority"] == "high" and created["body"] == "Local note description",
                name + ": note content or priority differs")
        require(created.get("listID") == "00000000-0000-0000-0000-000000000101" and
                created["tagIDs"] == ["00000000-0000-0000-0000-000000000200"], name + ": selected list/tag differs")
        require(created.get("dueDate") is None and not created["hasDueTime"], name + ": No date was not preserved")
    elif name == TEMPLATE:
        seed = original["templates"][0]
        require(all(created[k] == seed[k] for k in ("body", "richBody", "customRecurrence", "priority", "kind", "tagIDs")),
                name + ": template payload changed")
        require(len(created["checklist"]) == len(seed["checklist"]) == 1, name + ": template checklist missing")
        one, two = created["checklist"][0], seed["checklist"][0]
        require(one["id"] != two["id"] and one["title"] == two["title"] and one["isCompleted"] == two["isCompleted"],
                name + ": template checklist content/identity differs")
        old, new = seed["scheduledDuration"], created["scheduledDuration"]
        require(new["end"] == created["dueDate"] == day and new["end"] - new["start"] == old["end"] - old["start"] and
                new["isAllDay"] == old["isAllDay"] and created["hasDueTime"], name + ": template window not end-anchored")
    else:
        require(created["kind"] == "task" and created["dueDate"] == day and not created["hasDueTime"],
                name + ": contextual all-day schedule differs")
        require(created["tagIDs"] == [] and created.get("listID") is None, name + ": unexpected list or recognized tag")


def lifecycle_fixture(baseline):
    fixture = copy.deepcopy(baseline)
    tasks = fixture["tasks"]
    root_id = tasks[0]["id"]
    tasks[0]["recurrence"] = "daily"
    tasks[1]["parentID"] = root_id
    tasks[1].pop("listID")
    tasks[3].update(parentID=root_id, completedAt=815900400)
    tasks[4].update(parentID=root_id, deletedAt=815904000)
    tasks[4].pop("listID")
    tasks[6]["kind"] = "note"
    fixture["lists"][1]["isArchived"] = True
    return fixture


def check_lifecycle(name, baseline, before, after):
    original, actual = json.loads(before), json.loads(after)
    fixture = lifecycle_fixture(baseline)
    require(original == fixture, name + ": unexpected lifecycle fixture")
    root_id, child_id, archive_id, finished_id, separate_id = (task["id"] for task in original["tasks"][:5])
    prior = {t["id"]: t for t in original["tasks"]}
    records = {t["id"]: t for t in actual["tasks"]}
    require(len(records) == len(actual["tasks"]), name + ": duplicate task identities")

    def check_owned(id, *fields):
        old, new = copy.deepcopy(prior[id]), copy.deepcopy(records[id])
        require(new["updatedAt"] > old["updatedAt"], name + ": modification time did not advance")
        for field in (*fields, "updatedAt"):
            old.pop(field, None)
            new.pop(field, None)
        require(new == old, name + ": unowned record fields changed")

    if name == LIFECYCLE_COMPLETE:
        changed = {root_id, child_id}
        for id in changed:
            check_owned(id, "completedAt")
        stamp = records[root_id]["completedAt"]
        require(records[child_id]["completedAt"] == stamp, name + ": child completion stamp differs")
        require(actual["completionCascades"] == [{"parentID": root_id, "completedAt": stamp,
                 "children": [{"id": child_id, "completedAt": stamp}]}], name + ": completion ledger differs")
        successors = {t["recurrenceSourceID"]: t for t in actual["tasks"] if t["id"] not in prior}
        require(len(records) == 10 and set(successors) == changed, name + ": expected exactly one successor tree")
        parent, child = successors[root_id], successors[child_id]
        require(child["parentID"] == parent["id"] and parent.get("parentID") is None, name + ": successor parent link differs")
        for source, successor in successors.items():
            require(all(successor.get(key) == prior[source].get(key) for key in ("title", "body", "richBody", "listID", "tagIDs")),
                    name + ": successor content differs")
            require(successor.get("completedAt") is None and successor.get("deletedAt") is None,
                    name + ": successor is not open")
            require(successor["dueDate"] > prior[source]["dueDate"], name + ": successor date did not advance")
        require(child["scheduledDuration"]["end"] == child["dueDate"], name + ": successor window endpoint differs")
    elif name == LIFECYCLE_PURGE:
        changed = {child_id, finished_id, separate_id}
        require(len(records) == 7 and root_id not in records, name + ": purge removed more than the selected record")
        for id in changed:
            check_owned(id, "parentID", "deletedAt")
            require(records[id].get("parentID") is None and records[id].get("deletedAt") is not None,
                    name + ": surviving child was not detached in Trash")
        require(records[separate_id]["deletedAt"] == prior[separate_id]["deletedAt"],
                name + ": separate Trash stamp changed")
    elif name == LIFECYCLE_RESTORE:
        changed = {root_id, child_id, finished_id}
        for id in changed:
            check_owned(id)
    elif name == LIFECYCLE_PIN:
        changed = {root_id}
        check_owned(root_id, "isPinned")
        require(records[root_id]["isPinned"], name + ": reopened task lost its pin")
    else:
        require(name == LIFECYCLE_MOVE, "Unknown lifecycle case")
        changed = {archive_id}
        check_owned(archive_id, "listID")
        require(records[archive_id]["listID"] == fixture["lists"][0]["id"], name + ": move destination differs")

    removed = {root_id} if name == LIFECYCLE_PURGE else set()
    require(all(records.get(id) == task for id, task in prior.items() if id not in changed | removed),
            name + ": an unrelated task changed")
    if name != LIFECYCLE_COMPLETE:
        require(set(records) == set(prior) - removed and actual["completionCascades"] == original["completionCascades"],
                name + ": unrelated task or completion ledger changed")
    require({k: v for k, v in actual.items() if k not in ("tasks", "completionCascades")} ==
            {k: v for k, v in original.items() if k not in ("tasks", "completionCascades")},
            name + ": Trash ledger or unrelated workspace data changed")


def check_schedule(name, before, after):
    original, actual = json.loads(before), json.loads(after)
    index = 1 if name == SCHEDULE_ZONE else 0
    prior, changed = original["tasks"][index], actual["tasks"][index]
    require(changed["updatedAt"] > prior["updatedAt"], name + ": modification time did not advance")
    expected = copy.deepcopy(prior)
    expected["updatedAt"] = changed["updatedAt"]
    if name == SCHEDULE_DATE:
        expected.update(dueDate=815_950_800, reminderFollowsSchedule=True)
    elif name == SCHEDULE_CLEAR:
        expected.pop("dueDate")
    elif name == SCHEDULE_ZONE:
        shift = 8 * 3600
        window = expected["scheduledDuration"]
        window["start"] += shift
        window["end"] += shift
        expected.update(dueDate=window["end"], timeZoneID="America/New_York",
                        reminderDate=window["end"], reminderFollowsSchedule=False)
    else:
        raise ValueError("Unknown schedule case")
    require(changed == expected, name + ": persisted task fields differ from the schedule intent")
    actual["tasks"][index] = prior
    require(actual == original, name + ": an unrelated record changed")


def check_arrange(name, before, after):
    original, actual = json.loads(before), json.loads(after)
    index = {ARRANGE_FOCUSED: 2, ARRANGE_UNDO: 0, ARRANGE_HOUR: 0, ARRANGE_DRAG: 0, ARRANGE_RESIZE: 1}[name]
    prior, changed = original["tasks"][index], actual["tasks"][index]
    require(changed["updatedAt"] > prior["updatedAt"], name + ": modification time did not advance")
    expected = copy.deepcopy(prior)
    expected["updatedAt"] = changed["updatedAt"]
    if name == ARRANGE_FOCUSED:
        start = 815_950_800 + 9 * 3600
        end = start + 1800
        expected.update(dueDate=end, hasDueTime=True, reminderDate=end, reminderFollowsSchedule=True,
                        scheduledDuration={"start": start, "end": end, "isAllDay": False})
    elif name == ARRANGE_HOUR:
        start = 815_864_400 + 2 * 3600
        end = start + 1800
        expected.update(dueDate=end, hasDueTime=True, reminderDate=end, reminderFollowsSchedule=True,
                        scheduledDuration={"start": start, "end": end, "isAllDay": False})
    elif name == ARRANGE_DRAG:
        expected.update(dueDate=815_950_800, reminderFollowsSchedule=True)
    elif name == ARRANGE_RESIZE:
        end = expected["scheduledDuration"]["end"] + 1800
        expected["scheduledDuration"]["end"] = end
        expected.update(dueDate=end, reminderDate=end, reminderFollowsSchedule=True)
    require(changed == expected, name + ": persisted Calendar fields differ from the command")
    actual["tasks"][index] = prior
    require(actual == original, name + ": unrelated task or workspace data changed")


def calendar_settings_parts(raw):
    text = raw.decode("utf-8")
    matches = list(re.finditer(r'"calendarOptions"\s*:\s*', text))
    require(len(matches) == 1, "Expected one Calendar options object in the neutral fixture")
    start = matches[0].end()
    options, end = json.JSONDecoder().raw_decode(text, start)
    require(isinstance(options, dict) and options == json.loads(text)["calendarOptions"], "Expected Calendar options")
    return options, text[:start], text[end:]


def check_calendar_preferences(name, before, after):
    if name not in MODE_WRITES and name not in {PREFS_RULERS, "testCalendarFilterReset", METADATA_CHECKLIST}:
        require(before == after, name + ": settings were rewritten")
        return
    expected, before_prefix, before_suffix = calendar_settings_parts(before)
    actual, after_prefix, after_suffix = calendar_settings_parts(after)
    require((before_prefix, before_suffix) == (after_prefix, after_suffix), name + ": unrelated setting bytes changed")
    if name in MODE_WRITES:
        expected["mode"] = MODE_WRITES[name]
    if name == PREFS_STYLE:
        expected.update(colorBy="priority", itemStyle="outline", yearStyle="standard",
                        showItemIcons=False, showCompleted=False, showChecklistItems=True, showRepeatCycles=False)
    elif name == PREFS_RULERS:
        expected["showAdditionalTimeZones"] = True
        expected["additionalTimeZoneID"] = expected["additionalTimeZones"][0]["identifier"]
        expected["additionalTimeZones"] += [
            {"identifier": "Europe/London", "label": "UK"},
            {"identifier": "Europe/Paris", "label": ""},
        ]
    elif name == METADATA_CHECKLIST:
        expected["showChecklistItems"] = True
    require(actual == expected, name + ": saved Calendar options differ")


def metadata_fixture(baseline):
    fixture = copy.deepcopy(baseline)
    task = fixture["tasks"][0]
    task["tagIDs"] = [UNAVAILABLE_TAG]
    task["checklist"] = [
        {"id": CHECKLIST_FIRST, "title": "First step", "isCompleted": False},
        {"id": CHECKLIST_SECOND, "title": "Second step", "isCompleted": False},
    ]
    fixture["tasks"][3]["parentID"] = task["id"]
    return fixture


def check_metadata(name, before, after):
    original, actual = json.loads(before), json.loads(after)
    old, changed = original["tasks"][0], actual["tasks"][0]
    expected = copy.deepcopy(old)
    require(changed["updatedAt"] > old["updatedAt"], name + ": modification time did not advance")
    expected["updatedAt"] = changed["updatedAt"]
    if name == METADATA_PRIORITY:
        expected.update(priority="high", tagIDs=[UNAVAILABLE_TAG, "00000000-0000-0000-0000-000000000200"])
    else:
        items = changed["checklist"]
        require(len(items) == 2, name + ": unexpected checklist count")
        new = next((item for item in items if item["title"] == "Bring a note"), None)
        require(new is not None and str(uuid.UUID(new["id"])).upper() == new["id"] and
                new["id"] not in {CHECKLIST_FIRST, CHECKLIST_SECOND}, name + ": missing stable new checklist identity")
        expected["checklist"] = [
            {"id": CHECKLIST_FIRST, "title": "First step reviewed", "isCompleted": True},
            {"id": new["id"], "title": "Bring a note", "isCompleted": False},
        ]
    require(changed == expected, name + ": task metadata or a preserved field differs")
    actual["tasks"][0] = old
    require(actual == original, name + ": unrelated workspace content changed")


def check_hierarchy(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    root, target, _, child = expected["tasks"][:4]
    if name == HIERARCHY_CREATE:
        new = actual["tasks"].pop(0)
        require(new["title"] == "Gather a folder" and new["parentID"] == root["id"] and
                new["id"] not in {task["id"] for task in expected["tasks"]}, name + ": missing independent child")
        require(new["completedAt"] >= new["createdAt"] and new["updatedAt"] == new["completedAt"] and
                not new.get("listID") and not new.get("dueDate") and not new.get("richBody") and
                new["checklist"] == [] and new["tagIDs"] == [], name + ": child inherited unrelated fields")
    elif name == HIERARCHY_MOVE:
        root.update(parentID=target["id"], listID=target["listID"])
        moved_child = next(task for task in actual["tasks"] if task["id"] == child["id"])
        require(moved_child["updatedAt"] > child["updatedAt"], name + ": descendant timestamp did not advance")
        child.update(listID=target["listID"], updatedAt=moved_child["updatedAt"])
    else:
        del child["parentID"]
    require(actual == expected, name + ": hierarchy change modified an unowned field")


def organization_fixture(baseline):
    fixture = copy.deepcopy(baseline)
    work = fixture["lists"][0]["id"]
    root = fixture["tasks"][0]
    root["listID"] = work
    root["checklist"] = [{"id": CHECKLIST_FIRST, "title": "Review the first step", "isCompleted": True}]
    fixture["tasks"][1]["parentID"] = root["id"]
    fixture["tasks"][7]["deletedAt"] = 815904000
    fixture["filters"][0].update(name="Original Work only", listIDs=[work], tagIDs=[])
    return fixture


def check_organization(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    work = expected["lists"][0]
    if name == ORGANIZATION_ARCHIVE:
        work["showsInSmartLists"] = False
    elif name == ORGANIZATION_FOLDER:
        require(len(actual["folders"]) == 1 and actual["folders"][0]["name"] == "Studio folder" and
                not actual["folders"][0]["isPinned"], name + ": ungroup or folder creation differs")
        expected["folders"] = actual["folders"]
        studio = next(item for item in actual["lists"] if item["name"] == "Studio list")
        expected["lists"].remove(work)
        work["name"] = "Work renamed"
        expected["lists"] += [
            {"id": studio["id"], "name": "Studio list", "kind": "task", "color": "#4E64D8", "viewMode": "list",
             "belowFolders": False, "isArchived": False, "isPinned": False, "showsInSmartLists": True},
            work,
        ]
    else:
        expected["lists"].remove(work)
        duplicate = actual["lists"][-1]
        require(duplicate["id"] != work["id"], name + ": reused list identity")
        expected["lists"].append(dict(work, id=duplicate["id"], name="Work copy", isArchived=False, isPinned=False))
        copied_from = [copy.deepcopy(task) for task in expected["tasks"]
                       if task.get("listID") == work["id"] and not task.get("deletedAt")]
        copies = actual["tasks"][len(expected["tasks"]):]
        require(len(copies) == len(copied_from), name + ": copied the wrong task set")
        id_map = {old["id"]: new["id"] for old, new in zip(copied_from, copies)}
        require(len(set(id_map.values())) == len(copies) and
                not (set(id_map.values()) & {task["id"] for task in expected["tasks"]}), name + ": reused a task identity")
        for old, new in zip(copied_from, copies):
            old.update(id=new["id"], listID=duplicate["id"], createdAt=new["createdAt"], updatedAt=new["createdAt"])
            parent = id_map.get(old.pop("parentID", None))
            if parent:
                old["parentID"] = parent
            old.pop("recurrenceSourceID", None)
            for item, copied in zip(old["checklist"], new["checklist"]):
                require(item["id"] != copied["id"], name + ": reused a checklist identity")
                item["id"] = copied["id"]
        for old, new in zip(expected["tasks"], actual["tasks"]):
            if old.get("listID") == work["id"]:
                del old["listID"]
                old["updatedAt"] = new["updatedAt"]
        expected["tasks"] += copied_from
    require(actual == expected, name + ": organization change modified an unowned field")


def check_smart_lists(before, after):
    def member(text, pattern):
        matches = list(re.finditer(pattern, text))
        require(len(matches) == 1, "Expected one Smart List settings member")
        match = matches[0]
        value, end = json.JSONDecoder().raw_decode(text, match.end())
        return value, match.start(), end

    old, saved = before.decode("utf-8"), after.decode("utf-8")
    require("smartListOrder" not in json.loads(old), "Unexpected saved smart order in baseline")
    order, start, end = member(saved, r',"smartListOrder":')
    require(order == ["all", "today", "tomorrow", "inbox", "week", "summary", "tags", "filters",
                      "completed", "wontDo", "trash"], "Saved smart order differs")
    without_order = saved[:start] + saved[end:]
    old_values, old_start, old_end = member(old, r'"smartListVisibility"\s*:\s*')
    new_values, new_start, new_end = member(without_order, r'"smartListVisibility"\s*:\s*')
    require(old[:old_start] == without_order[:new_start] and old[old_end:] == without_order[new_end:],
            "Unrelated settings bytes changed")
    expected = dict(zip(old_values[::2], old_values[1::2]))
    expected.update(all="show", today="hidden", tomorrow="showIfNotEmpty", tags="hidden", filters="showIfNotEmpty")
    require(dict(zip(new_values[::2], new_values[1::2])) == expected, "Saved Smart List visibility differs")


def rule_condition(kind, **values):
    return {"type": "condition", "condition": dict(values, kind=kind)}


def saved_filter_fixture(baseline):
    fixture = copy.deepcopy(baseline)
    missing_list = "00000000-0000-0000-0000-000000000598"
    fixture["filters"][0].update(name="Unavailable work", listIDs=[missing_list], tagIDs=[UNAVAILABLE_TAG], ruleRoot={
        "type": "and", "children": [rule_condition("list", listID=missing_list),
                                    {"type": "not", "child": rule_condition("tag", tagID=UNAVAILABLE_TAG)}],
    })
    return fixture


def check_saved_filter(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    if name == SAVED_FILTER_ADVANCED:
        added = actual["filters"][-1]
        require(str(uuid.UUID(added["id"])).upper() == added["id"] and
                added["id"] not in {item["id"] for item in expected["filters"]}, name + ": reused filter identity")
        expected["filters"].append({
            "id": added["id"], "name": "Work words", "dateRule": "all", "dateRules": [],
            "keyword": "", "kinds": [], "isPinned": False, "listIDs": [], "priorities": [],
            "priority": None, "status": "active", "tagIDs": [], "tagMode": "any",
            "ruleRoot": {"type": "and", "children": [
                rule_condition("status", status="active"),
                {"type": "or", "children": [rule_condition("keyword", keyword="weekly"),
                                           rule_condition("keyword", keyword="meeting")]},
            ]},
        })
    elif name == SAVED_FILTER_RENAME:
        expected["filters"][0]["name"] = "Retained rule"
    elif name == SEARCH_ARCHIVE:
        added = actual["filters"][-1]
        require(str(uuid.UUID(added["id"])).upper() == added["id"] and
                added["id"] not in {item["id"] for item in expected["filters"]}, name + ": reused filter identity")
        expected["filters"].append({
            "id": added["id"], "name": "Archived chapter", "dateRule": "all", "dateRules": [],
            "keyword": "chapter", "kinds": [], "isPinned": False, "listIDs": [expected["lists"][1]["id"]],
            "priorities": [], "priority": None, "status": "all", "tagIDs": [], "tagMode": "any",
        })
    require(actual == expected, name + ": unexpected change to saved filter rules or other workspace content")


def check_tag_fixture(name, before, baseline):
    actual, expected = json.loads(before), copy.deepcopy(baseline)
    if name not in TAG_FIXTURE_CASES:
        require(actual == expected, name + ": unexpected tag baseline")
        return
    expected["tags"] += [
        dict(id=TAG_TARGET, name="Sprint", color="#4E64D8", parentID=TAG_PARENT, isCollapsed=False, isPinned=False),
        dict(id=TAG_SIBLING, name="Review group", color="#4E64D8", parentID=TAG_PARENT, isCollapsed=False, isPinned=False),
    ]
    expected["tasks"][0]["tagIDs"] = [TAG_PARENT, TAG_TARGET]
    expected["filters"][0].update(name="Tagged review", tagIDs=[TAG_PARENT, TAG_TARGET], ruleRoot={
        "type": "and", "children": [rule_condition("tag", tagID=TAG_PARENT), rule_condition("tag", tagID=TAG_TARGET)]})
    require(len(actual["templates"]) == 1, name + ": missing tag fixture template")
    expected["templates"] = [dict(id=actual["templates"][0]["id"], name="Tagged example", title="Review notes",
                                  body="", checklist=[], priority="none", tagIDs=[TAG_PARENT, TAG_TARGET], kind="task")]
    require(actual == expected, name + ": unexpected tag fixture")


def check_tag_settings(name, before, after):
    def member(raw):
        text = raw.decode("utf-8")
        matches = list(re.finditer(r'"defaultTagID"\s*:\s*', text))
        require(len(matches) == 1, name + ": expected one default tag value")
        start = matches[0].end()
        value, end = json.JSONDecoder().raw_decode(text, start)
        return value, text[:start], text[end:]

    old, old_prefix, old_suffix = member(before)
    saved, new_prefix, new_suffix = member(after)
    require(old == TAG_PARENT and saved == (TAG_TARGET if name == TAG_MERGE else None), name + ": wrong saved default tag")
    require((old_prefix, old_suffix) == (new_prefix, new_suffix), name + ": unowned settings changed")


def check_tag_change(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    if name == TAG_CREATE:
        new = next(tag for tag in actual["tags"] if tag["name"] == "Sprint")
        require(new["id"] != TAG_PARENT and str(uuid.UUID(new["id"])).upper() == new["id"], name + ": invalid new tag identity")
        expected["tags"].append(dict(id=new["id"], name="Sprint", color="#4E64D8", parentID=TAG_PARENT,
                                     isCollapsed=False, isPinned=True))
        expected["tasks"][3].update(tagIDs=[new["id"]], updatedAt=815_907_600)
    elif name == TAG_REORDER:
        renamed = expected["tags"].pop(1)
        renamed.pop("parentID")
        renamed["name"] = "Sprint renamed"
        expected["tags"].append(renamed)
    else:
        expected["tags"].pop(0)
        for tag in expected["tags"]:
            tag.pop("parentID")
        if name == TAG_MERGE:
            expected["tags"][1]["parentID"] = TAG_TARGET
            expected["filters"][0]["tagIDs"] = [TAG_TARGET]
            expected["filters"][0]["ruleRoot"]["children"] = [rule_condition("tag", tagID=TAG_TARGET)]
        expected["tasks"][0].update(tagIDs=[TAG_TARGET], updatedAt=815_907_600)
        expected["tasks"][1].update(tagIDs=[TAG_TARGET] if name == TAG_MERGE else [], updatedAt=815_907_600)
        expected["templates"][0]["tagIDs"] = [TAG_TARGET]
    require(actual == expected, name + ": unexpected tag or unowned workspace changes")


def check_board_fixture(name, before, baseline):
    expected = copy.deepcopy(baseline)
    expected["lists"].append(dict(id=BOARD_ARCHIVE_ID, name="Reference Board", color="#4E64D8",
                                  kind="task", viewMode="board", belowFolders=False, isArchived=True,
                                  showsInSmartLists=True, isPinned=False))
    expected["tasks"][1].update(recurrence="daily", wontDoAt=815_900_400)
    expected["tasks"][2].update(listID=BOARD_ARCHIVE_ID, completedAt=815_904_000)
    expected["tasks"][4].update(listID=expected["lists"][0]["id"], kind="note")
    require(json.loads(before) == expected, name + ": unexpected Board fixture")


def check_board_change(name, before, after):
    if name == BOARD_ARCHIVE:
        require(before == after, name + ": read-only navigation rewrote workspace bytes")
        return
    expected, actual = json.loads(before), json.loads(after)
    expected["lists"][0]["viewMode"] = "board"
    if name in {BOARD_UNDO, BOARD_DROP}:
        index = 1 if name == BOARD_UNDO else 5
        changed = actual["tasks"][index]
        require(changed["updatedAt"] > expected["tasks"][index]["updatedAt"], name + ": modification time did not advance")
        expected["tasks"][index]["updatedAt"] = changed["updatedAt"]
        if name == BOARD_DROP:
            require(changed["completedAt"] == changed["updatedAt"], name + ": wrong completion stamp")
            expected["tasks"][index]["completedAt"] = changed["completedAt"]
    require(actual == expected, name + ": unexpected Board or unrelated data changes")


def check_summary_note(name, before, after, edited):
    expected, actual = json.loads(before), json.loads(after)
    require(len(actual["tasks"]) == len(expected["tasks"]) + 1, name + ": expected one new note")
    note = actual["tasks"].pop(0)
    require(actual == expected, name + ": an existing workspace value changed")
    require(str(uuid.UUID(note["id"])).upper() == note["id"] and
            note["id"] not in {task["id"] for task in expected["tasks"]}, name + ": incorrect note identity")
    require(note["title"].startswith("Summary ") and note["body"] == edited and "Edited locally" in edited and
            note["kind"] == "note" and note["priority"] == "none", name + ": edited report note was lost")
    require(all(note.get(key) is None for key in ("listID", "dueDate", "reminderDate", "scheduledDuration",
                                                 "richBody", "completedAt", "wontDoAt", "deletedAt")),
            name + ": note inherited unexpected metadata")
    require(not note["hasDueTime"] and not note["tagIDs"] and not note.get("additionalReminderDates"),
            name + ": note inherited a schedule or tags")


def check_template_change(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    if name == TEMPLATE_APPLICATION:
        source, original_child = expected["tasks"][0], expected["tasks"][3]
        require(len(actual["templates"]) == 1, name + ": expected one new template")
        template = actual["templates"][0]
        require(str(uuid.UUID(template["id"])).upper() == template["id"], name + ": invalid template identity")
        require(template["name"] == source["title"] and template["tagIDs"] == [], name + ": invalid template metadata")
        for field in ("title", "body", "richBody", "kind", "priority", "checklist"):
            require(template[field] == source[field], name + ": template did not preserve " + field)
        child = actual["tasks"][3]
        for field in ("title", "body", "richBody", "kind", "priority", "tagIDs"):
            require(child[field] == template[field], name + ": application did not copy " + field)
        steps = child["checklist"]
        require(len(steps) == len(template["checklist"]), name + ": checklist size differs")
        copied_ids = {step["id"] for step in steps}
        require(len(copied_ids) == len(steps) and copied_ids.isdisjoint(step["id"] for step in template["checklist"]),
                name + ": expected distinct, fresh checklist identities")
        for copied, original in zip(steps, template["checklist"]):
            require((copied["title"], copied["isCompleted"]) == (original["title"], original["isCompleted"]),
                    name + ": checklist content differs")
        require(child["updatedAt"] > original_child["updatedAt"], name + ": modification time did not advance")
        expected["templates"] = [template]
        owned = ("title", "body", "richBody", "kind", "priority", "tagIDs", "checklist", "updatedAt")
        original_child.update({key: child[key] for key in owned})
    require(actual == expected, name + ": unexpected template or task changes")


def check_rich_body_edit(name, before, after):
    expected, actual = json.loads(before), json.loads(after)
    task = expected["tasks"][0]
    edited = actual["tasks"][0]
    require(edited["updatedAt"] > task["updatedAt"], name + ": modification time did not advance")
    task["updatedAt"] = edited["updatedAt"]
    rich = task["richBody"]
    if name == RICH_INLINE_EDIT:
        original = rich["runs"][0]
        rich["runs"] = [dict(original, length=7, italic=True, link="https://example.test/project"),
                        dict(original, location=7, length=9)]
    elif name == RICH_PLAIN_PASTE:
        rich["runs"] = [dict(rich["runs"][0], location=7, length=9)]
    else:
        task["body"] += " Rich update"
        rich["text"] = task["body"]
        prefix, _, last = task["body"].rpartition("\n")
        rich["blocks"] = [{"location": len((prefix + "\n").encode("utf-16-le")) // 2,
                           "length": len(last.encode("utf-16-le")) // 2, "quote": True, "rule": False}]
    require(actual == expected, name + ": text, formatting or unowned task fields differ")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", type=Path, required=True)
    parser.add_argument("--attachments", type=Path, required=True)
    parser.add_argument("--mac-tool", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--capture", action="store_true", help="also audit the ten native capture cases")
    parser.add_argument("--lifecycle", action="store_true", help="audit lifecycle cases, including earlier cases when --capture is used")
    parser.add_argument("--schedule", action="store_true", help="also audit the native scheduling cases")
    parser.add_argument("--arrange", action="store_true", help="also audit Arrange and direct Calendar edits")
    parser.add_argument("--preferences", action="store_true", help="audit persisted Calendar preferences and presentation")
    parser.add_argument("--rich-preview", action="store_true", help="also audit the styled and malformed description cases")
    parser.add_argument("--metadata", action="store_true", help="also audit priority, tags and embedded checklist cases")
    parser.add_argument("--hierarchy", action="store_true", help="also audit linked subtask creation, move and detach")
    parser.add_argument("--organization", action="store_true", help="also audit list and folder management")
    parser.add_argument("--smart-lists", action="store_true", help="also audit saved Smart List visibility and order")
    parser.add_argument("--saved-filters", action="store_true", help="also audit normal and advanced filter authoring")
    parser.add_argument("--tags", action="store_true", help="also audit tag creation, merge and deletion")
    parser.add_argument("--boards", action="store_true", help="audit list modes, archived and status boards")
    parser.add_argument("--summary", action="store_true", help="audit edited Summary note capture")
    parser.add_argument("--search", action="store_true", help="audit local search and saved search criteria")
    parser.add_argument("--templates", action="store_true", help="audit template management and application")
    parser.add_argument("--local-settings", action="store_true", help="audit local settings and new-capture defaults")
    parser.add_argument("--rich-editor", action="store_true", help="audit the saved styled description")
    parser.add_argument("--only-case", help="audit a focused result bundle containing one known case")
    args = parser.parse_args()
    fixtures = Path(__file__).resolve().parent.parent / "Mobile/Fixtures"
    workspace = (fixtures / "MobileQAWorkspace.json").read_bytes()
    settings = (fixtures / "MobileQASettings.json").read_bytes()
    baseline = json.loads(workspace)
    qa_root = args.container.resolve() / "Library/Application Support/TaskovskyMobile/QA"
    require(qa_root.is_dir(), "The owned app's QA directory is missing")
    expected = {
        "testCalendarFilterReset", "testCalendarViews",
        "testDirtyCancelKeepsOrDiscardsWithoutSavingTask",
        "testPlainDescriptionRecoveryDoesNotAutosubmit",
        "testRecoveryDiscardDoesNotSubmitDraft", "testSaveFailureRetainsEditorAndDraft",
        "testSearchResultsStayReadOnly", "testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask",
        "testStyledDescriptionIsProtected", "testStyledTaskTitleSavesAndSurvivesRelaunch",
        "testUnchangedDoneAndViewOnlyNavigationPreserveTaskFile",
        "testUnknownDataBlocksPhoneEditing", "testUnknownDraftIsPreservedAndBlocksReplacement",
    }
    if args.capture:
        expected |= set(CAPTURE_TITLES) | CAPTURE_NO_CREATE
    if args.lifecycle:
        expected = expected | LIFECYCLE if args.capture else set(LIFECYCLE)
    if args.schedule:
        expected = expected | SCHEDULE if args.capture or args.lifecycle else set(SCHEDULE)
    if args.arrange:
        expected = expected | ARRANGE if args.capture or args.lifecycle or args.schedule else set(ARRANGE)
    if args.preferences:
        focused_preferences = PREFERENCES | {"testCalendarFilterReset", "testCalendarViews"}
        expected = expected | focused_preferences if args.capture or args.lifecycle or args.schedule or args.arrange else focused_preferences
    if args.rich_preview:
        rich_workflows = RICH_CASES | {"testStyledDescriptionIsProtected", "testStyledTaskTitleSavesAndSurvivesRelaunch"}
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences:
            expected |= rich_workflows
        else:
            expected = rich_workflows
    if args.metadata:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview:
            expected |= METADATA
        else:
            expected = METADATA
    if args.hierarchy:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata:
            expected |= HIERARCHY
        else:
            expected = HIERARCHY
    if args.organization:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy:
            expected |= ORGANIZATION
        else:
            expected = ORGANIZATION
    if args.smart_lists:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy or args.organization:
            expected |= SMART_LISTS
        else:
            expected = SMART_LISTS
    if args.saved_filters:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy or args.organization or args.smart_lists:
            expected |= SAVED_FILTERS
        else:
            expected = SAVED_FILTERS
    if args.tags:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy or args.organization or args.smart_lists or args.saved_filters:
            expected |= TAG_ORGANIZATION
        else:
            expected = TAG_ORGANIZATION
    if args.boards:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy or args.organization or args.smart_lists or args.saved_filters or args.tags:
            expected |= BOARD_CASES
        else:
            expected = BOARD_CASES
    if args.summary:
        if args.capture or args.lifecycle or args.schedule or args.arrange or args.preferences or args.rich_preview or args.metadata or args.hierarchy or args.organization or args.smart_lists or args.saved_filters or args.tags or args.boards:
            expected |= SUMMARY_CASES
        else:
            expected = SUMMARY_CASES
    if args.search:
        if any((args.capture, args.lifecycle, args.schedule, args.arrange, args.preferences, args.rich_preview,
                args.metadata, args.hierarchy, args.organization, args.smart_lists, args.saved_filters, args.tags,
                args.boards, args.summary)):
            expected |= SEARCH_CASES
        else:
            expected = SEARCH_CASES | {"testSearchResultsStayReadOnly"}
    if args.templates:
        if any((args.capture, args.lifecycle, args.schedule, args.arrange, args.preferences, args.rich_preview,
                args.metadata, args.hierarchy, args.organization, args.smart_lists, args.saved_filters, args.tags,
                args.boards, args.summary, args.search)):
            expected |= TEMPLATE_CASES
        else:
            expected = TEMPLATE_CASES
    if args.local_settings:
        if any((args.capture, args.lifecycle, args.schedule, args.arrange, args.preferences, args.rich_preview,
                args.metadata, args.hierarchy, args.organization, args.smart_lists, args.saved_filters, args.tags,
                args.boards, args.summary, args.search, args.templates)):
            expected.add(LOCAL_SETTINGS)
        else:
            expected = {LOCAL_SETTINGS}
    if args.rich_editor:
        if any((args.capture, args.lifecycle, args.schedule, args.arrange, args.preferences, args.rich_preview,
                args.metadata, args.hierarchy, args.organization, args.smart_lists, args.saved_filters, args.tags,
                args.boards, args.summary, args.search, args.templates, args.local_settings)):
            expected |= RICH_EDITOR_CASES
        else:
            expected = RICH_EDITOR_CASES
    if args.only_case:
        require(args.only_case in expected, "Unknown focused QA case")
        expected = {args.only_case}
    rows = []
    for test in json.loads((args.attachments / "manifest.json").read_text()):
        sessions = [a for a in test["attachments"] if a["suggestedHumanReadableName"].startswith("QA session")]
        if not sessions:
            continue
        require(len(sessions) == 1, "Ambiguous session attachment")
        name = test["testIdentifier"].split("/")[-1].removesuffix("()")
        require(name in expected, "Unexpected QA case")
        session_file = args.attachments / sessions[0]["exportedFileName"]
        require(session_file.resolve().parent == args.attachments.resolve(), "Invalid attachment path")
        session = str(uuid.UUID(session_file.read_text().strip())).upper()
        root = qa_root / session
        require(root.resolve().parent == qa_root.resolve(), "Invalid QA directory")
        before = (root / "initial-workspace.json").read_bytes()
        after = (root / "workspace.json").read_bytes()
        initial_settings = (root / "initial-settings.json").read_bytes()
        if name in PREFERENCES_FIXTURE or name in TAG_FIXTURE_CASES or name in SUMMARY_CASES:
            expected_settings = json.loads(settings)
            if name in PREFERENCES_FIXTURE:
                expected_settings["calendarOptions"]["additionalTimeZones"] = expected_settings["calendarOptions"]["additionalTimeZones"][:2]
            elif name in TAG_FIXTURE_CASES:
                expected_settings["defaultTagID"] = TAG_PARENT
            else:
                expected_settings.update(defaultTagID=TAG_PARENT, defaultListID=baseline["lists"][0]["id"],
                                         defaultDate="today", defaultPriority="high")
            actual_settings = json.loads(initial_settings)
            for fixture_settings in (expected_settings, actual_settings):
                pairs = fixture_settings["smartListVisibility"]
                mapping = dict(zip(pairs[::2], pairs[1::2]))
                require(len(mapping) * 2 == len(pairs), "Unexpected ambiguous smart-list settings in fixture")
                fixture_settings["smartListVisibility"] = mapping
            if name in SUMMARY_CASES:
                expected_settings["smartListVisibility"]["summary"] = "show"
            require(actual_settings == expected_settings, name + ": unexpected preference fixture")
        else:
            require(name == EMPTY or initial_settings == settings, name + ": wrong Mac settings fixture")
        current_settings = (root / "settings.json").read_bytes()
        if name == SMART_LIST_CHANGE:
            check_smart_lists(initial_settings, current_settings)
        elif name in TAG_PAIR_CASES:
            check_tag_settings(name, initial_settings, current_settings)
        elif name == LOCAL_SETTINGS:
            expected_settings = json.loads(initial_settings)
            work = next(item for item in baseline["lists"] if item["name"] == "Work")
            expected_settings.update(startWeekOn=1, defaultPriority="high", defaultListID=work["id"])
            require(json.loads(current_settings) == expected_settings, name + ": unexpected saved settings")
        elif args.preferences or args.metadata:
            check_calendar_preferences(name, initial_settings, current_settings)
        else:
            require(current_settings == initial_settings, name + ": settings were rewritten")
        field_changed = name in {"testPlainDescriptionRecoveryDoesNotAutosubmit", "testStyledTaskTitleSavesAndSurvivesRelaunch", "testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask", STALE, RICH_PREVIEW}
        capture_created = name in CAPTURE_TITLES
        lifecycle_changed = name in LIFECYCLE and name != LIFECYCLE_FAILURE
        schedule_changed = name in SCHEDULE_CHANGED
        arranged = name in ARRANGE
        metadata_changed = name in METADATA_CHANGED
        hierarchy_changed = name in HIERARCHY
        organization_changed = name in ORGANIZATION and name != ORGANIZATION_FAILURE
        saved_filter_mutation = name in SAVED_FILTER_MUTATIONS
        unknown = name == "testUnknownDataBlocksPhoneEditing"
        if unknown:
            expected_unknown = copy.deepcopy(baseline)
            expected_unknown["tasks"][-1]["futurePayload"] = {"version": 99, "retained": True}
            require(json.loads(before) == expected_unknown, name + ": incorrect unknown-field fixture")
        elif name == EMPTY:
            empty = json.loads(before)
            require(empty.keys() == baseline.keys() and all(v == [] for v in empty.values()), "Expected a completely empty initial QA workspace")
        elif name == TEMPLATE:
            initial = json.loads(before)
            seeds = initial.pop("templates")
            require(len(seeds) == 1 and seeds[0]["name"] == "Styled project" and seeds[0]["richBody"] == baseline["tasks"][0]["richBody"], "Expected the synthetic neutral styled template")
            initial["templates"] = []
            require(initial == baseline, "Template QA setup changed other Mac fixture fields")
        elif name == ORGANIZATION_COPY:
            require(json.loads(before) == organization_fixture(baseline), name + ": unexpected organization fixture")
        elif name == SAVED_FILTER_RENAME:
            require(json.loads(before) == saved_filter_fixture(baseline), name + ": unexpected saved filter fixture")
        elif name in TAG_ORGANIZATION:
            check_tag_fixture(name, before, baseline)
        elif name in BOARD_CASES:
            check_board_fixture(name, before, baseline)
        elif name == SEARCH_ARCHIVE:
            require(json.loads(before) == lifecycle_fixture(baseline), name + ": unexpected archived search fixture")
        elif name in METADATA_FIXTURE or hierarchy_changed or name in {SEARCH_ROUTES, TEMPLATE_APPLICATION}:
            require(json.loads(before) == metadata_fixture(baseline), name + ": unexpected metadata fixture")
        elif name in RICH_CASES:
            expected_fixture = copy.deepcopy(baseline)
            if name == MALFORMED_RICH:
                expected_fixture["tasks"][0]["richBody"]["runs"][0]["length"] = 2**63 - 1
            else:
                task = json.loads(before)["tasks"][0]
                expected_fixture["tasks"][0].update(body=task["body"], richBody=task["richBody"])
                require(task["richBody"]["text"] == task["body"] and len(task["richBody"]["runs"]) == 4 and
                        len(task["richBody"]["blocks"]) == 7, name + ": malformed compound seed")
            require(json.loads(before) == expected_fixture, name + ": unrelated seed fields changed")
        elif name in PREFERENCES_FIXTURE:
            expected_fixture = copy.deepcopy(baseline)
            expected_fixture["tasks"][0]["recurrence"] = "daily"
            expected_fixture["tasks"][0]["checklist"] = [{"id": "00000000-0000-0000-0000-000000000501", "title": "Review the first step", "isCompleted": False}]
            expected_fixture["tasks"][3]["completedAt"] = 815_907_600
            require(json.loads(before) == expected_fixture, name + ": unexpected Calendar content fixture")
        elif name == ARRANGE_FOCUSED:
            expected_fixture = copy.deepcopy(baseline)
            expected_fixture["tasks"][2]["priority"] = "high"
            expected_fixture["tasks"][3]["dueDate"] = 815_821_200
            require(json.loads(before) == expected_fixture, name + ": unexpected Arrange fixture")
        elif not lifecycle_changed:
            require(before == workspace, name + ": baseline was not produced by Mac TaskStore")
        if lifecycle_changed:
            check_lifecycle(name, baseline, before, after)
        elif capture_created:
            check_capture(name, before, after)
        elif schedule_changed:
            check_schedule(name, before, after)
        elif arranged:
            check_arrange(name, before, after)
        elif metadata_changed:
            check_metadata(name, before, after)
        elif hierarchy_changed:
            check_hierarchy(name, before, after)
        elif organization_changed:
            check_organization(name, before, after)
        elif saved_filter_mutation:
            check_saved_filter(name, before, after)
        elif name in TAG_ORGANIZATION:
            check_tag_change(name, before, after)
        elif name in BOARD_CASES:
            check_board_change(name, before, after)
        elif name == SUMMARY_NOTE:
            outputs = [item for item in test["attachments"] if item["suggestedHumanReadableName"].startswith("Summary edited output")]
            require(len(outputs) == 1, name + ": missing exact report attachment")
            exported = args.attachments / outputs[0]["exportedFileName"]
            require(exported.resolve().parent == args.attachments.resolve(), "Invalid report attachment path")
            check_summary_note(name, before, after, exported.read_bytes().decode("utf-8"))
        elif name in TEMPLATE_CASES:
            check_template_change(name, before, after)
        elif name in RICH_EDITOR_CASES:
            check_rich_body_edit(name, before, after)
        elif field_changed:
            original, actual = json.loads(before), json.loads(after)
            task_id = "00000000-0000-0000-0000-000000000002" if name == "testPlainDescriptionRecoveryDoesNotAutosubmit" else "00000000-0000-0000-0000-000000000001"
            prior = next(t for t in original["tasks"] if t["id"] == task_id)
            current = next(t for t in actual["tasks"] if t["id"] == task_id)
            if name == "testPlainDescriptionRecoveryDoesNotAutosubmit":
                field, value = "body", "A neutral sample description.\nRecovered line"
            elif name in {"testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask", STALE}:
                field, value = "title", "Changed elsewhere"
            elif name == RICH_PREVIEW:
                field, value = "title", "Review the project outline with formatting"
            else:
                field, value = "title", "Review the project outline saved locally"
            require(current[field] == value, name + ": owned field differs")
            require(current["updatedAt"] > prior["updatedAt"], name + ": modification time did not advance")
            current[field], current["updatedAt"] = prior[field], prior["updatedAt"]
            require(actual == original, name + ": an unowned field changed")
        else:
            require(before == after, name + ": no-op/view/refusal rewrote workspace bytes")
        scratch = root / "field-draft.json"
        if name == "testUnknownDraftIsPreservedAndBlocksReplacement":
            require(scratch.read_bytes() == b'{"version":99,"opaque":"Retain original"}', "Unknown recovery data changed")
        else:
            require(not scratch.exists(), name + ": an abandoned/completed recovery file remains")
        require(not (root / "capture-draft.json").exists(), name + ": capture scratch was not cleared")
        require(not (root / "workspace.json.tag-transaction").exists(), name + ": tag transaction did not clear")
        mac_reload = False
        if not unknown:
            mode = "verify-first-capture" if name == EMPTY else "verify-capture" if capture_created else "verify"
            if name == RICH_PREVIEW:
                mode = "verify-rich-preview"
            elif name == LIFECYCLE_COMPLETE:
                mode = "verify-lifecycle-complete"
            elif name == LIFECYCLE_PURGE:
                mode = "verify-lifecycle-purge"
            elif hierarchy_changed:
                mode = {HIERARCHY_CREATE: "verify-hierarchy-create", HIERARCHY_MOVE: "verify-hierarchy-move",
                        HIERARCHY_DETACH: "verify-hierarchy-detach"}[name]
            elif organization_changed:
                mode = {ORGANIZATION_COPY: "verify-organization-copy", ORGANIZATION_FOLDER: "verify-organization-folder",
                        ORGANIZATION_ARCHIVE: "verify-organization-archive"}[name]
            elif name == SMART_LIST_CHANGE:
                mode = "verify-smart-lists"
            elif name in {SAVED_FILTER_ADVANCED, SAVED_FILTER_RENAME}:
                mode = "verify-saved-filter-advanced" if name == SAVED_FILTER_ADVANCED else "verify-saved-filter-rename"
            elif name in TAG_PAIR_CASES:
                mode = "verify-tag-merge" if name == TAG_MERGE else "verify-tag-delete"
            elif name in BOARD_CASES:
                mode = {BOARD_ARCHIVE: "verify-board-archive", BOARD_MODE: "verify-board-mode",
                        BOARD_UNDO: "verify-board-undo", BOARD_DROP: "verify-board-drop"}[name]
            elif name == SUMMARY_NOTE:
                mode = "verify-summary-note"
            elif name == SEARCH_ARCHIVE:
                mode = "verify-search-filter"
            elif name == TEMPLATE_APPLICATION:
                mode = "verify-template-application"
            elif name == LOCAL_SETTINGS:
                mode = "verify-local-settings"
            elif name == RICH_BODY_EDIT:
                mode = "verify-rich-editor"
            elif name == RICH_INLINE_EDIT:
                mode = "verify-rich-inline-edit"
            elif name == RICH_PLAIN_PASTE:
                mode = "verify-rich-plain-paste"
            subprocess.run([str(args.mac_tool.resolve()), mode, str(root)], check=True, capture_output=True, text=True)
            mac_reload = True
        rows.append({"test": name, "passed": True, "workspaceChanged": before != after, "captureCreated": capture_created,
                     "workspaceSHA256": digest(after), "settingsChanged": current_settings != initial_settings,
                     "macReloadWithoutWrites": mac_reload})
    require({r["test"] for r in rows} == expected and len(rows) == len(expected), "Missing/duplicate QA cases")
    report = {"readOnlyAudit": True, "macFixtureSHA256": digest(workspace), "settingsSHA256": digest(settings),
              "qaCases": sorted(rows, key=lambda r: r["test"]), "passed": len(rows),
              "macReloadsWithoutWrites": sum(r["macReloadWithoutWrites"] for r in rows)}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Passed {len(rows)} QA file audits and {report['macReloadsWithoutWrites']} Mac reloads without writes")


if __name__ == "__main__":
    main()
