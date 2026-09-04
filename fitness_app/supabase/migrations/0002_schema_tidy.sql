-- Closing the gaps between the local schema and this one, and removing a
-- column that never meant anything.
--
-- Safe to re-run.
--
--   node tool/sql.mjs --file supabase/migrations/0002_schema_tidy.sql

-- ---------------------------------------------------------------------------
-- Routine targets for exercises that are not measured in reps
-- ---------------------------------------------------------------------------
--
-- A routine has been able to plan a run or a plank locally since the metric
-- types were added, but the sync payload had nowhere to put the numbers, so a
-- planned 5 km came back from the server as "3 sets of 10 reps" — the default
-- that means nothing for a run.

alter table public.routine_exercises
  add column if not exists target_distance_metres real;

alter table public.routine_exercises
  add column if not exists target_duration_seconds integer;

-- ---------------------------------------------------------------------------
-- workout_sets.is_completed
-- ---------------------------------------------------------------------------
--
-- Dead since it was introduced. Nothing ever set it: the app writes a set row
-- when the set is done, so the row's existence is the completion, and no query
-- anywhere filters on it. Every row in it was `false`, including the sets that
-- had plainly been completed — the column contradicted the data it sat beside.
--
-- Dropped rather than left alone because a boolean called `is_completed` that
-- is always false is worse than no column: it invites a future query to use
-- it, and that query would return nothing.

alter table public.workout_sets
  drop column if exists is_completed;

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------

select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'routine_exercises'
      and column_name in ('target_distance_metres', 'target_duration_seconds'))
    or (table_name = 'workout_sets' and column_name = 'is_completed')
  )
order by table_name, column_name;
