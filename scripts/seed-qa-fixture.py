#!/usr/bin/env python3
"""Seed an isolated Taskovsky QA fixture under /tmp/TaskovskyQA/.

Generates workspace.json (+ settings.json) with stable UUIDs covering the
stage scope for parent CUA checks:

- rich bodies: mixed bold/italic/underline/strike, H1-H6, link, highlight,
  inline code, quote, bulleted/numbered/checklist paragraphs, emoji,
  horizontal rule
- organization: archived list (read-only), smart-list-excluded list,
  regular + pinned lists, a folder, nested tags + pinned tag, normal and
  advanced-rule filters (incl. nextMonth) + pinned filter, a pinned task
- hierarchy/duration/recurrence: a parent + subtask pair, a custom weekly
  repeat series, an end-count (maxOccurrences) series, a timed task with a
  scheduled window, a same-body undo pair, an empty-body draft

Dates are seconds since 2001-01-01 UTC (Swift JSONDecoder's default
deferredToDate Double strategy). datetime.timestamp() is 1970-based and
loads 31 years in the future — always subtract the 2001 delta.
ISO-8601 strings do NOT load and void the whole file.

Usage:
    python3 scripts/seed-qa-fixture.py [--dir /tmp/TaskovskyQA]
    ./scripts/build-app.sh
    open build/Taskovsky.app --args --workspace /tmp/TaskovskyQA/workspace.json

Never points at or modifies the real user workspace.
"""
import argparse
import datetime
import json
import os
import sys
import uuid

RICH = "rich"


def u16(s):
    """UTF-16 code-unit length (matches NSString.length, emoji = 2)."""
    return len(s.encode("utf-16-le")) // 2


def span(loc, text, **attrs):
    run = {"location": loc, "length": u16(text)}
    run.update(attrs)
    return run


def block(loc, text, **attrs):
    run = {"location": loc, "length": u16(text)}
    run.update(attrs)
    return run


