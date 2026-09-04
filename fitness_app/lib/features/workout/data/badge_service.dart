import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import '../../profile/data/profile_provider.dart';
import '../domain/badge_catalogue.dart';
import 'badge_stats.dart';
import 'badge_unlock_queue.dart';

// The catalogue moved to domain/badge_catalogue.dart so the database seed can
// read it without importing this file's providers. Re-exported because every
// existing consumer — the badges screen, the session chips, the sync service —
// reaches for kAllBadges through here.
export '../domain/badge_catalogue.dart';

part 'badge_service.g.dart';

// ---------------------------------------------------------------------------
// Watch query — drives the badges screen
// ---------------------------------------------------------------------------

/// Combines the static badge definitions with live Drift rows so the UI
/// always has a fully merged, sorted list. Earned badges show earnedAt;
/// unearned badges show null. The UI never needs to touch the DB directly.
@riverpod
Stream<List<BadgeViewModel>> watchBadges(Ref ref) {
  final db = ref.watch(databaseProvider);

  return (db.select(
    db.badges,
  )..orderBy([(b) => OrderingTerm.asc(b.badgeKey)])).watch().map((rows) {
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
  BadgeTier get tier => definition.tier;
  BadgeCategory get category => definition.category;
}

// ---------------------------------------------------------------------------
// BadgeService — trigger evaluation
// ---------------------------------------------------------------------------
// Call evaluateAll() after any action that could unlock a badge.
//
// Every criterion is "counter reached threshold", so evaluation is one stats
// snapshot compared against kAllBadges rather than a method per badge. That
// keeps adding a badge a data change, and — because the same snapshot backs
// the progress rings on the badges screen — guarantees the ring and the award
// are measuring the same thing.
//
// evaluateAll() is idempotent: already-earned badges are excluded before the
// stats are computed, so re-evaluating writes nothing and queues nothing.
// ---------------------------------------------------------------------------

@riverpod
class BadgeService extends _$BadgeService {
  @override
  void build() {}

  /// Master evaluation entry point. Call this after any action that could
  /// unlock a badge — a session ending, a set being logged, a custom exercise
  /// or split being created.
  ///
  /// Newly-awarded keys are both returned and pushed onto
  /// [BadgeUnlockQueue], which is what actually surfaces the celebration.
  /// Pushing from here rather than returning to the caller means a new call
  /// site cannot forget to wire it up — the three that existed when the queue
  /// was introduced all discarded the return value.
  Future<List<String>> evaluateAll({required int totalPrCount}) async {
    // Badge work is never worth failing a workout for. This runs inside
    // `logSet` and inside `endSession`, and `endSession` is awaited by the
    // Finish button — an exception thrown from here propagates into that
    // await, the pops that follow it never run, and the user is left on the
    // session screen with a button that does nothing and no error to explain
    // it. A badge that cannot be evaluated is a badge earned later instead.
    try {
      return await _evaluate(totalPrCount);
    } catch (error, stack) {
      debugPrint('Badge evaluation failed: $error\n$stack');
      return const [];
    }
  }

  Future<List<String>> _evaluate(int totalPrCount) async {
    final db = ref.read(databaseProvider);

    // Only unearned badges can be awarded, and only their stats need
    // computing. This runs after every logged set, so the work has to shrink
    // as the collection fills — once everything is earned it is one COUNT.
    final unearned = await _unearnedBadges();
    if (unearned.isEmpty) return const [];

    final wanted = {for (final def in unearned) def.stat};

    final stats = await computeBadgeStats(
      db,
      prCount: totalPrCount,
      bodyweightKg: wanted.contains(BadgeStat.bestBigLiftBodyweightRatio)
          ? await _bodyweightOrNull()
          : null,
      only: wanted,
    );

    final awarded = <String>[];
    for (final def in unearned) {
      if (!isEarnedBy(def, stats)) continue;
      if (await _awardIfNotEarned(def.key)) awarded.add(def.key);
    }

    if (awarded.isNotEmpty) {
      ref.read(badgeUnlockQueueProvider.notifier).enqueue(awarded);
    }
    return awarded;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The user's bodyweight, or null if it cannot be read.
  ///
  /// Only two badges need it, and it is the one input that does not come from
  /// the database — the profile lives in `SharedPreferences`, so reading it
  /// crosses a platform channel. Read lazily so a user who has already earned
  /// those two never pays for it, and tolerantly because this runs inside
  /// `logSet`: a profile that cannot be loaded should cost the user two locked
  /// badges, not the set they just finished.
  Future<double?> _bodyweightOrNull() async {
    try {
      final profile = await ref.read(profileNotifierProvider.future);
      return profile.bodyweightKg;
    } catch (_) {
      return null;
    }
  }

  /// The definitions with no row yet, or a row that has never been earned.
  ///
  /// A definition with no row at all is included: it will fail to award (see
  /// [_awardIfNotEarned]) but silently dropping it here would hide the real
  /// fault, which is a missed seed after adding a badge.
  Future<List<BadgeDefinition>> _unearnedBadges() async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(
      db.badges,
    )..where((b) => b.earnedAt.isNotNull())).get();

    final earnedKeys = {for (final row in rows) row.badgeKey};
    return [
      for (final def in kAllBadges)
        if (!earnedKeys.contains(def.key)) def,
    ];
  }

  /// Stamps earnedAt = now() on the badge row if it hasn't been earned yet.
  /// Returns true if a new award was written, false if already earned or
  /// the row doesn't exist (should never happen after seeding, but defensive).
  Future<bool> _awardIfNotEarned(String key) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.badges,
    )..where((b) => b.badgeKey.equals(key))).getSingleOrNull();

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
