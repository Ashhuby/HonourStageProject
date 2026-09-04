-- Split scheduling — the remote half of local schema v13.
--
-- The app gained a rotation per split: weekly, or a cycle of any length, with
-- each routine recording which slots of it it occupies. Those four columns
-- exist locally already; until they exist here too the sync payloads cannot
-- carry them, because every payload in sync_service.dart is written column by
-- column and an unknown column fails the whole upsert.
--
-- Safe to re-run: every statement is IF NOT EXISTS.
--
-- Run in the Supabase dashboard under SQL Editor, or with the CLI:
--   supabase db execute --file supabase/migrations/0001_split_schedule.sql

-- How the split repeats: 'none', 'weekly' or 'cycle'.
--
-- Text rather than an enum so a client running a newer catalogue of modes
-- cannot fail to insert. The app parses it through ScheduleMode.byNameOrNone,
-- which treats anything it does not recognise as unscheduled.
alter table public.workout_splits
  add column if not exists schedule_mode text not null default 'none';

-- How many slots the rotation has. Seven for weekly, where slot 0 is Monday.
alter table public.workout_splits
  add column if not exists cycle_length integer not null default 7;

-- The split the Splits tab opens on. At most one per user, which the app
-- enforces in a transaction; the index below makes it true at the schema level
-- rather than merely usual.
alter table public.workout_splits
  add column if not exists is_default boolean not null default false;

-- Which slots of the rotation a routine occupies, as a comma-separated list of
-- positions — '0,3' is Monday and Thursday on a weekly split. A list because a
-- six-day push/pull/legs trains Push twice a week.
alter table public.workout_routines
  add column if not exists schedule_slots text;

-- One default per user.
--
-- Partial, so the rows that are not default do not compete for it — without
-- the WHERE clause every user could have only one non-default split, which is
-- the opposite of the intent.
create unique index if not exists workout_splits_one_default_per_user
  on public.workout_splits (user_id)
  where is_default and deleted_at is null;

-- A cycle short enough to be a rotation and long enough to be one.
-- Mirrors the clamp in SplitScheduleRepository.setScheduleMode.
do $$
begin
  alter table public.workout_splits
    add constraint workout_splits_cycle_length_sane
    check (cycle_length between 2 and 14);
exception
  when duplicate_object then null;
end $$;
