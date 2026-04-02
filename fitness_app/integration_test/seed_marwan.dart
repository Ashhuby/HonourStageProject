// integration_test/seed_marwan.dart
//
// flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/seed_marwan.dart \
//   --dart-define=SUPABASE_URL=YOUR_URL \
//   --dart-define=SUPABASE_ANON_KEY=YOUR_KEY

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_app/core/database/local_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  });

  testWidgets('Seed marwan@proton.com showcase account', (tester) async {
    final client = Supabase.instance.client;

    await client.auth.signInWithPassword(
      email: 'marwan@proton.com',
      password: 'password123',
    );
    debugPrint('Signed in as marwan@proton.com');

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedExercises(db);
    await _seedBadgeRows(db);

    final ex = {for (final e in await db.select(db.exercises).get()) e.name: e};

    await _seedMarwan(db, ex);
    await _syncToSupabase(db, client);

    await db.close();
    await client.auth.signOut();
    debugPrint('Done.');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

// ---------------------------------------------------------------------------
// Seed badge rows (unearned) so we can award them
// ---------------------------------------------------------------------------
Future<void> _seedBadgeRows(AppDatabase db) async {
  const keys = [
    'first_workout', 'streak_7_day', 'streak_30_day',
    'first_pr', 'pr_10', 'sets_50', 'sets_500', 'first_custom_exercise',
  ];
  for (final key in keys) {
    await db.into(db.badges).insert(
      BadgesCompanion.insert(badgeKey: key),
      onConflict: DoUpdate((_) => BadgesCompanion.insert(badgeKey: key),
          target: [db.badges.badgeKey]),
    );
  }
}

// ---------------------------------------------------------------------------
// Award a badge at a specific time
// ---------------------------------------------------------------------------
Future<void> _awardBadge(AppDatabase db, String key, DateTime when) async {
  await (db.update(db.badges)..where((b) => b.badgeKey.equals(key)))
      .write(BadgesCompanion(earnedAt: Value(when), syncedAt: const Value(null)));
}

// ---------------------------------------------------------------------------
// Upsert a PR into personal_bests
// ---------------------------------------------------------------------------
Future<void> _savePr(AppDatabase db, int exerciseId, {
  double weight = 0.0,
  int reps = 0,
  int? durationSeconds,
  double? distanceMetres,
  required String metricType,
  required DateTime achievedAt,
}) async {
  await db.into(db.personalBests).insert(
    PersonalBestsCompanion.insert(
      exerciseId: exerciseId,
      reps: Value(reps),
      weight: Value(weight),
      durationSeconds: Value(durationSeconds),
      distanceMetres: Value(distanceMetres),
      metricType: Value(metricType),
      achievedAt: achievedAt,
    ),
    onConflict: DoUpdate(
      (old) => PersonalBestsCompanion.custom(
        weight: Variable(weight),
        durationSeconds: Variable(durationSeconds),
        distanceMetres: Variable(distanceMetres),
        achievedAt: Variable(achievedAt),
      ),
      target: [db.personalBests.exerciseId, db.personalBests.reps],
    ),
  );
}

// ---------------------------------------------------------------------------
// Main seeder
// ---------------------------------------------------------------------------
Future<void> _seedMarwan(AppDatabase db, Map<String, Exercise> ex) async {

  // ---- Create splits ----
  final pplId = await _split(db, 'PPL Split');
  final pushId = await _routine(db, pplId, 'Push', 0);
  final pullId = await _routine(db, pplId, 'Pull', 1);
  final legsId = await _routine(db, pplId, 'Legs', 2);

  final cardioId = await _split(db, 'Cardio & HIIT');
  final hiitId  = await _routine(db, cardioId, 'HIIT', 0);
  final runId   = await _routine(db, cardioId, 'Running', 1);

  // ---- Link exercises to routines ----
  // Push
  await _linkEx(db, pushId, ex['Bench Press']!.id, 0, 4, 5);
  await _linkEx(db, pushId, ex['Overhead Press']!.id, 1, 3, 8);
  await _linkEx(db, pushId, ex['Incline Bench Press']!.id, 2, 3, 8);
  await _linkEx(db, pushId, ex['Tricep Pushdown']!.id, 3, 3, 12);
  await _linkEx(db, pushId, ex['Lateral Raise']!.id, 4, 3, 15);
  // Pull
  await _linkEx(db, pullId, ex['Deadlift']!.id, 0, 3, 5);
  await _linkEx(db, pullId, ex['Barbell Row']!.id, 1, 3, 8);
  await _linkEx(db, pullId, ex['Lat Pulldown']!.id, 2, 3, 10);
  await _linkEx(db, pullId, ex['Barbell Curl']!.id, 3, 3, 10);
  await _linkEx(db, pullId, ex['Face Pull']!.id, 4, 3, 15);
  // Legs
  await _linkEx(db, legsId, ex['Squat']!.id, 0, 4, 5);
  await _linkEx(db, legsId, ex['Romanian Deadlift']!.id, 1, 3, 8);
  await _linkEx(db, legsId, ex['Leg Press']!.id, 2, 3, 12);
  await _linkEx(db, legsId, ex['Leg Curl']!.id, 3, 3, 12);
  await _linkEx(db, legsId, ex['Calf Raise']!.id, 4, 3, 15);
  // HIIT
  await _linkEx(db, hiitId, ex['Plank']!.id, 0, 3, 1);
  await _linkEx(db, hiitId, ex['Rowing Machine']!.id, 1, 2, 1);
  // Running
  await _linkEx(db, runId, ex['Running']!.id, 0, 1, 1);

  // ========================================================================
  // WEEK 1 — 21–27 Mar
  // ========================================================================

  // Mon 21: Push (first ever session → first_workout badge)
  {
    final s = await _session(db, DateTime(2026,3,21,7,30), DateTime(2026,3,21,9,0), routineId: pushId);
    await _wsets(db, s, ex['Bench Press']!.id,       [(70.0,5),(70.0,5),(72.5,5),(72.5,4)]);
    await _wsets(db, s, ex['Overhead Press']!.id,    [(45.0,8),(45.0,7),(47.5,6)]);
    await _wsets(db, s, ex['Incline Bench Press']!.id, [(55.0,8),(55.0,8),(57.5,7)]);
    await _wsets(db, s, ex['Tricep Pushdown']!.id,   [(27.5,12),(27.5,11),(30.0,10)]);
    await _wsets(db, s, ex['Lateral Raise']!.id,     [(10.0,15),(10.0,14),(12.0,12)]);
    // First session PRs
    await _savePr(db, ex['Bench Press']!.id, weight: 72.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,7,45));
    await _savePr(db, ex['Bench Press']!.id, weight: 70.0, reps: 4, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,7,40));
    await _savePr(db, ex['Overhead Press']!.id, weight: 47.5, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,8,5));
    await _savePr(db, ex['Incline Bench Press']!.id, weight: 57.5, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,8,20));
    await _savePr(db, ex['Tricep Pushdown']!.id, weight: 30.0, reps: 10, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,8,35));
    await _savePr(db, ex['Lateral Raise']!.id, weight: 12.0, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,3,21,8,45));
    await _awardBadge(db, 'first_workout', DateTime(2026,3,21,9,0));
    await _awardBadge(db, 'first_pr', DateTime(2026,3,21,9,0));
  }

  // Tue 22: Pull
  {
    final s = await _session(db, DateTime(2026,3,22,7,30), DateTime(2026,3,22,8,55), routineId: pullId);
    await _wsets(db, s, ex['Deadlift']!.id,     [(100.0,5),(102.5,5),(105.0,4)]);
    await _wsets(db, s, ex['Barbell Row']!.id,  [(60.0,8),(62.5,8),(62.5,7)]);
    await _wsets(db, s, ex['Lat Pulldown']!.id, [(50.0,10),(52.5,9),(52.5,8)]);
    await _wsets(db, s, ex['Barbell Curl']!.id, [(30.0,10),(30.0,9),(32.5,8)]);
    await _wsets(db, s, ex['Face Pull']!.id,    [(20.0,15),(20.0,14),(22.5,12)]);
    await _savePr(db, ex['Deadlift']!.id, weight: 105.0, reps: 4, metricType: 'weightReps', achievedAt: DateTime(2026,3,22,7,45));
    await _savePr(db, ex['Barbell Row']!.id, weight: 62.5, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,3,22,8,0));
    await _savePr(db, ex['Lat Pulldown']!.id, weight: 52.5, reps: 8, metricType: 'weightReps', achievedAt: DateTime(2026,3,22,8,15));
    await _savePr(db, ex['Barbell Curl']!.id, weight: 32.5, reps: 8, metricType: 'weightReps', achievedAt: DateTime(2026,3,22,8,25));
    await _savePr(db, ex['Face Pull']!.id, weight: 22.5, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,3,22,8,35));
  }

  // Wed 23: HIIT
  {
    final s = await _session(db, DateTime(2026,3,23,18,0), DateTime(2026,3,23,18,45), routineId: hiitId);
    await _timed(db, s, ex['Plank']!.id, 45);
    await _timed(db, s, ex['Plank']!.id, 40);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 480);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 472);
    await _savePr(db, ex['Plank']!.id, durationSeconds: 45, metricType: 'timeOnly', achievedAt: DateTime(2026,3,23,18,10));
    await _savePr(db, ex['Rowing Machine']!.id, durationSeconds: 472, distanceMetres: 2000, metricType: 'distanceTime', achievedAt: DateTime(2026,3,23,18,30));
  }

  // Fri 25: Legs
  {
    final s = await _session(db, DateTime(2026,3,25,7,30), DateTime(2026,3,25,9,0), routineId: legsId);
    await _wsets(db, s, ex['Squat']!.id,             [(90.0,5),(92.5,5),(92.5,4),(95.0,3)]);
    await _wsets(db, s, ex['Romanian Deadlift']!.id, [(70.0,8),(72.5,8),(72.5,7)]);
    await _wsets(db, s, ex['Leg Press']!.id,         [(120.0,12),(130.0,10),(130.0,10)]);
    await _wsets(db, s, ex['Leg Curl']!.id,          [(35.0,12),(37.5,11),(37.5,10)]);
    await _wsets(db, s, ex['Calf Raise']!.id,        [(50.0,15),(50.0,15),(55.0,12)]);
    await _savePr(db, ex['Squat']!.id, weight: 95.0, reps: 3, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,8,0));
    await _savePr(db, ex['Squat']!.id, weight: 92.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,7,50));
    await _savePr(db, ex['Romanian Deadlift']!.id, weight: 72.5, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,8,15));
    await _savePr(db, ex['Leg Press']!.id, weight: 130.0, reps: 10, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,8,30));
    await _savePr(db, ex['Leg Curl']!.id, weight: 37.5, reps: 10, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,8,40));
    await _savePr(db, ex['Calf Raise']!.id, weight: 55.0, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,3,25,8,50));
  }

  // Sat 26: Run
  {
    final s = await _session(db, DateTime(2026,3,26,8,0), DateTime(2026,3,26,8,35), routineId: runId);
    await _cardio(db, s, ex['Running']!.id, 5000, 1740);
    await _savePr(db, ex['Running']!.id, durationSeconds: 1740, distanceMetres: 5000, metricType: 'distanceTime', achievedAt: DateTime(2026,3,26,8,29));
  }

  // sets_50 badge after week 1 (we have ~55 sets by now)
  await _awardBadge(db, 'sets_50', DateTime(2026,3,26,8,35));

  // ========================================================================
  // WEEK 2 — 28 Mar – 3 Apr
  // ========================================================================

  // Mon 28: Push — overload
  {
    final s = await _session(db, DateTime(2026,3,28,7,30), DateTime(2026,3,28,9,0), routineId: pushId);
    await _wsets(db, s, ex['Bench Press']!.id,       [(72.5,5),(72.5,5),(75.0,5),(75.0,4)]);
    await _wsets(db, s, ex['Overhead Press']!.id,    [(47.5,8),(47.5,7),(50.0,6)]);
    await _wsets(db, s, ex['Incline Bench Press']!.id, [(57.5,8),(57.5,8),(60.0,6)]);
    await _wsets(db, s, ex['Tricep Pushdown']!.id,   [(30.0,12),(30.0,11),(32.5,10)]);
    await _wsets(db, s, ex['Lateral Raise']!.id,     [(12.0,15),(12.0,13),(12.0,12)]);
    await _savePr(db, ex['Bench Press']!.id, weight: 75.0, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,3,28,7,55));
    await _savePr(db, ex['Bench Press']!.id, weight: 75.0, reps: 4, metricType: 'weightReps', achievedAt: DateTime(2026,3,28,8,0));
    await _savePr(db, ex['Overhead Press']!.id, weight: 50.0, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,3,28,8,15));
    await _savePr(db, ex['Incline Bench Press']!.id, weight: 60.0, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,3,28,8,25));
    await _savePr(db, ex['Tricep Pushdown']!.id, weight: 32.5, reps: 10, metricType: 'weightReps', achievedAt: DateTime(2026,3,28,8,35));
  }

  // Mon 30: Pull
  {
    final s = await _session(db, DateTime(2026,3,30,7,30), DateTime(2026,3,30,8,55), routineId: pullId);
    await _wsets(db, s, ex['Deadlift']!.id,     [(105.0,5),(107.5,5),(107.5,4)]);
    await _wsets(db, s, ex['Barbell Row']!.id,  [(62.5,8),(62.5,8),(65.0,6)]);
    await _wsets(db, s, ex['Lat Pulldown']!.id, [(52.5,10),(55.0,9),(55.0,8)]);
    await _wsets(db, s, ex['Barbell Curl']!.id, [(32.5,10),(32.5,9),(35.0,7)]);
    await _wsets(db, s, ex['Face Pull']!.id,    [(22.5,15),(22.5,14),(25.0,12)]);
    await _savePr(db, ex['Deadlift']!.id, weight: 107.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,3,30,7,50));
    await _savePr(db, ex['Barbell Row']!.id, weight: 65.0, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,3,30,8,5));
    await _savePr(db, ex['Lat Pulldown']!.id, weight: 55.0, reps: 8, metricType: 'weightReps', achievedAt: DateTime(2026,3,30,8,20));
    await _savePr(db, ex['Barbell Curl']!.id, weight: 35.0, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,3,30,8,30));
    await _savePr(db, ex['Face Pull']!.id, weight: 25.0, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,3,30,8,40));
  }

  // Tue 31: HIIT — plank PR
  {
    final s = await _session(db, DateTime(2026,3,31,18,0), DateTime(2026,3,31,18,45), routineId: hiitId);
    await _timed(db, s, ex['Plank']!.id, 55);
    await _timed(db, s, ex['Plank']!.id, 50);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 465);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 470);
    await _savePr(db, ex['Plank']!.id, durationSeconds: 55, metricType: 'timeOnly', achievedAt: DateTime(2026,3,31,18,12));
    await _savePr(db, ex['Rowing Machine']!.id, durationSeconds: 465, distanceMetres: 2000, metricType: 'distanceTime', achievedAt: DateTime(2026,3,31,18,30));
  }

  // Thu 1 Apr: Legs
  {
    final s = await _session(db, DateTime(2026,4,1,7,30), DateTime(2026,4,1,9,0), routineId: legsId);
    await _wsets(db, s, ex['Squat']!.id,             [(95.0,5),(97.5,5),(97.5,4),(100.0,3)]);
    await _wsets(db, s, ex['Romanian Deadlift']!.id, [(72.5,8),(75.0,8),(75.0,6)]);
    await _wsets(db, s, ex['Leg Press']!.id,         [(130.0,12),(140.0,10),(140.0,9)]);
    await _wsets(db, s, ex['Leg Curl']!.id,          [(37.5,12),(37.5,11),(40.0,9)]);
    await _wsets(db, s, ex['Calf Raise']!.id,        [(55.0,15),(55.0,14),(60.0,12)]);
    await _savePr(db, ex['Squat']!.id, weight: 100.0, reps: 3, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,8,0));
    await _savePr(db, ex['Squat']!.id, weight: 97.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,7,50));
    await _savePr(db, ex['Romanian Deadlift']!.id, weight: 75.0, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,8,15));
    await _savePr(db, ex['Leg Press']!.id, weight: 140.0, reps: 9, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,8,30));
    await _savePr(db, ex['Leg Curl']!.id, weight: 40.0, reps: 9, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,8,40));
    await _savePr(db, ex['Calf Raise']!.id, weight: 60.0, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,4,1,8,50));
  }

  // Thu 2 Apr: Run — faster 5k
  {
    final s = await _session(db, DateTime(2026,4,2,8,0), DateTime(2026,4,2,8,33), routineId: runId);
    await _cardio(db, s, ex['Running']!.id, 5000, 1695);
    await _savePr(db, ex['Running']!.id, durationSeconds: 1695, distanceMetres: 5000, metricType: 'distanceTime', achievedAt: DateTime(2026,4,2,8,28));
  }

  // pr_10 badge — 10+ PRs by end of week 2
  await _awardBadge(db, 'pr_10', DateTime(2026,4,2,8,33));

  // ========================================================================
  // WEEK 3 — 4–12 Apr
  // ========================================================================

  // Mon 4: Push — bench PR
  {
    final s = await _session(db, DateTime(2026,4,4,7,30), DateTime(2026,4,4,9,5), routineId: pushId);
    await _wsets(db, s, ex['Bench Press']!.id,       [(75.0,5),(77.5,5),(77.5,5),(80.0,3)]);
    await _wsets(db, s, ex['Overhead Press']!.id,    [(50.0,8),(50.0,7),(52.5,5)]);
    await _wsets(db, s, ex['Incline Bench Press']!.id, [(60.0,8),(60.0,7),(62.5,6)]);
    await _wsets(db, s, ex['Tricep Pushdown']!.id,   [(32.5,12),(32.5,10),(35.0,9)]);
    await _wsets(db, s, ex['Lateral Raise']!.id,     [(12.0,15),(14.0,12),(14.0,11)]);
    await _savePr(db, ex['Bench Press']!.id, weight: 80.0, reps: 3, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,7,58));
    await _savePr(db, ex['Bench Press']!.id, weight: 77.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,7,50));
    await _savePr(db, ex['Overhead Press']!.id, weight: 52.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,8,15));
    await _savePr(db, ex['Incline Bench Press']!.id, weight: 62.5, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,8,25));
    await _savePr(db, ex['Tricep Pushdown']!.id, weight: 35.0, reps: 9, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,8,40));
    await _savePr(db, ex['Lateral Raise']!.id, weight: 14.0, reps: 12, metricType: 'weightReps', achievedAt: DateTime(2026,4,4,8,48));
  }

  // Sun 5: HIIT — best plank
  {
    final s = await _session(db, DateTime(2026,4,5,18,0), DateTime(2026,4,5,18,45), routineId: hiitId);
    await _timed(db, s, ex['Plank']!.id, 65);
    await _timed(db, s, ex['Plank']!.id, 58);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 458);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 462);
    await _savePr(db, ex['Plank']!.id, durationSeconds: 65, metricType: 'timeOnly', achievedAt: DateTime(2026,4,5,18,12));
    await _savePr(db, ex['Rowing Machine']!.id, durationSeconds: 458, distanceMetres: 2000, metricType: 'distanceTime', achievedAt: DateTime(2026,4,5,18,32));
  }

  // Mon 6: Pull — deadlift PR
  {
    final s = await _session(db, DateTime(2026,4,6,7,30), DateTime(2026,4,6,8,55), routineId: pullId);
    await _wsets(db, s, ex['Deadlift']!.id,     [(107.5,5),(110.0,5),(112.5,3)]);
    await _wsets(db, s, ex['Barbell Row']!.id,  [(65.0,8),(65.0,7),(67.5,6)]);
    await _wsets(db, s, ex['Lat Pulldown']!.id, [(55.0,10),(57.5,9),(57.5,7)]);
    await _wsets(db, s, ex['Barbell Curl']!.id, [(35.0,10),(35.0,8),(37.5,7)]);
    await _wsets(db, s, ex['Face Pull']!.id,    [(25.0,15),(25.0,13),(27.5,11)]);
    await _savePr(db, ex['Deadlift']!.id, weight: 112.5, reps: 3, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,7,52));
    await _savePr(db, ex['Deadlift']!.id, weight: 110.0, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,7,45));
    await _savePr(db, ex['Barbell Row']!.id, weight: 67.5, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,8,5));
    await _savePr(db, ex['Lat Pulldown']!.id, weight: 57.5, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,8,20));
    await _savePr(db, ex['Barbell Curl']!.id, weight: 37.5, reps: 7, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,8,30));
    await _savePr(db, ex['Face Pull']!.id, weight: 27.5, reps: 11, metricType: 'weightReps', achievedAt: DateTime(2026,4,6,8,42));
  }

  // Wed 8: Legs — squat PR
  {
    final s = await _session(db, DateTime(2026,4,8,7,30), DateTime(2026,4,8,9,5), routineId: legsId);
    await _wsets(db, s, ex['Squat']!.id,             [(100.0,5),(102.5,5),(102.5,4),(105.0,2)]);
    await _wsets(db, s, ex['Romanian Deadlift']!.id, [(75.0,8),(77.5,7),(77.5,6)]);
    await _wsets(db, s, ex['Leg Press']!.id,         [(140.0,12),(150.0,10),(150.0,9)]);
    await _wsets(db, s, ex['Leg Curl']!.id,          [(40.0,12),(40.0,10),(42.5,9)]);
    await _wsets(db, s, ex['Calf Raise']!.id,        [(60.0,15),(60.0,13),(65.0,11)]);
    await _savePr(db, ex['Squat']!.id, weight: 105.0, reps: 2, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,8,2));
    await _savePr(db, ex['Squat']!.id, weight: 102.5, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,7,52));
    await _savePr(db, ex['Romanian Deadlift']!.id, weight: 77.5, reps: 6, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,8,18));
    await _savePr(db, ex['Leg Press']!.id, weight: 150.0, reps: 9, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,8,32));
    await _savePr(db, ex['Leg Curl']!.id, weight: 42.5, reps: 9, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,8,42));
    await _savePr(db, ex['Calf Raise']!.id, weight: 65.0, reps: 11, metricType: 'weightReps', achievedAt: DateTime(2026,4,8,8,52));
  }

  // Thu 9: Run — fastest 5k
  {
    final s = await _session(db, DateTime(2026,4,9,8,0), DateTime(2026,4,9,8,31), routineId: runId);
    await _cardio(db, s, ex['Running']!.id, 5000, 1650);
    await _savePr(db, ex['Running']!.id, durationSeconds: 1650, distanceMetres: 5000, metricType: 'distanceTime', achievedAt: DateTime(2026,4,9,8,28));
  }

  // Mon 11: Push
  {
    final s = await _session(db, DateTime(2026,4,11,7,30), DateTime(2026,4,11,9,0), routineId: pushId);
    await _wsets(db, s, ex['Bench Press']!.id,       [(77.5,5),(80.0,5),(80.0,4),(82.5,2)]);
    await _wsets(db, s, ex['Overhead Press']!.id,    [(52.5,7),(52.5,6),(55.0,5)]);
    await _wsets(db, s, ex['Incline Bench Press']!.id, [(62.5,7),(62.5,7),(65.0,5)]);
    await _wsets(db, s, ex['Tricep Pushdown']!.id,   [(35.0,11),(35.0,10),(37.5,8)]);
    await _wsets(db, s, ex['Lateral Raise']!.id,     [(14.0,13),(14.0,12),(14.0,11)]);
    await _savePr(db, ex['Bench Press']!.id, weight: 82.5, reps: 2, metricType: 'weightReps', achievedAt: DateTime(2026,4,11,8,0));
    await _savePr(db, ex['Bench Press']!.id, weight: 80.0, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,11,7,52));
    await _savePr(db, ex['Overhead Press']!.id, weight: 55.0, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,11,8,15));
    await _savePr(db, ex['Incline Bench Press']!.id, weight: 65.0, reps: 5, metricType: 'weightReps', achievedAt: DateTime(2026,4,11,8,28));
    await _savePr(db, ex['Tricep Pushdown']!.id, weight: 37.5, reps: 8, metricType: 'weightReps', achievedAt: DateTime(2026,4,11,8,40));
  }

  // Tue 12: HIIT — final session
  {
    final s = await _session(db, DateTime(2026,4,12,18,0), DateTime(2026,4,12,18,45), routineId: hiitId);
    await _timed(db, s, ex['Plank']!.id, 72);
    await _timed(db, s, ex['Plank']!.id, 65);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 451);
    await _cardio(db, s, ex['Rowing Machine']!.id, 2000, 458);
    await _savePr(db, ex['Plank']!.id, durationSeconds: 72, metricType: 'timeOnly', achievedAt: DateTime(2026,4,12,18,12));
    await _savePr(db, ex['Rowing Machine']!.id, durationSeconds: 451, distanceMetres: 2000, metricType: 'distanceTime', achievedAt: DateTime(2026,4,12,18,32));
  }

  debugPrint('All sessions and PRs created');
}

