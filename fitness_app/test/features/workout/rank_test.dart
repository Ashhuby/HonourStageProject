import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/workout/domain/badge_catalogue.dart';
import 'package:fitness_app/features/workout/domain/rank.dart';
import 'package:fitness_app/features/workout/presentation/widgets/rank_visuals.dart';

/// Tests the rank ladder.
///
/// Ranks are derived entirely from the badges held, so the risks are not in
/// the arithmetic but in the ladder itself: a top rank the catalogue cannot
/// reach, thresholds that overlap, or a rank that shares a colour with the
/// badge tier of the same name — each of which fails silently, as a ladder
/// that simply never pays out or a header nobody can read.
void main() {
  group('points', () {
    test('a tier is worth more than everything below it', () {
      // The steepness is the point. If a gold were worth two bronzes, breadth
      // would beat difficulty and the ladder would reward logging one set a
      // day over pulling double bodyweight.
      expect(
        rankPointsForTier(BadgeTier.silver),
        greaterThan(rankPointsForTier(BadgeTier.bronze)),
      );
      expect(
        rankPointsForTier(BadgeTier.gold),
        greaterThan(rankPointsForTier(BadgeTier.silver)),
      );
      expect(
        rankPointsForTier(BadgeTier.platinum),
        greaterThan(rankPointsForTier(BadgeTier.gold)),
      );
    });

    test('an empty collection is worth nothing', () {
      expect(rankPointsOf(const []), 0);
    });

    test('points are the sum of the tiers held', () {
      expect(
        rankPointsOf([BadgeTier.bronze, BadgeTier.bronze, BadgeTier.gold]),
        rankPointsForTier(BadgeTier.bronze) * 2 +
            rankPointsForTier(BadgeTier.gold),
      );
    });
  });

  group('the ladder', () {
    test('starts at zero, so a new user holds a rank rather than none', () {
      expect(Rank.values.first.threshold, 0);
      expect(rankForPoints(0), Rank.sand);
    });

    test('thresholds ascend', () {
      for (var i = 1; i < Rank.values.length; i++) {
        expect(
          Rank.values[i].threshold,
          greaterThan(Rank.values[i - 1].threshold),
          reason: '${Rank.values[i].label} is not above the rank below it',
        );
      }
    });

    test('the top rank is reachable', () {
      // The guard that matters when a badge is added or retired: a top
      // threshold above what the catalogue can yield is a rank nobody can
      // ever hold, and nothing would report it.
      expect(Rank.values.last.threshold, lessThanOrEqualTo(kMaxRankPoints));
    });

    test('the top rank demands most of the catalogue', () {
      // The other half of that guard. A top rank reachable with a third of
      // the badges is not a top rank.
      expect(Rank.values.last.threshold, greaterThan(kMaxRankPoints * 0.8));
    });

    test('a rank is held from its threshold up to the next one', () {
      for (final rank in Rank.values) {
        expect(rankForPoints(rank.threshold), rank, reason: rank.label);

        final next = rank.next;
        if (next == null) continue;
        expect(rankForPoints(next.threshold - 1), rank, reason: rank.label);
      }
    });

    test('points beyond the top stay at the top', () {
      expect(rankForPoints(kMaxRankPoints * 10), Rank.values.last);
      expect(Rank.values.last.next, isNull);
    });
  });

  group('standing', () {
    test('reports what is left to the next rank', () {
      final standing = standingFor(Rank.pebble.threshold);

      expect(standing.rank, Rank.pebble);
      expect(standing.next, Rank.pebble.next);
      expect(
        standing.pointsToNext,
        Rank.stone.threshold - Rank.pebble.threshold,
      );
      expect(standing.fraction, 0);
    });

    test('fills as the rank is crossed', () {
      final span = Rank.stone.threshold - Rank.pebble.threshold;
      final standing = standingFor(Rank.pebble.threshold + span ~/ 2);

      expect(standing.rank, Rank.pebble);
      expect(standing.fraction, closeTo(0.5, 0.05));
    });

    test('the top rank reads as complete rather than as stalled', () {
      // A bar that can never fill is worse than no bar: at the top there is
      // nothing left to earn, and showing 0% would say the opposite.
      final standing = standingFor(kMaxRankPoints);

      expect(standing.rank, Rank.values.last);
      expect(standing.next, isNull);
      expect(standing.pointsToNext, 0);
      expect(standing.fraction, 1);
    });
  });

  group('presentation', () {
    test('every rank has a numeral and a colour', () {
      for (final rank in Rank.values) {
        expect(rank.numeral, isNotEmpty, reason: rank.label);
        expect(rank.color, isNot(OneRepColors.background), reason: rank.label);
      }
    });

    test('no two ranks look alike', () {
      final colours = {for (final rank in Rank.values) rank.color};
      expect(colours, hasLength(Rank.values.length));

      final numerals = {for (final rank in Rank.values) rank.numeral};
      expect(numerals, hasLength(Rank.values.length));
    });

    test('a rank never wears a badge tier colour', () {
      // The two ladders appear together in the badges header. Sharing a
      // colour there would make a rank read as a tier, which is the confusion
      // the separate names were chosen to avoid.
      final tierColours = <Color>{
        OneRepColors.bronze,
        OneRepColors.silver,
        OneRepColors.gold,
        OneRepColors.platinum,
      };

      for (final rank in Rank.values) {
        expect(
          tierColours.contains(rank.color),
          isFalse,
          reason: '${rank.label} is drawn in a badge tier colour',
        );
      }
    });
  });
}
