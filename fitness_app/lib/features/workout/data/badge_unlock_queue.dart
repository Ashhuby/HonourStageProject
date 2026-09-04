/// Badges earned but not yet celebrated.
///
/// `BadgeService.evaluateAll` has always returned the keys it just awarded,
/// and every one of its three call sites discarded that value — so the only
/// way to find out you had earned something was to open the badges tab and
/// notice a tile had changed. A queue rather than a single value because
/// several badges can fall at once: finishing a first session can trip the
/// first-workout, first-cardio and streak badges together, and they deserve to
/// be shown one after another rather than three deep in a stack.
///
/// The service pushes here itself instead of returning to the caller, so a
/// future call site cannot forget to wire it up.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/badge_catalogue.dart';

part 'badge_unlock_queue.g.dart';

/// The pending celebrations, oldest first.
///
/// Kept alive rather than auto-disposed: an award can land while no widget
/// happens to be listening — during a rebuild, or between routes — and a
/// dropped queue is a badge the user is never told about.
@Riverpod(keepAlive: true)
class BadgeUnlockQueue extends _$BadgeUnlockQueue {
  @override
  List<BadgeDefinition> build() => const [];

  /// Queues newly-awarded badges for celebration.
  ///
  /// Unknown keys are skipped rather than throwing — a badge row synced from a
  /// newer version of the app has no definition here, and that is not worth a
  /// crash. Keys already queued are skipped too, so a repeated evaluation
  /// cannot show the same badge twice.
  void enqueue(Iterable<String> keys) {
    final queued = {for (final badge in state) badge.key};
    final additions = <BadgeDefinition>[];

    for (final key in keys) {
      if (!queued.add(key)) continue;
      final definition = badgeByKeyOrNull(key);
      if (definition != null) additions.add(definition);
    }

    if (additions.isEmpty) return;
    state = [...state, ...additions];
  }

  /// Drops the badge currently being celebrated, revealing the next.
  void dismissCurrent() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }

  /// Drops everything pending. Used on sign-out, where the badge rows are
  /// reset and a queued celebration would belong to the previous account.
  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }
}
