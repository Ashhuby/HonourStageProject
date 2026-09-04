import 'package:fitness_app/core/database/local_database.dart';

/// Makes a database file genuinely look like an older schema version.
///
/// The migration tests all work the same way: open an [AppDatabase] (which
/// creates every table at today's schema), write the rows an older install
/// would have had, then stamp an older `user_version` and reopen so the real
/// `onUpgrade` runs over it.
///
/// The stamp alone is a fiction. The file still has every column the current
/// schema defines, so the moment a migration adds one, `ALTER TABLE ... ADD
/// COLUMN` fails with "duplicate column name" and four unrelated tests break
/// on a change that has nothing to do with them. Dropping the columns first
/// makes the fiction true.
///
/// **This has to grow with every migration that adds a column.** A missing
/// entry does not fail quietly — it fails on the next test run, loudly, which
/// is the reason it is done here rather than filtered out at the migration.
Future<void> makeLookLikeVersion(AppDatabase db, int version) async {
  /// Columns introduced by each version, dropped when pretending to predate it.
  const addedIn = <int, List<String>>{
    13: [
      'workout_splits.schedule_mode',
      'workout_splits.cycle_length',
      'workout_splits.is_default',
      'workout_routines.schedule_slots',
    ],
  };

  for (final entry in addedIn.entries) {
    if (version >= entry.key) continue;
    for (final column in entry.value) {
      final parts = column.split('.');
      await db.customStatement(
        'ALTER TABLE ${parts[0]} DROP COLUMN ${parts[1]}',
      );
    }
  }

  await db.customStatement('PRAGMA user_version = $version');
}
