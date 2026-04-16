import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';

part 'badge_service.g.dart';

// ---------------------------------------------------------------------------
// Badge definitions
// ---------------------------------------------------------------------------
// Single source of truth for every badge in the system.
// The UI reads from this list to render locked/unlocked states.
// badgeKey must match exactly what is seeded in local_database.dart.
// ---------------------------------------------------------------------------

class BadgeDefinition {
  final String key;
  final String name;
  final String description;
  final String icon; // Material icon codepoint name — no external assets needed

  const BadgeDefinition({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
  });
}

const List<BadgeDefinition> kAllBadges = [
  BadgeDefinition(
    key: 'first_workout',
    name: 'First Rep',
    description: 'Complete your first workout session.',
    icon: 'fitness_center',
  ),
  BadgeDefinition(
    key: 'streak_7_day',
    name: '7-Day Streak',
    description: 'Log at least one session every day for 7 consecutive days.',
    icon: 'local_fire_department',
  ),
  BadgeDefinition(
    key: 'streak_30_day',
    name: '30-Day Streak',
    description: 'Log at least one session every day for 30 consecutive days.',
    icon: 'emoji_events',
  ),
  BadgeDefinition(
    key: 'first_pr',
    name: 'Personal Record',
    description: 'Set your first personal best.',
    icon: 'military_tech',
  ),
  BadgeDefinition(
    key: 'pr_10',
    name: 'PR Machine',
    description: 'Set 10 personal bests across any exercises.',
    icon: 'trending_up',
  ),
  BadgeDefinition(
    key: 'sets_50',
    name: 'Getting Started',
    description: 'Log 50 total sets.',
    icon: 'bolt',
  ),
  BadgeDefinition(
    key: 'sets_500',
    name: 'Iron Consistency',
    description: 'Log 500 total sets.',
    icon: 'workspace_premium',
  ),
  BadgeDefinition(
    key: 'first_custom_exercise',
    name: 'Your Own Rules',
    description: 'Create your first custom exercise.',
    icon: 'add_circle',
  ),
];

// ---------------------------------------------------------------------------
// Watch query — drives the badges screen
// ---------------------------------------------------------------------------

/// Combines the static badge definitions with live Drift rows so the UI
/// always has a fully merged, sorted list. Earned badges show earnedAt;
/// unearned badges show null. The UI never needs to touch the DB directly.
@riverpod
Stream<List<BadgeViewModel>> watchBadges(Ref ref) {
  final db = ref.watch(databaseProvider);

  return (db.select(db.badges)..orderBy([
    (b) => OrderingTerm.asc(b.badgeKey),
  ])).watch().map((rows) {
    final rowByKey = {for (final r in rows) r.badgeKey: r};

    // Preserve the display order defined in kAllBadges — earned first,
    // then unearned, matching standard gamification conventions.
    final earned = <BadgeViewModel>[];
    final unearned = <BadgeViewModel>[];

    for (final def in kAllBadges) {
      final row = rowByKey[def.key];
      final vm = BadgeViewModel(definition: def, earnedAt: row?.earnedAt);
      if (vm.isEarned) {
        earned.add(vm);
      } else {
        unearned.add(vm);
      }
    }

    return [...earned, ...unearned];
  });
}

/// View model consumed by the badges screen.
/// Merges the static definition (name, description, icon) with the
/// live DB row (earnedAt). Clean separation — definitions never go in
/// the database.
class BadgeViewModel {
  final BadgeDefinition definition;
  final DateTime? earnedAt;

  const BadgeViewModel({required this.definition, required this.earnedAt});

  bool get isEarned => earnedAt != null;
  String get key => definition.key;
  String get name => definition.name;
  String get description => definition.description;
  String get icon => definition.icon;
}

// ---------------------------------------------------------------------------
// BadgeService — trigger evaluation
// ---------------------------------------------------------------------------
// Call evaluateAll() after any action that could unlock a badge.
// Each trigger is cheap: a COUNT or a date range query — no full scans.
// evaluateAll() is idempotent: re-evaluating an already-earned badge
// is a no-op because _awardIfNotEarned checks earnedAt before writing.
// ---------------------------------------------------------------------------

@riverpod
class BadgeService extends _$BadgeService {
  @override
  void build() {}

