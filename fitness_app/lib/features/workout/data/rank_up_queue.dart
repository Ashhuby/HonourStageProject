/// The rank the user has just climbed to, waiting to be announced.
///
/// A single value rather than a queue, unlike [BadgeUnlockQueue]: a rank-up is
/// caused by the badges awarded alongside it, and awarding enough at once to
/// cross two ranks should say where you ended up, not walk you through the
/// step you passed through on the way.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/rank.dart';

part 'rank_up_queue.g.dart';

/// Kept alive for the same reason the badge queue is: a rank-up can land while
/// no widget happens to be listening, and one that is dropped is never
/// mentioned again — the header simply reads differently the next time the
/// user looks.
@Riverpod(keepAlive: true)
class RankUpQueue extends _$RankUpQueue {
  @override
  Rank? build() => null;

  /// Announces [rank], replacing any rank still pending — which can only ever
  /// be a lower one, since the ladder is only climbed.
  void announce(Rank rank) => state = rank;

  /// Drops the announcement once it has been shown.
  void clear() {
    if (state != null) state = null;
  }
}
