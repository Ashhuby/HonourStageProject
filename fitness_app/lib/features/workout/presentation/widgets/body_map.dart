import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/muscle.dart';
import 'body_geometry.dart';
import 'exercise_filter.dart';

/// Front and back figures, tapped to filter the exercise list by muscle group.
///
/// Only the seven [MuscleGroup]s are tappable. Individual muscles — forearms,
/// calves, the three heads of the deltoid — are chosen from the chip row that
/// appears beneath a selected group, because none of them is a comfortable
/// target for a thumb at this size.
///
/// The outlines are real anatomy rather than rounded rectangles: SVG paths
/// from the `body-muscles` project, parsed once into [Path]s. See
/// `body_paths.g.dart` for provenance.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
    this.figureHeight = 210,
  });

  /// Per-group counts, dimming a region that holds nothing.
  ///
  /// Null when the map is being used to *choose* a muscle rather than to
  /// filter a list — in the exercise editor every region is a valid answer,
  /// so dimming one would be saying it cannot be picked.
  final Map<MuscleGroup, MuscleCount>? counts;

  final MuscleGroup? selected;

  /// Tapping the selected group, or missing every region, passes null.
  final ValueChanged<MuscleGroup?> onSelected;

  /// Height of each figure in logical pixels; width follows from the artwork's
  /// aspect ratio.
  final double figureHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildView(BodyView.front),
            const SizedBox(width: 16),
            _buildView(BodyView.back),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ViewLabel('FRONT', width: _widthFor(BodyView.front)),
            const SizedBox(width: 16),
            _ViewLabel('BACK', width: _widthFor(BodyView.back)),
          ],
        ),
        const SizedBox(height: 12),
        _buildPills(),
      ],
    );
  }

  double _widthFor(BodyView view) =>
      figureHeight * designWidthFor(view) / kDesignHeight;

  Widget _buildView(BodyView view) {
    final scale = figureHeight / kDesignHeight;
    final origin = designOriginFor(view);
    final regions = groupRegionsFor(view);
    final order = hitOrderFor(view);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        // Back into design space: undo the scale, then the view's own origin.
        final point = Offset(
          details.localPosition.dx / scale + origin,
          details.localPosition.dy / scale,
        );
        for (final group in order) {
          if (regions[group]!.contains(point)) {
            onSelected(selected == group ? null : group);
            return;
          }
        }
        // A tap on the figure but outside every region clears the filter.
        onSelected(null);
      },
      child: SizedBox(
        width: _widthFor(view),
        height: figureHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BodyPainter(
                  view: view,
                  counts: counts,
                  selected: selected,
                ),
              ),
            ),
            // Screen readers cannot see a CustomPaint, so each region gets an
            // invisible, non-hit-testing box carrying its semantics.
            for (final group in order)
              _semanticsFor(group, regions[group]!, scale, origin),
          ],
        ),
      ),
    );
  }

  Widget _semanticsFor(
    MuscleGroup group,
    Path path,
    double scale,
    double origin,
  ) {
    final bounds = path.getBounds();
    final tally = counts;
    final label = tally == null
        ? group.label
        : '${group.label}, ${tally[group]?.total ?? 0} '
              '${(tally[group]?.total ?? 0) == 1 ? 'exercise' : 'exercises'}';

    return Positioned(
      left: (bounds.left - origin) * scale,
      top: bounds.top * scale,
      width: bounds.width * scale,
      height: bounds.height * scale,
      child: Semantics(
        button: true,
        selected: selected == group,
        label: label,
        onTap: () => onSelected(selected == group ? null : group),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// The reset.
  ///
  /// This used to also carry a "Full Body" pill, because cardio was filed
  /// under a muscle that had no anatomical region to draw. Cardio is now its
  /// own category, so every group on the map is a real place on the body and
  /// the diagram needs no escape hatch.
  Widget _buildPills() {
    // Nothing to reset to when the map is a picker: some muscle is always the
    // answer.
    if (selected == null || counts == null) return const SizedBox.shrink();

    return _MapPill(
      label: 'Show all',
      color: OneRepColors.textSecondary,
      isSelected: false,
      onTap: () => onSelected(null),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.view,
    required this.counts,
    required this.selected,
  });

  final BodyView view;
  final Map<MuscleGroup, MuscleCount>? counts;
  final MuscleGroup? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / kDesignHeight);
    canvas.translate(-designOriginFor(view), 0);

    canvas.drawPath(
      inertPathFor(view),
      Paint()..color = OneRepColors.surfaceElevated,
    );

    final regions = groupRegionsFor(view);
    // Painted in reverse of the hit-test order, so the region that wins a tap
    // where two overlap is also the one drawn on top.
    for (final group in hitOrderFor(view).reversed) {
      // A null tally means every region is live — see BodyMap.counts.
      final count = counts?[group]?.total ?? 1;
      final isSelected = selected == group;

      final Color fill;
      if (isSelected) {
        fill = group.color;
      } else if (count > 0) {
        // The silhouette beneath is very dark, so a light tint reads as almost
        // nothing; 0.55 is where the groups become distinguishable at a glance
        // without competing with the selected one.
        fill = group.color.withValues(alpha: 0.55);
      } else {
        fill = OneRepColors.surfaceHighest;
      }
      canvas.drawPath(regions[group]!, Paint()..color = fill);

      if (isSelected) {
        canvas.drawPath(
          regions[group]!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = OneRepColors.textPrimary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.view != view ||
      old.selected != selected ||
      !mapEquals(old.counts, counts);
}

class _ViewLabel extends StatelessWidget {
  const _ViewLabel(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: OneRepColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : OneRepColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : OneRepColors.surfaceHighest,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: OneRepColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
