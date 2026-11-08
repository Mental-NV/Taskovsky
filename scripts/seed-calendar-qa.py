#!/usr/bin/env python3
"""Seed a disposable local Calendar fixture; never reads the real workspace."""
import argparse
import datetime as dt
import json
from pathlib import Path
import uuid
from zoneinfo import ZoneInfo


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dir', default='/private/tmp/TaskovskyCalendarQA')
    args = parser.parse_args()
    root = Path(args.dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    zone = ZoneInfo('Europe/Moscow')
    today = dt.datetime.now(zone).replace(hour=0, minute=0, second=0, microsecond=0)
    epoch = dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc)
    def stamp(day=0, hour=0, minute=0):
        return ((today + dt.timedelta(days=day, hours=hour, minutes=minute)) - epoch).total_seconds()
    def ident(name):
        return str(uuid.uuid5(uuid.NAMESPACE_URL, 'taskovsky-calendar-qa-' + name)).upper()
    lists = [dict(id=ident(name), name=name, color=color, kind='task', isArchived=archived, showsInSmartLists=smart)
             for name, color, archived, smart in [('Calendar Work', '#528DD9', False, True),
                 ('Calendar Personal', '#58A888', False, True), ('Calendar Archived', '#888888', True, True),
                 ('Calendar Excluded', '#AE79CE', False, False)]]
    tags = [dict(id=ident('Area'), name='Area', color='#CD8356'),
            dict(id=ident('Project'), name='Project', color='#D9A354', parentID=ident('Area'))]
    tasks = []
    def task(title, start=None, end=None, all_day=False, list_name='Calendar Work', **extra):
        item = dict(id=ident(title), title=title, body='', listID=ident(list_name), tagIDs=[], kind='task',
                    priority='none', recurrence='none', hasDueTime=start is not None and not all_day,
                    checklist=[], createdAt=stamp(), updatedAt=stamp(), occurrenceIndex=1, timeZoneID='Europe/Moscow')
        if start is not None:
            item['dueDate'] = end if end is not None else start
            if end is not None:
                item['scheduledDuration'] = dict(start=start, end=end, isAllDay=all_day)
        item.update(extra)
        tasks.append(item)
    task('Calendar overlap A', stamp(hour=9), stamp(hour=10, minute=30), tagIDs=[ident('Project')])
    task('Calendar overlap B', stamp(hour=9, minute=30), stamp(hour=11), list_name='Calendar Personal', priority='high')
    task('Calendar point', stamp(hour=12))
    task('Calendar three-day span', stamp(-1), stamp(1), all_day=True, list_name='Calendar Personal')
    task('Calendar daily series', stamp(hour=14), stamp(hour=14, minute=30), recurrence='daily')
    task('Calendar done', stamp(hour=16), stamp(hour=17), completedAt=stamp(hour=17))
    task('Calendar note', stamp(), all_day=True, kind='note')
    task('Calendar unscheduled')
    task('Calendar arrange second', list_name='Calendar Personal')
    task('Calendar archived hidden', stamp(hour=10), list_name='Calendar Archived')
    task('Calendar smart-excluded visible', stamp(hour=18), stamp(hour=19), list_name='Calendar Excluded')
    task('Calendar deleted hidden', stamp(hour=11), deletedAt=stamp())
    workspace = dict(tasks=tasks, lists=lists, tags=tags, folders=[], filters=[], templates=[])
    settings = dict(startWeekOn=2, dateRecognition=False, urlParsing=False, completionSound=False,
                    defaultReminder='none', allDayReminder='none', hasInstalledBuiltInTemplates=True,
                    calendarOptions=dict(mode='day', showSidebar=True))
    for name, data in [('workspace.json', workspace), ('settings.json', settings)]:
        path = root / name
        if path.exists():
            raise SystemExit(f'Refusing to overwrite existing QA fixture: {path}')
        path.write_text(json.dumps(data, indent=2) + '\n')
    print(root)


if __name__ == '__main__':
    main()
