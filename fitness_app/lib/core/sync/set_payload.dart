/// The wire mapping for the fields that describe *how much* was done.
///
/// Kept as pure functions for the same reason as `exercise_muscle_payload.dart`:
/// the Supabase calls themselves are not testable here, but the mapping to and
/// from the wire is where the bugs live, and this part needs no network.
///
/// Everything below was simply absent from the payload before. A logged run
/// uploaded its `weight` (0) and `reps` (0) and dropped its distance and
/// duration on the floor, so a reinstall brought back every run and every
/// plank as a 0 kg × 0 rep set.
///
/// **Remote columns this requires** — additive and nullable, so a client that
/// predates them keeps working in both directions:
///
/// ```sql
/// alter table public.workout_sets
///   add column if not exists duration_seconds integer,
///   add column if not exists distance_metres  double precision;
///
/// alter table public.personal_bests
///   add column if not exists duration_seconds integer,
///   add column if not exists distance_metres  double precision,
///   add column if not exists metric_type      text;
/// ```
///
/// The `personal_bests` table also carries a **stale unique key**. The comment
/// in `SyncService` still describes `UNIQUE (user_id, exercise_id, reps)`,
/// which is the pre-v7 identity. Every distanceTime record has `reps = 0`, so
/// two legitimate records for one exercise collide the moment distance starts
/// uploading. It is masked today only because distance never leaves the
/// device. Replace it with the local v7 key:
///
/// ```sql
/// update public.personal_bests set metric_type     = 'weightReps' where metric_type is null;
/// update public.personal_bests set distance_metres = 0            where distance_metres is null;
///
/// -- confirm the real name first:
/// --   select conname from pg_constraint
/// --    where conrelid = 'public.personal_bests'::regclass and contype = 'u';
/// alter table public.personal_bests
///   drop constraint if exists personal_bests_user_id_exercise_id_reps_key;
///
/// create unique index if not exists personal_bests_identity
///   on public.personal_bests (user_id, exercise_id, metric_type, distance_metres);
/// ```
library;

/// The distance and duration half of a logged set's remote row.
Map<String, dynamic> setMetricColumns({
  int? durationSeconds,
  double? distanceMetres,
}) {
  return {
    'duration_seconds': durationSeconds,
    'distance_metres': distanceMetres,
  };
}

/// Reads them back. Both null for a row written before the columns existed,
/// which is exactly what a weight-and-reps set carries anyway.
({int? durationSeconds, double? distanceMetres}) setMetricsFromRemoteRow(
  Map<String, dynamic> row,
) {
  return (
    durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
    distanceMetres: (row['distance_metres'] as num?)?.toDouble(),
  );
}

/// A personal best's measurement half.
///
/// `metric_type` travels too. Without it every downloaded record landed on the
/// key `('weightReps', 0.0)`, collapsing a user's whole set of distance
/// records onto a single row.
Map<String, dynamic> personalBestMetricColumns({
  required String metricType,
  int? durationSeconds,
  required double distanceMetres,
}) {
  return {
    'metric_type': metricType,
    'duration_seconds': durationSeconds,
    'distance_metres': distanceMetres,
  };
}

/// Reads a record's measurements back, defaulting to what a pre-taxonomy
/// client meant when it wrote neither column.
({String metricType, int? durationSeconds, double distanceMetres})
personalBestMetricsFromRemoteRow(Map<String, dynamic> row) {
  return (
    metricType: (row['metric_type'] as String?) ?? 'weightReps',
    durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
    distanceMetres: (row['distance_metres'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Reads a weight column that the schema declares NOT NULL but a malformed row
/// might not carry.
///
/// The download used unguarded casts, so one bad row threw and took the rest
/// of the sync with it rather than costing a single set.
double weightFromRemoteRow(Map<String, dynamic> row) =>
    (row['weight'] as num?)?.toDouble() ?? 0.0;

/// As [weightFromRemoteRow], for reps.
int repsFromRemoteRow(Map<String, dynamic> row) =>
    (row['reps'] as num?)?.toInt() ?? 0;
