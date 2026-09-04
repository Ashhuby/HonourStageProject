-- A fresh start: every row of workout data, gone.
--
-- DESTRUCTIVE AND IRREVERSIBLE. There is no soft delete here and no undo —
-- these are hard DELETEs, not the `deleted_at` stamps the app writes.
--
-- Accounts are deliberately left alone. Wiping auth.users would sign the
-- device out and orphan nothing useful; see the note at the bottom if that is
-- actually what you want.
--
-- ============================================================================
-- READ THIS BEFORE RUNNING
-- ============================================================================
--
-- Wiping the server is only half of a fresh start. The app is offline-first:
-- the device holds its own copy and pushes anything the server is missing on
-- the next sync, so a server-only wipe is undone within seconds of opening the
-- app. To actually start clean, do both:
--
--   1. Run this script.
--   2. Clear the app's local database on every device — uninstall and
--      reinstall, or clear app storage. On Android:
--        adb shell pm clear <application id>
--
-- Doing (1) without (2) restores the data you just deleted.
--
-- ============================================================================

begin;

-- Children first. The order is the foreign keys read backwards: sets belong to
-- sessions, sessions to routines, routines to splits.
delete from public.workout_sets;
delete from public.personal_bests;
delete from public.workout_sessions;
delete from public.routine_exercises;
delete from public.workout_routines;
delete from public.workout_splits;

-- Badges are per-user progress, not reference data — a fresh start that kept
-- them would open on a full trophy case.
delete from public.badges;

-- Only custom exercises live here. The seeded library ships with the app and
-- is written by a local migration on every install, so this removes what the
-- user created and nothing they depend on.
delete from public.exercises;

commit;

-- Confirm. Every count should be zero.
select 'workout_sets'      as table_name, count(*) from public.workout_sets
union all select 'workout_sessions',   count(*) from public.workout_sessions
union all select 'personal_bests',     count(*) from public.personal_bests
union all select 'routine_exercises',  count(*) from public.routine_exercises
union all select 'workout_routines',   count(*) from public.workout_routines
union all select 'workout_splits',     count(*) from public.workout_splits
union all select 'badges',             count(*) from public.badges
union all select 'exercises',          count(*) from public.exercises;

-- To remove the accounts as well, uncomment. This signs every device out and
-- cannot be undone either.
--   delete from auth.users;
