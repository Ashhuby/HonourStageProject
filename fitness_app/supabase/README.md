# Supabase

The app is offline-first: SQLite on the device is the source of truth, and
`lib/core/sync/sync_service.dart` pushes and pulls against the tables here.

Every payload in that file is written **column by column**, so the remote
schema and the local one have to be kept in step by hand — an unknown column
fails the whole upsert rather than being ignored.

## Applying a migration

There is no automated runner. Paste the file into the Supabase dashboard
(SQL Editor → New query → Run), or use the CLI if it is installed:

```bash
supabase db execute --file supabase/migrations/0001_split_schedule.sql
```

Every migration here is written to be safe to run twice.

## Files

| File | What it does |
|---|---|
| `migrations/0001_split_schedule.sql` | The remote half of local schema v13 — split rotations and the default split. **Required before the schedule can sync.** |
| `wipe_workout_data.sql` | Deletes every row of workout data. Destructive, and only half a reset — see the warning in the file. |

## The remote schema, as of local v13

Audited against every column the sync service reads or writes.

| Table | Notes |
|---|---|
| `workout_splits` | Missing `schedule_mode`, `cycle_length`, `is_default` until `0001` is applied |
| `workout_routines` | Missing `schedule_slots` until `0001` is applied |
| `routine_exercises` | Matches |
| `workout_sessions` | Matches |
| `workout_sets` | Matches |
| `personal_bests` | Matches |
| `exercises` | Matches. Holds **custom exercises only** — the seeded library is written locally on every install, which is why there is no `is_custom` column and the download hard-codes it |
| `badges` | Matches |
