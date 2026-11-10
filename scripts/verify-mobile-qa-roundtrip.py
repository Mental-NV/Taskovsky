#!/usr/bin/env python3
"""Read-only audit of neutral XCTest QA folders, never a normal workspace."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
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


def check_lifecycle(name, baseline, before, after):
    fixture = copy.deepcopy(baseline)
    tasks = fixture["tasks"]
    root_id, child_id, archive_id, finished_id, separate_id = (task["id"] for task in tasks[:5])
    tasks[0]["recurrence"] = "daily"
    tasks[1]["parentID"] = root_id
    tasks[1].pop("listID")
    tasks[3].update(parentID=root_id, completedAt=815900400)
    tasks[4].update(parentID=root_id, deletedAt=815904000)
    tasks[4].pop("listID")
    tasks[6]["kind"] = "note"
    fixture["lists"][1]["isArchived"] = True
    original, actual = json.loads(before), json.loads(after)
    require(original == fixture, name + ": unexpected lifecycle fixture")
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", type=Path, required=True)
    parser.add_argument("--attachments", type=Path, required=True)
    parser.add_argument("--mac-tool", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--capture", action="store_true", help="also audit the ten native capture cases")
    parser.add_argument("--lifecycle", action="store_true", help="audit lifecycle cases, including earlier cases when --capture is used")
    parser.add_argument("--schedule", action="store_true", help="also audit the native scheduling cases")
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
        require(name == EMPTY or initial_settings == settings, name + ": wrong Mac settings fixture")
        require((root / "settings.json").read_bytes() == initial_settings, name + ": settings were rewritten")
        field_changed = name in {"testPlainDescriptionRecoveryDoesNotAutosubmit", "testStyledTaskTitleSavesAndSurvivesRelaunch", "testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask", STALE}
        capture_created = name in CAPTURE_TITLES
        lifecycle_changed = name in LIFECYCLE and name != LIFECYCLE_FAILURE
        schedule_changed = name in SCHEDULE_CHANGED
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
        elif not lifecycle_changed:
            require(before == workspace, name + ": baseline was not produced by Mac TaskStore")
        if lifecycle_changed:
            check_lifecycle(name, baseline, before, after)
        elif capture_created:
            check_capture(name, before, after)
        elif schedule_changed:
            check_schedule(name, before, after)
        elif field_changed:
            original, actual = json.loads(before), json.loads(after)
            task_id = "00000000-0000-0000-0000-000000000002" if name == "testPlainDescriptionRecoveryDoesNotAutosubmit" else "00000000-0000-0000-0000-000000000001"
            prior = next(t for t in original["tasks"] if t["id"] == task_id)
            current = next(t for t in actual["tasks"] if t["id"] == task_id)
            if name == "testPlainDescriptionRecoveryDoesNotAutosubmit":
                field, value = "body", "A neutral sample description.\nRecovered line"
            elif name in {"testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask", STALE}:
                field, value = "title", "Changed elsewhere"
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
        mac_reload = False
        if not unknown:
            mode = "verify-first-capture" if name == EMPTY else "verify-capture" if capture_created else "verify"
            if name == LIFECYCLE_COMPLETE:
                mode = "verify-lifecycle-complete"
            elif name == LIFECYCLE_PURGE:
                mode = "verify-lifecycle-purge"
            subprocess.run([str(args.mac_tool.resolve()), mode, str(root)], check=True, capture_output=True, text=True)
            mac_reload = True
        rows.append({"test": name, "passed": True, "workspaceChanged": field_changed or capture_created or lifecycle_changed or schedule_changed, "captureCreated": capture_created,
                     "workspaceSHA256": digest(after), "macReloadWithoutWrites": mac_reload})
    require({r["test"] for r in rows} == expected and len(rows) == len(expected), "Missing/duplicate QA cases")
    report = {"readOnlyAudit": True, "macFixtureSHA256": digest(workspace), "settingsSHA256": digest(settings),
              "qaCases": sorted(rows, key=lambda r: r["test"]), "passed": len(rows),
              "macReloadsWithoutWrites": sum(r["macReloadWithoutWrites"] for r in rows)}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Passed {len(rows)} QA file audits and {report['macReloadsWithoutWrites']} Mac reloads without writes")


if __name__ == "__main__":
    main()
