import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'body_part.dart';

/// The coordinate space the silhouette is authored in.
///
/// Every path below is expressed in this fixed design box and scaled to the
/// widget's real width at paint time, so the figure is resolution independent
/// and taps map back to the same coordinates by dividing by that scale.
const double _kDesignWidth = 100;
const double _kDesignHeight = 220;

enum _View { front, back }

/// A tappable muscle group: the [BodyPart] it selects and the shape it fills.
class _Region {
  final BodyPart part;
  final Path path;

  const _Region(this.part, this.path);
}

// ---------------------------------------------------------------------------
// Path authoring helpers
// ---------------------------------------------------------------------------

Path _rounded(double l, double t, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
  );

Path _oval(double cx, double cy, double w, double h) =>
    Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h));

Path _union(List<Path> parts) {
  final path = Path();
  for (final part in parts) {
    path.addPath(part, Offset.zero);
  }
  return path;
}

/// The inert body outline both views share — head, neck, torso, limbs.
final Path _silhouette = _union([
  _oval(50, 16, 22, 24), // head
  _rounded(45, 25, 10, 11, 3), // neck
  Path()
    ..moveTo(30, 34)
    ..lineTo(70, 34)
    ..lineTo(67, 80)
    ..lineTo(65, 118)
    ..lineTo(35, 118)
    ..lineTo(33, 80)
    ..close(), // torso
  _rounded(33, 112, 34, 22, 6), // pelvis
  _rounded(16, 42, 13, 44, 6), // upper arm, left
  _rounded(71, 42, 13, 44, 6), // upper arm, right
  _rounded(15, 86, 11, 42, 5), // forearm, left
  _rounded(74, 86, 11, 42, 5), // forearm, right
  _oval(20, 132, 11, 12), // hand, left
  _oval(80, 132, 11, 12), // hand, right
  _rounded(33, 128, 15, 50, 7), // thigh, left
  _rounded(52, 128, 15, 50, 7), // thigh, right
  _rounded(35, 176, 12, 38, 6), // calf, left
  _rounded(53, 176, 12, 38, 6), // calf, right
  _rounded(34, 211, 13, 7, 3), // foot, left
  _rounded(53, 211, 13, 7, 3), // foot, right
]);

Path _shouldersPath() => _union([_oval(27, 44, 18, 17), _oval(73, 44, 18, 17)]);

Path _armsPath() =>
    _union([_rounded(17, 54, 11, 30, 5), _rounded(72, 54, 11, 30, 5)]);

Path _legsPath() => _union([
  _rounded(34, 130, 13, 46, 6),
  _rounded(53, 130, 13, 46, 6),
  _rounded(36, 178, 10, 34, 5),
  _rounded(54, 178, 10, 34, 5),
]);

/// Regions are ordered smallest-area first so that where shapes overlap — the
/// deltoid caps sit over the top of the chest and back — a tap resolves to the
/// smaller, more specific group.
final List<_Region> _frontRegions = [
  _Region(BodyPart.shoulders, _shouldersPath()),
  _Region(BodyPart.biceps, _armsPath()),
  _Region(
    BodyPart.chest,
    _union([_rounded(31, 38, 18, 26, 6), _rounded(51, 38, 18, 26, 6)]),
  ),
  _Region(BodyPart.core, _rounded(36, 68, 28, 46, 8)),
  _Region(BodyPart.legs, _legsPath()),
];

final List<_Region> _backRegions = [
  _Region(BodyPart.shoulders, _shouldersPath()),
  _Region(BodyPart.triceps, _armsPath()),
  _Region(BodyPart.legs, _legsPath()),
  _Region(BodyPart.back, _rounded(31, 38, 38, 54, 8)),
];

