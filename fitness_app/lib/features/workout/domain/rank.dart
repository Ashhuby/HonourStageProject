/// The rank ladder, derived entirely from the badges already earned.
///
/// A rank is a summary of the collection rather than a separate thing to
/// grind: every badge is worth points by tier, and the total places the user on
/// the ladder. Nothing here queries anything — pass in the tiers of the earned
/// badges and the rank falls out — which is what lets the award path, the
/// badges header and the rank-up celebration all agree without coordinating.
///
/// Deliberately named apart from [BadgeTier]. Bronze, silver, gold and platinum
/// already mean "how good is this badge"; reusing them here would leave the
/// header saying "Gold — 3 gold badges" and meaning two different things.
library;

import 'badge_catalogue.dart';

/// What one badge of each tier contributes.
///
/// Steep rather than linear: a platinum badge is worth twelve bronzes because
/// it is worth far more than twelve times the effort, and a ladder that
/// rewarded breadth alone would put a user who logged one set a day above one
/// who pulled double bodyweight.
int rankPointsForTier(BadgeTier tier) => switch (tier) {
  BadgeTier.bronze => 1,
  BadgeTier.silver => 3,
  BadgeTier.gold => 6,
  BadgeTier.platinum => 12,
};

/// The points a set of earned badges is worth.
int rankPointsOf(Iterable<BadgeTier> earnedTiers) =>
    earnedTiers.fold(0, (total, tier) => total + rankPointsForTier(tier));

/// The most points the catalogue can yield — every badge earned.
///
/// Computed rather than written down so adding a badge cannot silently put
/// the top rank out of reach.
final int kMaxRankPoints = rankPointsOf(kAllBadges.map((b) => b.tier));

/// The ladder, lowest first.
enum Rank {
  iron('Iron', 0),
  copper('Copper', 12),
  steel('Steel', 30),
  obsidian('Obsidian', 55),
  titanium('Titanium', 85),
  mithril('Mithril', 118);

  const Rank(this.label, this.threshold);

  /// The name shown to the user.
  final String label;

  /// The points needed to hold this rank.
  final int threshold;

  /// The rank above this one, or null at the top.
  Rank? get next =>
      index + 1 < Rank.values.length ? Rank.values[index + 1] : null;

  /// The rank as a numeral, which is what the crest draws. Legible at the
  /// twenty pixels the nav bar gives it, where a name would not be.
  String get numeral => const ['I', 'II', 'III', 'IV', 'V', 'VI'][index];
}

/// The rank [points] earns: the highest whose threshold has been passed.
Rank rankForPoints(int points) {
  var held = Rank.values.first;
  for (final rank in Rank.values) {
    if (points >= rank.threshold) held = rank;
  }
  return held;
}

/// Where a user stands: the rank held, and how far into it they are.
typedef RankStanding = ({
  Rank rank,
  int points,
  Rank? next,
  /// Points still needed for [next]; zero at the top of the ladder.
  int pointsToNext,
  /// Progress through the current rank in 0..1. One at the top, because a
  /// bar that can never fill is worse than no bar.
  double fraction,
});

/// Where [points] places the user.
RankStanding standingFor(int points) {
  final rank = rankForPoints(points);
  final next = rank.next;

  if (next == null) {
    return (
      rank: rank,
      points: points,
      next: null,
      pointsToNext: 0,
      fraction: 1,
    );
  }

  final span = next.threshold - rank.threshold;
  final gained = points - rank.threshold;

  return (
    rank: rank,
    points: points,
    next: next,
    pointsToNext: next.threshold - points,
    fraction: span <= 0 ? 1 : (gained / span).clamp(0.0, 1.0).toDouble(),
  );
}
