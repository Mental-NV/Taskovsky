# MOB-SEARCH-001 Local Search on iPhone

The phone Search destination follows the [full-search scope](../spec/business.md#bus-023). It uses the same task matcher for titles, plain descriptions and embedded steps. Results also open lists, tags and saved filters. Distinct accessibility labels identify organization results with identical names.

Search Filters stages date, list, tag, type and status selections. Cancel keeps the previous criteria, while Done applies the draft. Default task scope excludes archives, opted-out lists and Trash. Explicit list selection can include archived or opted-out tasks. Result rows identify the list and indicate archived context. Opening task detail or following related tasks keeps the underlying search in place.

Recent queries are local to the iPhone. Opening a result or submitting the query remembers it, replaces any case-insensitive duplicate and keeps up to ten entries. Clear removes the history. Save as Filter opens the existing editor with the query and current criteria already filled in.

See the [verification record](../spec/verification.md#mobile-search) for native navigation, saved bytes, and the Mac reopen check. External search remains deferred.
