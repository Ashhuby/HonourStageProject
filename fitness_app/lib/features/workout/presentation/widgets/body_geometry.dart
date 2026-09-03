import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';

import '../../domain/muscle.dart';
import 'body_paths.g.dart';

/// Which way the figure faces.
enum BodyView { front, back }

/// The coordinate space the vendored path data is authored in.
///
/// Front and back share one canvas in the source artwork, so each view is
/// drawn with its own horizontal origin and both use the same height. These
/// numbers are measured from the parsed path bounds, not guessed: front
/// content spans x 0.0-31.5, back x 36.5-68.6, and both span y 0.0-92.6.
const double kDesignHeight = 93;
const double _frontOriginX = 0;
const double _frontWidth = 32;
const double _backOriginX = 36;
const double _backWidth = 33;

/// Width of one figure in design units, for the view's aspect ratio.
double designWidthFor(BodyView view) =>
    view == BodyView.front ? _frontWidth : _backWidth;

double designOriginFor(BodyView view) =>
    view == BodyView.front ? _frontOriginX : _backOriginX;

/// Turns an SVG `d` string into a [Path].
///
/// [PathProxy] is `path_parsing`'s callback interface; it emits normalised
/// segments, so only these four commands ever arrive.
class _PathBuilder extends PathProxy {
  _PathBuilder(this.path);

  final Path path;

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

/// Parses and unions a list of `d` strings into one [Path].
///
/// Subpaths are added rather than boolean-unioned; with the default non-zero
/// fill rule that reads as a union for both painting and [Path.contains],
/// which is all this needs.
Path _parseAll(Iterable<String> data) {
  final path = Path();
  for (final d in data) {
    final part = Path();
    writeSvgPathDataToPath(d, _PathBuilder(part));
    path.addPath(part, Offset.zero);
  }
  return path;
}

Map<Muscle, Path>? _frontMuscles;
Map<Muscle, Path>? _backMuscles;
Path? _frontInert;
Path? _backInert;

Map<Muscle, Path> _buildMuscles(Map<String, List<String>> source) {
  final built = <Muscle, Path>{};
  source.forEach((name, data) {
    final muscle = Muscle.byNameOrNull(name);
    if (muscle != null) built[muscle] = _parseAll(data);
  });
  return built;
}

/// One [Path] per muscle drawn in [view].
///
/// Parsed once on first use and cached — roughly 100 path strings in total,
/// which is cheap but not worth repeating on every rebuild.
Map<Muscle, Path> musclePathsFor(BodyView view) {
  if (view == BodyView.front) {
    return _frontMuscles ??= _buildMuscles(kFrontMusclePaths);
  }
  return _backMuscles ??= _buildMuscles(kBackMusclePaths);
}

/// The head, hands, feet, joints and out-of-vocabulary muscles, as one path.
/// Drawn flat beneath the regions and never hit-tested.
Path inertPathFor(BodyView view) {
  if (view == BodyView.front) {
    return _frontInert ??= _parseAll(kFrontInertPaths);
  }
  return _backInert ??= _parseAll(kBackInertPaths);
}

/// The tappable regions of [view]: one path per [MuscleGroup], unioned from
/// the muscles of that group which this view actually shows.
///
/// Groups rather than muscles, deliberately. Seven regions on two figures are
/// all comfortably fingertip-sized; a forearm or a calf is not, so the chip
/// row below the diagram — not the diagram — is where those are chosen.
Map<MuscleGroup, Path> groupRegionsFor(BodyView view) {
  final muscles = musclePathsFor(view);
  final regions = <MuscleGroup, Path>{};

  for (final entry in muscles.entries) {
    final group = entry.key.group;
    final existing = regions[group];
    if (existing == null) {
      regions[group] = Path()..addPath(entry.value, Offset.zero);
    } else {
      existing.addPath(entry.value, Offset.zero);
    }
  }
  return regions;
}

/// Groups ordered smallest-area-first, so that where two overlap a tap
/// resolves to the more specific one.
///
/// Bounding-box area stands in for true area: it is cheap, stable, and the
/// ordering only has to be roughly right to feel correct under a thumb.
List<MuscleGroup> hitOrderFor(BodyView view) {
  final regions = groupRegionsFor(view);
  final ordered = regions.keys.toList()
    ..sort((a, b) {
      final aBounds = regions[a]!.getBounds();
      final bBounds = regions[b]!.getBounds();
      return (aBounds.width * aBounds.height).compareTo(
        bBounds.width * bBounds.height,
      );
    });
  return ordered;
}
