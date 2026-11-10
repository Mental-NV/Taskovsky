# TASK-SORT-001 — Task sorting by created and modified time

The task-list sort menu offers Created and Modified, each with Newest First and Oldest First. Created reads the record’s creation timestamp. Modified reads its last saved update. Equal timestamps retain the incoming order. Pins and history stay in their own groups and subtasks remain nested under their parent in each group.

On Mac, the old Created preference opens Created · Newest First. Timestamp sorts use one active group across due dates. Reminders and Trash keep their existing semantic groups. Timestamp sorting is a computed order, so manual reorder remains available through None. Other existing Mac sort choices remain available.

On iPhone, the Sort tasks control appears on Tasks lists. Default Order follows the existing stored sequence. Boards, Search and Summary keep their own presentation. The sort choice is device-local on both platforms and saves independently of workspace and Calendar settings files.

The [TickTick release notes](https://help.ticktick.com/articles/7082552170989486080) document Created and Modified and both directions. [Verification](../spec/verification.md#task-timestamp-sorting).
