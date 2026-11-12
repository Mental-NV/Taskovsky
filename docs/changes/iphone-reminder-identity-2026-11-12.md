# iPhone reminder ownership record

Status: implemented persistence boundary only, before adapter/UI wiring. Extends the [phone proposal](iphone-local-notifications-2026-11-12.md). No notification authorization, registration, UI or existing settings changes.

A dedicated `PhoneReminderPreferences` actor owns one existing workspace directory for its lifetime. One actor per directory, single process, no concurrent external writers. Missing record means off; read and disable on a missing record create nothing. Only explicit `setEnabled(true)` may atomically create a version-1 record with a random UUID, app scope and enabled intent. Repeated enable/disable preserves UUID. The owner must acknowledge persistence before using intent for any future scheduling.

The UUID is not a credential. Request namespace is a SHA-256 digest of length-delimited app scope and UUID, never an absolute container path, task title or other user content. Moving a whole owned container preserves namespace; independent QA directories get independent identities. Copy/import of an active identity is out of scope and must not be treated as creating a new workspace.

Reject invalid JSON, duplicate or unknown keys, unknown versions, invalid UUID/Boolean/app scope, missing/unavailable directory, and record symlinks/nonregular files. Preserve bytes on refusal. An absent directory is not permission to create a workspace. Use the same atomic and iOS file protection options as workspace files. Do not cache optimistic intent: read back exact intended bytes before acknowledging a write; a writer that throws after committing those exact bytes is acknowledged, otherwise fail. Retrying reads actual disk state and does not silently replace malformed identity. No cross-process lock or adversarial filesystem race protection is claimed.

Tests use owned temporary directories and injected writes only: absence, first/repeated/concurrent enable, disable, relocation, separate containers/app scope, corrupt/duplicate/unknown data, failure before and after commit, dishonest no-op writer, unavailable directory and symlink refusal. Real iPhone notification permissions and delivery remain unimplemented/unverified.
