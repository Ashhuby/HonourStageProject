import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/badge_catalogue.dart';
import 'package:fitness_app/features/workout/domain/session_highlights.dart';
import 'package:fitness_app/features/workout/presentation/widgets/session_chips.dart'
    show badgeIconData;

/// Guards the places a new badge has to be registered but where forgetting
/// fails silently rather than loudly.
///
/// Each of these has already gone wrong once: an icon name missing from
/// `badgeIconData` renders a star with no error, and a key missing from the
/// session attribution set means the badge simply never appears as a chip.
void main() {
  group('keys', () {
    test('are unique', () {
      final keys = kAllBadges.map((b) => b.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('badgeByKeyOrNull finds every badge, and nothing else', () {
      for (final badge in kAllBadges) {
        expect(badgeByKeyOrNull(badge.key), same(badge));
      }
      expect(badgeByKeyOrNull('no_such_badge'), isNull);
    });

    test('the keys shipped before the tiered catalogue all survive', () {
      // These have rows in every existing install and in the remote `badges`
      // table. Renaming one would orphan the row, silently un-earning it.
      const shipped = {
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
      };
      final keys = kAllBadges.map((b) => b.key).toSet();
      expect(keys.containsAll(shipped), isTrue);
    });
  });

  group('icons', () {
    test('every badge resolves to a real icon, not the fallback star', () {
      for (final badge in kAllBadges) {
        expect(
          badgeIconData(badge.icon),
          isNot(Icons.star),
          reason:
              '${badge.key} uses icon "${badge.icon}", which is missing from '
              'badgeIconData() and renders as the fallback star',
        );
      }
    });

    test('an unknown name still falls back rather than throwing', () {
      // A badge synced from a newer app version must not crash this one.
      expect(badgeIconData('not_an_icon'), Icons.star);
    });
  });

  group('criteria', () {
    test('every target is positive', () {
      for (final badge in kAllBadges) {
        expect(badge.target, greaterThan(0), reason: badge.key);
      }
    });

    test('a badge showing progress has somewhere to progress to', () {
      // The bodyweight ratio is exempt: its target of 1.0 is a real journey
      // measured in fractions, not a one-step badge.
      final counted = kAllBadges.where(
        (b) =>
            b.showsProgress &&
            b.stat != BadgeStat.bestBigLiftBodyweightRatio,
      );

      for (final badge in counted) {
        expect(
          badge.target,
          greaterThan(1),
          reason:
              '${badge.key} draws a progress ring but is earned in one step; '
              'either raise the target or set showsProgress: false',
        );
      }
    });

    test('badges sharing a stat form a ladder of distinct thresholds', () {
      final byStat = <BadgeStat, List<num>>{};
      for (final badge in kAllBadges) {
        byStat.putIfAbsent(badge.stat, () => []).add(badge.target);
      }
      for (final entry in byStat.entries) {
        expect(
          entry.value.toSet().length,
          entry.value.length,
          reason:
              'two badges on ${entry.key.name} share a threshold, so they '
              'would always be earned together',
        );
      }
    });

    test('every tier and category is used', () {
      for (final tier in BadgeTier.values) {
        expect(
          kAllBadges.any((b) => b.tier == tier),
          isTrue,
          reason: 'no badge is ${tier.label}',
        );
      }
      for (final category in BadgeCategory.values) {
        expect(
          kAllBadges.any((b) => b.category == category),
          isTrue,
          reason: 'the ${category.label} filter chip would show nothing',
        );
      }
    });
  });

  group('session attribution', () {
    test('covers every badge except the curation ones', () {
      for (final badge in kAllBadges) {
        expect(
          kSessionAttributableBadges.contains(badge.key),
          !kCurationBadges.contains(badge.key),
          reason: badge.key,
        );
      }
    });

    test('the curation badges name real badges', () {
      for (final key in kCurationBadges) {
        expect(badgeByKeyOrNull(key), isNotNull, reason: key);
      }
    });
  });
}
