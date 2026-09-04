-- Give a synced row a way to name the exercise it belongs to.
--
-- `exercise_id` on these three tables is an integer, and the integer is the
-- *device's* SQLite rowid. Every other reference in this schema is a uuid this
-- database issued; this one is a number that means something only on the
-- machine that wrote it.
--
-- It has worked so far by luck. The seeded library is written by a code-driven
-- migration in the same order on every install, so a seeded exercise happens to
-- land on the same rowid everywhere. Custom exercises get their ids after the
-- seed, in creation order, so two devices disagree the moment either of them
-- adds one — and a set logged against "Marwan's Curl" on the phone comes back
-- pointing at whatever the laptop happens to have at that number.
--
-- The fix is to record what the two devices can actually agree on:
--
--   exercise_remote_id  the uuid this database issued, for a custom exercise
--   exercise_name       the name, which is what identifies a seeded one —
--                       `idx_exercises_seed_name` makes it unique among them,
--                       and the seed is code, so it is the same everywhere
--
-- `exercise_id` stays for now. It is the only thing older rows carry, so it
-- remains the last resort when resolving, and dropping it would strand the
-- rows already up here. It can go once every row carries the new columns.
--
-- Safe to re-run.
--
--   node tool/sql.mjs --file supabase/migrations/0003_exercise_identity.sql

alter table public.workout_sets
  add column if not exists exercise_remote_id uuid,
  add column if not exists exercise_name text;

alter table public.routine_exercises
  add column if not exists exercise_remote_id uuid,
  add column if not exists exercise_name text;

alter table public.personal_bests
  add column if not exists exercise_remote_id uuid,
  add column if not exists exercise_name text;

-- Deliberately no foreign key on exercise_remote_id. Only custom exercises
-- have a row in `exercises`; a set against a seeded lift has no uuid to point
-- at, and a constraint here would reject the majority of honest rows.

select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and column_name in ('exercise_remote_id', 'exercise_name')
order by table_name, column_name;