// ---------------------------------------------------------------------------
// Sync everything to Supabase
// ---------------------------------------------------------------------------
Future<void> _syncToSupabase(AppDatabase db, SupabaseClient client) async {
  final userId = client.auth.currentUser!.id;
  int sessionCount = 0, setCount = 0, pbCount = 0;

  // Splits
  final splits = await db.select(db.workoutSplits).get();
  for (final s in splits) {
    final rid = _uid();
    await client.from('workout_splits').upsert({'id': rid, 'user_id': userId, 'name': s.name, 'created_at': s.createdAt.toIso8601String()});
    await (db.update(db.workoutSplits)..where((r) => r.id.equals(s.id))).write(WorkoutSplitsCompanion(remoteId: Value(rid), userId: Value(userId), syncedAt: Value(DateTime.now())));
  }

  // Routines
  final routines = await db.select(db.workoutRoutines).get();
  for (final r in routines) {
    final split = await (db.select(db.workoutSplits)..where((s) => s.id.equals(r.splitId))).getSingleOrNull();
    if (split?.remoteId == null) continue;
    final rid = _uid();
    await client.from('workout_routines').upsert({'id': rid, 'user_id': userId, 'split_id': split!.remoteId, 'name': r.name, 'order_index': r.orderIndex});
    await (db.update(db.workoutRoutines)..where((ro) => ro.id.equals(r.id))).write(WorkoutRoutinesCompanion(remoteId: Value(rid), userId: Value(userId), syncedAt: Value(DateTime.now())));
  }

  // Routine exercises
  final routineExercises = await db.select(db.routineExercises).get();
  for (final re in routineExercises) {
    final routine = await (db.select(db.workoutRoutines)..where((r) => r.id.equals(re.routineId))).getSingleOrNull();
    if (routine?.remoteId == null) continue;
    await client.from('routine_exercises').upsert({
      'id': _uid(), 'user_id': userId, 'routine_id': routine!.remoteId,
      'exercise_id': re.exerciseId, 'order_index': re.orderIndex,
      'target_sets': re.targetSets, 'target_reps': re.targetReps,
    });
  }

  // Sessions
  final sessions = await db.select(db.workoutSessions).get();
  for (final s in sessions) {
    WorkoutRoutine? routine;
    if (s.routineId != null) {
      routine = await (db.select(db.workoutRoutines)..where((r) => r.id.equals(s.routineId!))).getSingleOrNull();
    }
    final rid = _uid();
    await client.from('workout_sessions').upsert({'id': rid, 'user_id': userId, 'routine_id': routine?.remoteId, 'start_time': s.startTime.toIso8601String(), 'end_time': s.endTime?.toIso8601String()});
    await (db.update(db.workoutSessions)..where((se) => se.id.equals(s.id))).write(WorkoutSessionsCompanion(remoteId: Value(rid), userId: Value(userId), syncedAt: Value(DateTime.now())));
    sessionCount++;
  }

  // Sets
  final sets = await db.select(db.workoutSets).get();
  for (final s in sets) {
    final session = await (db.select(db.workoutSessions)..where((se) => se.id.equals(s.sessionId))).getSingleOrNull();
    if (session?.remoteId == null) continue;
    await client.from('workout_sets').upsert({
      'id': _uid(), 'user_id': userId, 'session_id': session!.remoteId,
      'exercise_id': s.exerciseId, 'weight': s.weight, 'reps': s.reps,
      'duration_seconds': s.durationSeconds, 'distance_metres': s.distanceMetres,
      'is_completed': s.isCompleted, 'timestamp': s.timestamp.toIso8601String(),
    });
    setCount++;
  }

  // Personal bests
  final pbs = await db.select(db.personalBests).get();
  for (final pb in pbs) {
    await client.from('personal_bests').upsert({
      'id': _uid(), 'user_id': userId, 'exercise_id': pb.exerciseId,
      'reps': pb.reps, 'weight': pb.weight,
      'duration_seconds': pb.durationSeconds, 'distance_metres': pb.distanceMetres,
      'metric_type': pb.metricType, 'achieved_at': pb.achievedAt.toIso8601String(),
    });
    pbCount++;
  }

  // Badges
  final badges = await (db.select(db.badges)..where((b) => b.earnedAt.isNotNull())).get();
  for (final b in badges) {
    await client.from('badges').upsert({
      'id': _uid(), 'user_id': userId, 'badge_key': b.badgeKey,
      'earned_at': b.earnedAt!.toIso8601String(),
    });
  }

  debugPrint('Synced: $sessionCount sessions, $setCount sets, $pbCount PRs, ${badges.length} badges');
}