  /// Master evaluation entry point. Call this after:
  ///   - a session is ended (first_workout, streak triggers, sets_50, sets_500)
  ///   - a PR is detected (first_pr, pr_10)
  ///   - a custom exercise is created (first_custom_exercise)
  ///
  /// It is intentionally coarse-grained. Calling it for triggers that
  /// haven't fired yet costs a handful of cheap SQL COUNT queries —
  /// far cheaper than tracking which specific trigger to call.
  Future<List<String>> evaluateAll({
    required int totalPrCount,
  }) async {
    final awarded = <String>[];

    if (await _checkFirstWorkout()) awarded.add('first_workout');
    if (await _checkStreak(7)) awarded.add('streak_7_day');
    if (await _checkStreak(30)) awarded.add('streak_30_day');
    if (totalPrCount >= 1 && await _awardIfNotEarned('first_pr')) {
      awarded.add('first_pr');
    }
    if (totalPrCount >= 10 && await _awardIfNotEarned('pr_10')) {
      awarded.add('pr_10');
    }
    if (await _checkSetCount(50)) awarded.add('sets_50');
    if (await _checkSetCount(500)) awarded.add('sets_500');
    if (await _checkFirstCustomExercise()) awarded.add('first_custom_exercise');

    return awarded;
  }

  // ---------------------------------------------------------------------------
  // Individual trigger checks
  // ---------------------------------------------------------------------------

  Future<bool> _checkFirstWorkout() async {
    final db = ref.read(databaseProvider);
    final countExpr = db.workoutSessions.id.count();
    final query = db.selectOnly(db.workoutSessions)
      ..where(db.workoutSessions.deletedAt.isNull())
      ..where(db.workoutSessions.endTime.isNotNull())
      ..addColumns([countExpr]);
    final count = (await query.getSingle()).read(countExpr) ?? 0;
    if (count < 1) return false;
    return _awardIfNotEarned('first_workout');
  }

  /// Checks for a streak of [days] consecutive calendar days each having
  /// at least one completed session. Works backwards from today.
  ///
  /// A "calendar day" streak — not a 24-hour rolling window. If the user
  /// trains at 11pm and again at 6am the next day, that's two days.
  /// This matches how every mainstream fitness app defines streaks and
  /// is what users expect.
  Future<bool> _checkStreak(int days) async {
    final db = ref.read(databaseProvider);
    final key = days == 7 ? 'streak_7_day' : 'streak_30_day';

    // If already earned, skip the expensive date scan.
    final existing = await _getBadgeRow(key);
    if (existing?.earnedAt != null) return false;

    final sessions = await (db.select(db.workoutSessions)
          ..where((s) => s.deletedAt.isNull())
          ..where((s) => s.endTime.isNotNull()))
        .get();

    if (sessions.length < days) return false;

    // Collect unique calendar days that have a completed session.
    final sessionDays = sessions
        .map((s) => DateTime(
              s.startTime.year,
              s.startTime.month,
              s.startTime.day,
            ))
        .toSet();

    // Walk backwards from today checking for [days] consecutive days.
    final today = DateTime.now();
    int consecutive = 0;
    for (int i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      if (sessionDays.contains(day)) {
        consecutive++;
      } else {
        break;
      }
    }

    if (consecutive < days) return false;
    return _awardIfNotEarned(key);
  }

  Future<bool> _checkSetCount(int threshold) async {
    final db = ref.read(databaseProvider);
    final key = threshold == 50 ? 'sets_50' : 'sets_500';

    final existing = await _getBadgeRow(key);
    if (existing?.earnedAt != null) return false;

    final countExpr = db.workoutSets.id.count();
    final query = db.selectOnly(db.workoutSets)
      ..where(db.workoutSets.deletedAt.isNull())
      ..addColumns([countExpr]);
    final count = (await query.getSingle()).read(countExpr) ?? 0;

    if (count < threshold) return false;
    return _awardIfNotEarned(key);
  }

  Future<bool> _checkFirstCustomExercise() async {
    final db = ref.read(databaseProvider);

    final existing = await _getBadgeRow('first_custom_exercise');
    if (existing?.earnedAt != null) return false;

    final countExpr = db.exercises.id.count();
    final query = db.selectOnly(db.exercises)
      ..where(db.exercises.isCustom.equals(true))
      ..addColumns([countExpr]);
    final count = (await query.getSingle()).read(countExpr) ?? 0;

    if (count < 1) return false;
    return _awardIfNotEarned('first_custom_exercise');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Badge?> _getBadgeRow(String key) async {
    final db = ref.read(databaseProvider);
    return (db.select(db.badges)
          ..where((b) => b.badgeKey.equals(key)))
        .getSingleOrNull();
  }

  /// Stamps earnedAt = now() on the badge row if it hasn't been earned yet.
  /// Returns true if a new award was written, false if already earned or
  /// the row doesn't exist (should never happen after seeding, but defensive).
  Future<bool> _awardIfNotEarned(String key) async {
    final db = ref.read(databaseProvider);
    final row = await _getBadgeRow(key);

    // Already earned — idempotent, do nothing.
    if (row == null || row.earnedAt != null) return false;

    await (db.update(db.badges)..where((b) => b.badgeKey.equals(key))).write(
      BadgesCompanion(
        earnedAt: Value(DateTime.now()),
        // Mark dirty for sync — same pattern as every other syncable table.
        syncedAt: const Value(null),
      ),
    );
    return true;
  }
}