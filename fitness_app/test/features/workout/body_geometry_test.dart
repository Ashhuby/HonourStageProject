import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';
import 'package:fitness_app/features/workout/presentation/widgets/body_geometry.dart';

/// Guards the conversion of the vendored SVG artwork into hit-testable paths.
///
/// A bad ingest compiles perfectly and simply draws nothing, or draws a region
/// off-screen where no tap can ever reach it. None of that is visible to the
/// analyser or to any other test, so it is pinned here.
void main() {
  test('every muscle in the vocabulary is drawn somewhere', () {
    final drawn = {
      ...musclePathsFor(BodyView.front).keys,
      ...musclePathsFor(BodyView.back).keys,
    };

    for (final muscle in Muscle.values) {
      // Full Body is the exception by design — it has no anatomical region and
      // is offered as a pill beneath the figures instead.
      if (muscle == Muscle.fullBody) continue;
      expect(drawn, contains(muscle), reason: '${muscle.label} is not drawn');
    }
  });

  test('no muscle path is empty', () {
    for (final view in BodyView.values) {
      musclePathsFor(view).forEach((muscle, path) {
        final bounds = path.getBounds();
        expect(
          bounds.width * bounds.height,
          greaterThan(0),
          reason: '${muscle.label} on $view has no area',
        );
      });
    }
  });

  test('every path falls inside its view\'s design box', () {
    for (final view in BodyView.values) {
      final origin = designOriginFor(view);
      final width = designWidthFor(view);

      void check(String what, Rect bounds) {
        expect(bounds.left, greaterThanOrEqualTo(origin - 0.5), reason: what);
        expect(
          bounds.right,
          lessThanOrEqualTo(origin + width + 0.5),
          reason: what,
        );
        expect(bounds.top, greaterThanOrEqualTo(-0.5), reason: what);
        expect(
          bounds.bottom,
          lessThanOrEqualTo(kDesignHeight + 0.5),
          reason: what,
        );
      }

      musclePathsFor(view).forEach(
        (muscle, path) => check('${muscle.label} on $view', path.getBounds()),
      );
      check('inert on $view', inertPathFor(view).getBounds());
    }
  });

  test('each group region unions the muscles that view shows', () {
    // Arms appears on both views — biceps and forearms in front, triceps and
    // forearms behind — so it must be tappable on either figure.
    for (final view in BodyView.values) {
      final regions = groupRegionsFor(view);
      expect(regions.keys, contains(MuscleGroup.arms), reason: '$view');
    }

    expect(groupRegionsFor(BodyView.front).keys, contains(MuscleGroup.chest));
    expect(groupRegionsFor(BodyView.back).keys, contains(MuscleGroup.back));
    // Chest is a front-only region; Back is back-only.
    expect(
      groupRegionsFor(BodyView.back).keys,
      isNot(contains(MuscleGroup.chest)),
    );
    expect(
      groupRegionsFor(BodyView.front).keys,
      isNot(contains(MuscleGroup.back)),
    );
  });

  test('hit order runs smallest region first', () {
    // Overlaps resolve to the more specific group, so the ordering carries
    // real behaviour rather than being cosmetic.
    for (final view in BodyView.values) {
      final regions = groupRegionsFor(view);
      final order = hitOrderFor(view);

      expect(order.toSet(), regions.keys.toSet());

      var previous = 0.0;
      for (final group in order) {
        final bounds = regions[group]!.getBounds();
        final area = bounds.width * bounds.height;
        expect(area, greaterThanOrEqualTo(previous), reason: '$view $group');
        previous = area;
      }
    }
  });

  test('a point inside a muscle resolves to that muscle\'s group', () {
    // Sample the centre of each muscle's bounds and check the group region
    // covering it is the one it belongs to, or a smaller overlapping one.
    for (final view in BodyView.values) {
      final regions = groupRegionsFor(view);
      musclePathsFor(view).forEach((muscle, path) {
        final region = regions[muscle.group]!;
        // The union of a group contains every one of its muscles' paths, so a
        // point in the muscle is necessarily in the group.
        final bounds = path.getBounds();
        final probe = bounds.center;
        if (!path.contains(probe)) return; // concave shape; skip this one
        expect(
          region.contains(probe),
          isTrue,
          reason: '${muscle.label} centre is outside ${muscle.group.label}',
        );
      });
    }
  });
}