// ---------------------------------------------------------------------------
// Exercise seeder
// ---------------------------------------------------------------------------
Future<void> _seedExercises(AppDatabase db) async {
  Future<void> s(String name, String bp, String eq, String mt) async {
    await db.into(db.exercises).insertOnConflictUpdate(ExercisesCompanion.insert(
      name: name, bodyPart: bp, equipmentType: eq, metricType: Value(mt),
    ));
  }
  await s('Bench Press',        'Chest',      'Barbell',    'weightReps');
  await s('Incline Bench Press','Chest',      'Barbell',    'weightReps');
  await s('Overhead Press',     'Shoulders',  'Barbell',    'weightReps');
  await s('Tricep Pushdown',    'Triceps',    'Cable',      'weightReps');
  await s('Lateral Raise',      'Shoulders',  'Dumbbell',   'weightReps');
  await s('Deadlift',           'Back',       'Barbell',    'weightReps');
  await s('Barbell Row',        'Back',       'Barbell',    'weightReps');
  await s('Lat Pulldown',       'Back',       'Cable',      'weightReps');
  await s('Barbell Curl',       'Biceps',     'Barbell',    'weightReps');
  await s('Face Pull',          'Shoulders',  'Cable',      'weightReps');
  await s('Squat',              'Legs',       'Barbell',    'weightReps');
  await s('Romanian Deadlift',  'Legs',       'Barbell',    'weightReps');
  await s('Leg Press',          'Legs',       'Machine',    'weightReps');
  await s('Leg Curl',           'Legs',       'Machine',    'weightReps');
  await s('Calf Raise',         'Legs',       'Machine',    'weightReps');
  await s('Plank',              'Core',       'Body Weight','timeOnly');
  await s('Rowing Machine',     'Whole Body', 'Machine',    'distanceTime');
  await s('Running',            'Whole Body', 'Body Weight','distanceTime');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
int _uidCounter = 0;
String _uid() {
  _uidCounter++;
  final t = DateTime.now().microsecondsSinceEpoch + _uidCounter;
  final h = t.toRadixString(16).padLeft(16, '0');
  return '${h.substring(0,8)}-${h.substring(8,12)}-4${h.substring(12,15)}-8${h.substring(0,3)}-${h.substring(3,15)}';
}

Future<int> _split(AppDatabase db, String name) =>
    db.into(db.workoutSplits).insert(WorkoutSplitsCompanion.insert(name: name));

Future<int> _routine(AppDatabase db, int splitId, String name, int order) =>
    db.into(db.workoutRoutines).insert(WorkoutRoutinesCompanion.insert(splitId: splitId, name: name, orderIndex: order));

Future<void> _linkEx(AppDatabase db, int routineId, int exerciseId, int order, int sets, int reps) =>
    db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
      routineId: routineId, exerciseId: exerciseId, orderIndex: order,
      targetSets: Value(sets), targetReps: Value(reps),
    ));

Future<int> _session(AppDatabase db, DateTime start, DateTime end, {int? routineId}) =>
    db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
      startTime: start, endTime: Value(end), routineId: Value(routineId)));

Future<void> _wsets(AppDatabase db, int sessionId, int exerciseId, List<(double, int)> sets) async {
  for (final s in sets) {
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
      sessionId: sessionId, exerciseId: exerciseId,
      weight: Value(s.$1), reps: Value(s.$2),
    ));
  }
}

Future<void> _timed(AppDatabase db, int sessionId, int exerciseId, int secs) =>
    db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
      sessionId: sessionId, exerciseId: exerciseId, durationSeconds: Value(secs)));

Future<void> _cardio(AppDatabase db, int sessionId, int exerciseId, double dist, int secs) =>
    db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
      sessionId: sessionId, exerciseId: exerciseId,
      distanceMetres: Value(dist), durationSeconds: Value(secs)));