import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/domain/badge_catalogue.dart';

import 'schema_fixture.dart';

/// Tests the v11 → v12 badge re-seed.
///
/// v12 changes no schema at all: a badge is a row keyed on `badge_key`, and
/// the tiered catalogue is twenty-five more of them. The version bump exists
/// only so `_seedBadges()` runs again on installs that already exist — without
/// it those users would have no rows for the new badges and could never earn
/// them, silently, with the badges screen showing them permanently locked.
///
/// Runs the real migration over a real v11 database file.
void main() {
  late Directory tempDir;
  late File dbFile;

  /// The badges that existed before v12.
  const v11Badges = [
    'first_workout',
    'streak_7_day',
    'streak_30_day',
    'first_pr',
    'pr_10',
    'sets_50',
    'sets_500',
    'first_cardio',
    'marathon_distance',
    'first_mobility',
    'first_custom_exercise',
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onerep_badge_seed');
    dbFile = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Builds a database file holding only the v11 badge rows, closed and ready
  /// to be reopened by the migrating [AppDatabase].
  Future<void> buildV11Database({
    Map<String, DateTime> earned = const {},
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1');

    // forTesting skips the seed, so the v11 rows go in by hand — which is also
    // what makes the file genuinely look like the older install.
    await db.customStatement('DELETE FROM badges');
    for (final key in v11Badges) {
      await db
          .into(db.badges)
          .insert(
            BadgesCompanion.insert(
              badgeKey: key,
              earnedAt: Value(earned[key]),
              syncedAt: Value(earned.containsKey(key) ? DateTime.now() : null),
            ),
          );
    }

    await makeLookLikeVersion(db, 11);
    await db.close();
  }

  Future<Map<String, DateTime?>> reopenAndRead() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    // Opening runs onUpgrade.
    final rows = await db.select(db.badges).get();
    await db.close();
    return {for (final row in rows) row.badgeKey: row.earnedAt};
  }

  test('every badge in the catalogue has a row after upgrading', () async {
    await buildV11Database();
    final rows = await reopenAndRead();

    for (final badge in kAllBadges) {
      expect(
        rows.containsKey(badge.key),
        isTrue,
        reason: '${badge.key} has no row, so it could never be earned',
      );
    }
    expect(rows.length, kAllBadges.length);
  });

  test('a badge already earned keeps its date', () async {
    final awardedAt = DateTime(2026, 3, 14);
    await buildV11Database(earned: {'first_workout': awardedAt});

    final rows = await reopenAndRead();

    // The seed is an upsert on badge_key. If it overwrote rather than merged,
    // the user would lose every badge they had earned.
    expect(rows['first_workout'], awardedAt);
    expect(rows['streak_7_day'], isNull);
  });

  test('the new badges arrive unearned', () async {
    await buildV11Database();
    final rows = await reopenAndRead();

    final newKeys = kAllBadges
        .map((b) => b.key)
        .where((key) => !v11Badges.contains(key));

    expect(newKeys, isNotEmpty);
    for (final key in newKeys) {
      expect(rows[key], isNull, reason: '$key was awarded by the migration');
    }
  });

  test('reopening the migrated file changes nothing', () async {
    await buildV11Database(earned: {'sets_50': DateTime(2026, 1, 2)});
    final first = await reopenAndRead();
    final second = await reopenAndRead();

    expect(second.length, first.length);
    expect(second['sets_50'], first['sets_50']);
  });
}