def para_offsets(text):
    """Start offset (UTF-16) of each paragraph in text."""
    offs, cur, out = 0, 0, []
    lines = text.split("\n")
    for line in lines:
        out.append(cur)
        cur += u16(line) + 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="/tmp/TaskovskyQA")
    args = ap.parse_args()
    os.makedirs(args.dir, exist_ok=True)

    def ID(name):
        return str(uuid.uuid5(uuid.NAMESPACE_URL, "taskovsky-qa-" + name))

    # ---- lists / folders / tags / filters -------------------------------
    folder_side = {"id": ID("folder-side"), "name": "Side", "isPinned": False}
    lists = [
        {"id": ID("list-inbox-work"), "name": "Work", "color": "#4A90D9", "kind": "task",
         "symbol": "briefcase", "viewMode": "list", "folderID": None, "belowFolders": False,
         "isArchived": False, "showsInSmartLists": True, "isPinned": False},
        {"id": ID("list-recipes"), "name": "Recipes", "color": "#E8A0BF", "kind": "task",
         "symbol": "book", "viewMode": "board", "folderID": ID("folder-side"), "belowFolders": False,
         "isArchived": False, "showsInSmartLists": True, "isPinned": True},
        {"id": ID("list-old"), "name": "Old Project", "color": "#999999", "kind": "task",
         "symbol": "folder", "folderID": None, "belowFolders": False,
         "isArchived": True, "showsInSmartLists": True, "isPinned": False},
        {"id": ID("list-someday"), "name": "Someday", "color": "#B8B8B8", "kind": "task",
         "symbol": "clock", "folderID": None, "belowFolders": True,
         "isArchived": False, "showsInSmartLists": False, "isPinned": False},
    ]
    tag_area, tag_proj, tag_urgent = ID("tag-area"), ID("tag-proj"), ID("tag-urgent")
    tags = [
        {"id": tag_area, "name": "Area", "color": "#7ED321", "parentID": None,
         "isCollapsed": False, "isPinned": False},
        {"id": tag_proj, "name": "Website", "color": "#50E3C2", "parentID": tag_area,
         "isCollapsed": False, "isPinned": True},
        {"id": tag_urgent, "name": "Urgent", "color": "#D0021B", "parentID": None,
         "isCollapsed": False, "isPinned": False},
    ]
    filters = [
        {"id": ID("filter-due-urgent"), "name": "Due High", "listIDs": [], "tagIDs": [tag_urgent],
         "priorities": ["high"], "dateRules": ["today", "next7"], "status": "active",
         "keyword": "", "kinds": ["task"], "tagMode": "any", "isPinned": False, "ruleRoot": None},
        {"id": ID("filter-focus"), "name": "Focus (advanced)", "listIDs": [], "tagIDs": [],
         "priorities": [], "dateRules": [], "status": "active",
         "keyword": "", "kinds": [], "tagMode": "any", "isPinned": True,
         "ruleRoot": {
             "type": "and",
             "children": [
                 {"type": "or", "children": [
                     {"type": "condition", "condition": {"kind": "priority", "priority": "high"}},
                     {"type": "condition", "condition": {"kind": "date", "dateRule": "today"}},
                 ]},
                 {"type": "not", "child": {"type": "condition", "condition": {"kind": "noTags"}}},
             ]}},
        {"id": ID("filter-not-someday"), "name": "Not Someday (advanced)", "listIDs": [], "tagIDs": [],
         "priorities": [], "dateRules": [], "status": "active",
         "keyword": "", "kinds": [], "tagMode": "any", "isPinned": False,
         "ruleRoot": {
             "type": "not",
             "child": {"type": "condition", "condition": {"kind": "list", "listID": ID("list-someday")}}}},
    ]

    # ---- tasks -----------------------------------------------------------
    # Seconds since 2001-01-01 UTC (Swift deferredToDate). datetime's
    # timestamp() is 1970-based; forgetting the delta lands 31 years ahead.
    ref2001 = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    ts = (now - ref2001).total_seconds()
    due_ts = ts + 3 * 86400

    def base(title, **kw):
        t = {"id": str(uuid.uuid4()), "title": title, "body": "", "listID": None,
             "tagIDs": [], "kind": "task", "priority": "none", "recurrence": "none",
             "hasDueTime": False, "checklist": [], "createdAt": ts, "updatedAt": ts,
             "occurrenceIndex": 1}
        t.update(kw)
        return t

    # Rich showcase body: headings, mixed inline styles, lists, quote, link, emoji.
    # List/quote/checklist paragraphs carry NO literal markers (no bullets,
    # numbers, boxes, or ">"): RichRender decorates those blocks itself, so
    # literal prefixes would draw doubled markers.
    body1_lines = [
        "Launch checklist 🎉",
        "Ship the release",
        "Bold and italic mix here",
        "bulleted item",
        "second bullet",
        "first step",
        "second step",
        "unchecked box",
        "checked box",
        "quoted line",
        "code snippet and link below",
        "",
        "tail line after the rule",
    ]
    body1 = "\n".join(body1_lines)
    po = para_offsets(body1)
    runs1 = []
    # Inline styles located from substrings (never stale constants) in
    # paragraph 2 ("Bold and italic mix here"): Bold 0-4, italic 9-15,
    # mix 16-19, here 20-24.
    p2, p2line = po[2], body1_lines[2]
    for word, attrs in (("Bold", {"bold": True}), ("italic", {"italic": True}),
                        ("mix", {"underline": True}), ("here", {"strikethrough": True})):
        loc = p2line.index(word)
        assert p2line[loc:loc + len(word)] == word
        runs1.append(span(p2 + u16(p2line[:loc]), word, **attrs))
    # link on "link" + highlight on "highlight"? paragraph 10: "code snippet and link below"
    p10 = po[10]
    runs1.append(span(p10 + 0, "code snippet", code=True))
    runs1.append(span(p10 + 17, "link", link="https://example.com"))
    runs1.append(span(p10 + 17, "link", highlight=True))
    blocks1 = [
        block(po[0], body1_lines[0] + "\n", heading=1),
        block(po[1], body1_lines[1] + "\n", heading=4),
        block(po[3], body1_lines[3] + "\n", list="bullet"),
        block(po[4], body1_lines[4] + "\n", list="bullet"),
        block(po[5], body1_lines[5] + "\n", list="numbered"),
        block(po[6], body1_lines[6] + "\n", list="numbered"),
        block(po[7], body1_lines[7] + "\n", list="checklist", checked=False),
        block(po[8], body1_lines[8] + "\n", list="checklist", checked=True),
        block(po[9], body1_lines[9] + "\n", quote=True),
        block(po[11], "\n", rule=True),
    ]

    parent_id = str(uuid.uuid4())
    tasks = [
        base("Release QA", body=body1, listID=ID("list-inbox-work"),
             tagIDs=[tag_proj, tag_urgent], priority="high",
             richBody={"text": body1, "runs": runs1, "blocks": blocks1},
             isPinned=True),
        base("Buy oat milk", body="plain body, no styles", listID=ID("list-inbox-work"),
             tagIDs=[tag_urgent]),
        # Same-body pair for document-scoped undo QA: identical text, distinct
        # records — edits in one must never leak into the other's history.
        base("Buy almond milk", body="plain body, no styles", listID=ID("list-inbox-work")),
        # Empty body: the toolbar must style an empty document (heading/list
        # start, typing) without crashing or dropping the styles.
        base("Empty draft", body="", listID=ID("list-inbox-work")),
        # Truly blank body for the final empty-editor Return/exit check
        # (empty-doc arming, Return-before-first-input, trailing exits).
        base("Final empty editor QA", body="", listID=ID("list-inbox-work")),
        base("Archived relic", body="read-only content", listID=ID("list-old")),
        base("Someday idea", body="hidden from smart lists, keeps reminders",
             listID=ID("list-someday"),
             reminderDate=due_ts),
        base("Website relaunch", id=parent_id, body="parent of two subtasks",
             listID=ID("list-inbox-work"), tagIDs=[tag_proj]),
        base("Draft announcement", body="nested under Website relaunch",
             listID=ID("list-inbox-work"), parentID=parent_id),
        base("Update screenshots", body="second subtask",
             listID=ID("list-inbox-work"), parentID=parent_id),
        base("Water plants", body="custom weekly series", listID=ID("list-inbox-work"),
             dueDate=due_ts, hasDueTime=True,
             customRecurrence={"anchor": "dueDate", "interval": 1, "unit": "weeks",
                               "weekdays": [2, 4], "skipWeekends": False}),
        base("Pay rent", body="end-count monthly series (5 occurrences)",
             listID=ID("list-inbox-work"), dueDate=due_ts, hasDueTime=False,
             customRecurrence={"anchor": "dueDate", "interval": 1, "unit": "months",
                               "maxOccurrences": 5}),
        base("Dentist", body="timed with a scheduled window",
             listID=ID("list-inbox-work"), dueDate=due_ts, hasDueTime=True,
             scheduledDuration={"start": due_ts - 3600, "end": due_ts, "isAllDay": False}),
    ]

    workspace = {"tasks": tasks, "lists": lists, "tags": tags,
                 "folders": [folder_side], "filters": filters, "templates": []}
    ws_path = os.path.join(args.dir, "workspace.json")
    with open(ws_path, "w", encoding="utf-8") as f:
        json.dump(workspace, f, indent=2, ensure_ascii=False)
        f.write("\n")

    settings = {"defaultListID": ID("list-inbox-work")}
    with open(os.path.join(args.dir, "settings.json"), "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

    # Validate offsets: every run/block must sit inside the body (UTF-16).
    for t in tasks:
        rich = t.get("richBody")
        if not rich:
            continue
        size = u16(rich["text"])
        assert rich["text"] == t["body"], "rich text must mirror body"
        for r in rich["runs"] + rich["blocks"]:
            assert 0 <= r["location"] <= size, r
            assert r["length"] > 0 and r["location"] + r["length"] <= size, r

    print("Wrote", ws_path)
    print("Launch: ./scripts/build-app.sh && open build/Taskovsky.app --args --workspace", ws_path)


if __name__ == "__main__":
    sys.exit(main())