List<_Region> _regionsFor(_View view) =>
    view == _View.front ? _frontRegions : _backRegions;

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Front and back body diagrams whose muscle groups filter the exercise list.
///
/// Groups holding no exercises are drawn inert; the selected group is filled
/// solid and outlined. Tapping the selected group again clears the filter, as
/// does tapping empty space around the figure.
///
/// [BodyPart.wholeBody] has no anatomical region — it is offered as a pill
/// beneath the figures instead, alongside a "Show all" reset.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
    this.figureHeight = 200,
  });

  final Map<BodyPart, int> counts;
  final BodyPart? selected;
  final ValueChanged<BodyPart?> onSelected;

  /// Height of each figure. Width follows from the design box's aspect ratio,
  /// so the pair stays a sensible size instead of filling the screen width.
  final double figureHeight;

  double get _figureWidth => figureHeight * _kDesignWidth / _kDesignHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildView(_View.front),
            const SizedBox(width: 20),
            _buildView(_View.back),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: _figureWidth, child: const _ViewLabel('FRONT')),
            const SizedBox(width: 20),
            SizedBox(width: _figureWidth, child: const _ViewLabel('BACK')),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _MapPill(
              label: BodyPart.wholeBody.label,
              color: BodyPart.wholeBody.color,
              isSelected: selected == BodyPart.wholeBody,
              isEnabled: (counts[BodyPart.wholeBody] ?? 0) > 0,
              onTap: () => onSelected(
                selected == BodyPart.wholeBody ? null : BodyPart.wholeBody,
              ),
            ),
            if (selected != null)
              _MapPill(
                label: 'Show all',
                color: OneRepColors.textSecondary,
                isSelected: false,
                isEnabled: true,
                onTap: () => onSelected(null),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildView(_View view) {
    final regions = _regionsFor(view);
    final scale = figureHeight / _kDesignHeight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final point = Offset(
          details.localPosition.dx / scale,
          details.localPosition.dy / scale,
        );
        for (final region in regions) {
          if (region.path.contains(point)) {
            onSelected(selected == region.part ? null : region.part);
            return;
          }
        }
        // A tap outside every muscle group clears the filter.
        onSelected(null);
      },
      child: SizedBox(
        width: _figureWidth,
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
            for (final region in regions) _semanticsFor(region, scale),
          ],
        ),
      ),
    );
  }

  Widget _semanticsFor(_Region region, double scale) {
    final bounds = region.path.getBounds();
    final count = counts[region.part] ?? 0;
    final plural = count == 1 ? 'exercise' : 'exercises';

    return Positioned(
      left: bounds.left * scale,
      top: bounds.top * scale,
      width: bounds.width * scale,
      height: bounds.height * scale,
      child: Semantics(
        button: true,
        selected: selected == region.part,
        label: '${region.part.label}, $count $plural',
        onTap: () => onSelected(selected == region.part ? null : region.part),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.view,
    required this.counts,
    required this.selected,
  });

  final _View view;
  final Map<BodyPart, int> counts;
  final BodyPart? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _kDesignWidth);

    canvas.drawPath(_silhouette, Paint()..color = OneRepColors.surfaceElevated);

    // Painted in reverse of the hit-test order, so the region that wins a tap
    // where two overlap is also the one drawn on top of the other.
    for (final region in _regionsFor(view).reversed) {
      final count = counts[region.part] ?? 0;
      final isSelected = selected == region.part;

      final Color fill;
      if (isSelected) {
        fill = region.part.color;
      } else if (count > 0) {
        fill = region.part.color.withValues(alpha: 0.35);
      } else {
        fill = OneRepColors.surfaceHighest;
      }
      canvas.drawPath(region.path, Paint()..color = fill);

      if (isSelected) {
        canvas.drawPath(
          region.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = OneRepColors.textPrimary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.selected != selected ||
      !mapEquals(oldDelegate.counts, counts);
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

class _ViewLabel extends StatelessWidget {
  final String text;

  const _ViewLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: OneRepColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _MapPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
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
          style: TextStyle(
            color: isEnabled
                ? OneRepColors.textPrimary
                : OneRepColors.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
