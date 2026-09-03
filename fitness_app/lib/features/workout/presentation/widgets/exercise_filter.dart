import '../../data/exercise_catalogue.dart';
import '../../domain/activity.dart';
import '../../domain/muscle.dart';

/// Filters the catalogue down to what a search box, a body-map selection and a
/// muscle chip currently ask for.
///
/// Pure and synchronous — the library is 41 seeded rows plus a handful of
/// custom ones, so filtering in Dart over the existing stream is cheaper than a
/// second query and keeps all of this unit-testable.
///
/// An exercise matches if it trains the muscle or group in *any* role, but
/// primary matches sort ahead of secondary ones: tapping Arms shows the curls
/// and pushdowns before Bench Press and Pull Ups.
///
/// [muscle] wins over [group] — the chip row narrows a diagram selection
/// rather than replacing it. When a [query] is set, the existing rule still
/// applies within each band: names *starting* with the query come before names
/// merely containing it.
///
/// [category] is a **pre-filter, never a sectioning axis**. Every exercise has
/// exactly one category, so narrowing to one is a subset operation and cannot
/// introduce a duplicate — which is what keeps [groupExercises] a partition.
List<ExerciseWithMuscles> filterExercises(
  List<ExerciseWithMuscles> all, {
  String query = '',
  ExerciseCategory? category,
  MuscleGroup? group,
  Muscle? muscle,
  Set<int> excludeIds = const {},

  /// When false only primary matches are kept, so the result is a strict
  /// partition across every possible filter value.
  bool includeSecondary = true,
}) {
  final needle = query.trim().toLowerCase();
  final matches = <(int rank, ExerciseWithMuscles exercise)>[];

  for (final entry in all) {
    if (excludeIds.contains(entry.id)) continue;
    if (category != null && entry.category != category) continue;
    if (needle.isNotEmpty && !entry.name.toLowerCase().contains(needle)) {
      continue;
    }

    final match = entry.matchFor(group: group, muscle: muscle);
    if (match == null) continue;
    if (match == MuscleMatch.secondary && !includeSecondary) continue;

    matches.add((match == MuscleMatch.primary ? 0 : 1, entry));
  }

  final isFiltered = group != null || muscle != null;
  if (needle.isEmpty && !isFiltered) {
    // Nothing to rank by — keep the stream's name ordering untouched.
    return [for (final match in matches) match.$2];
  }

  matches.sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (needle.isNotEmpty) {
      final aPrefix = a.$2.name.toLowerCase().startsWith(needle) ? 0 : 1;
      final bPrefix = b.$2.name.toLowerCase().startsWith(needle) ? 0 : 1;
      if (aPrefix != bPrefix) return aPrefix.compareTo(bPrefix);
    }
    return a.$2.name.compareTo(b.$2.name);
  });
  return [for (final match in matches) match.$2];
}

/// A run of exercises under one heading.
class ExerciseSection {
  const ExerciseSection({
    required this.title,
    required this.role,
    required this.exercises,
    this.group,
    this.muscle,
    this.modality,
  });

  final String title;

  /// The group, muscle or modality this section is headed by, for its heading
  /// tint. All null for "Unassigned".
  final MuscleGroup? group;
  final Muscle? muscle;
  final CardioModality? modality;

  /// Only meaningful when a filter is active; always [MuscleMatch.primary]
  /// otherwise.
  final MuscleMatch role;

  final List<ExerciseWithMuscles> exercises;
}

/// Groups [exercises] into sections such that **every exercise appears in
/// exactly one section**.
///
/// That invariant is not cosmetic. `ExerciseLibraryScreen` flattens these
/// sections into a single sliver and keys each row's `Dismissible` on
/// `exercise.id`, so an exercise emitted twice throws a duplicate-key error at
/// runtime. The rules below make that structurally impossible rather than
/// patching it with a composite key, which would also break dismissal state
/// across rebuilds.
///
/// Three modes, in precedence order:
///
/// * **Filtered by muscle or group** — sectioning by primary group would
///   misfile the results (tap Arms and Dips would appear under "Chest"), so
///   emit at most two sections mirroring the ranking: the primary matches
///   under the filter's own label, then the secondary matches under
///   "Also works …".
/// * **Cardio** — by [CardioModality], the one category whose second level is
///   not derivable from the muscles. Every cardio exercise has exactly one
///   modality, guaranteed by the database trigger, the seed's const assert and
///   [ExerciseWithMuscles.modality]'s total fallback — so this stays a
///   partition too.
/// * **Otherwise** — partition by the exercise's *primary* muscle group, in
///   [MuscleGroup] declaration order, alphabetical within, with a trailing
///   "Unassigned" for rows carrying no primary. Secondary muscles are ignored
///   for sectioning.
List<ExerciseSection> groupExercises(
  List<ExerciseWithMuscles> exercises, {
  ExerciseCategory? category,
  MuscleGroup? group,
  Muscle? muscle,
}) {
  final filterLabel = muscle?.label ?? group?.label;
  if (filterLabel != null) {
    final primary = <ExerciseWithMuscles>[];
    final secondary = <ExerciseWithMuscles>[];
    for (final entry in exercises) {
      final match = entry.matchFor(group: group, muscle: muscle);
      if (match == MuscleMatch.secondary) {
        secondary.add(entry);
      } else if (match == MuscleMatch.primary) {
        primary.add(entry);
      }
    }

    return [
      if (primary.isNotEmpty)
        ExerciseSection(
          title: filterLabel,
          group: group,
          muscle: muscle,
          role: MuscleMatch.primary,
          exercises: primary,
        ),
      if (secondary.isNotEmpty)
        ExerciseSection(
          title: 'Also works $filterLabel',
          group: group,
          muscle: muscle,
          role: MuscleMatch.secondary,
          exercises: secondary,
        ),
    ];
  }

  if (category != null && category.isSectionedByModality) {
    return _groupByModality(exercises);
  }

  final buckets = <MuscleGroup, List<ExerciseWithMuscles>>{};
  final unassigned = <ExerciseWithMuscles>[];

  for (final entry in exercises) {
    final primaryGroup = entry.primaryGroup;
    if (primaryGroup == null) {
      unassigned.add(entry);
    } else {
      buckets.putIfAbsent(primaryGroup, () => []).add(entry);
    }
  }

  final sections = <ExerciseSection>[];
  for (final candidate in MuscleGroup.values) {
    final bucket = buckets[candidate];
    if (bucket == null || bucket.isEmpty) continue;
    bucket.sort((a, b) => a.name.compareTo(b.name));
    sections.add(
      ExerciseSection(
        title: candidate.label,
        group: candidate,
        role: MuscleMatch.primary,
        exercises: bucket,
      ),
    );
  }
  if (unassigned.isNotEmpty) {
    unassigned.sort((a, b) => a.name.compareTo(b.name));
    sections.add(
      ExerciseSection(
        title: 'Unassigned',
        role: MuscleMatch.primary,
        exercises: unassigned,
      ),
    );
  }
  return sections;
}

/// Sections cardio by modality, in [CardioModality] declaration order.
List<ExerciseSection> _groupByModality(List<ExerciseWithMuscles> exercises) {
  final buckets = <CardioModality, List<ExerciseWithMuscles>>{};
  for (final entry in exercises) {
    final modality = entry.modality;
    if (modality == null) continue;
    buckets.putIfAbsent(modality, () => []).add(entry);
  }

  final sections = <ExerciseSection>[];
  for (final modality in CardioModality.values) {
    final bucket = buckets[modality];
    if (bucket == null || bucket.isEmpty) continue;
    bucket.sort((a, b) => a.name.compareTo(b.name));
    sections.add(
      ExerciseSection(
        title: modality.label,
        modality: modality,
        role: MuscleMatch.primary,
        exercises: bucket,
      ),
    );
  }
  return sections;
}

/// Counts exercises per cardio modality, for the chip row that stands in for
/// the body diagram under Cardio.
///
/// A plain count: the primary/total split is a muscle concept — an exercise
/// has one modality and no secondary ones.
Map<CardioModality, int> countByModality(List<ExerciseWithMuscles> exercises) {
  final counts = <CardioModality, int>{};
  for (final entry in exercises) {
    final modality = entry.modality;
    if (modality == null) continue;
    counts[modality] = (counts[modality] ?? 0) + 1;
  }
  return counts;
}

/// How many exercises sit in a group or muscle, counted two ways.
///
/// [primary] counts exercises whose primary muscle is here; those counts sum
/// to the library size, so it is the number worth showing. [total] counts
/// every exercise that trains it in any role — it double-counts by design and
/// must never be summed.
typedef MuscleCount = ({int primary, int total});

/// Counts per group, for shading and labelling the body diagram.
Map<MuscleGroup, MuscleCount> countByMuscleGroup(
  List<ExerciseWithMuscles> exercises,
) {
  final counts = <MuscleGroup, MuscleCount>{};

  void bump(MuscleGroup group, {required bool isPrimary}) {
    final current = counts[group] ?? (primary: 0, total: 0);
    counts[group] = (
      primary: current.primary + (isPrimary ? 1 : 0),
      total: current.total + 1,
    );
  }

  for (final entry in exercises) {
    final seen = <MuscleGroup>{};
    final primary = entry.primaryGroup;
    if (primary != null) {
      bump(primary, isPrimary: true);
      seen.add(primary);
    }
    // A group counts once per exercise however many of its muscles are hit.
    for (final muscle in entry.secondary) {
      if (seen.add(muscle.group)) bump(muscle.group, isPrimary: false);
    }
  }
  return counts;
}

/// Counts per muscle, for the chip row beneath the diagram.
Map<Muscle, MuscleCount> countByMuscle(List<ExerciseWithMuscles> exercises) {
  final counts = <Muscle, MuscleCount>{};

  void bump(Muscle muscle, {required bool isPrimary}) {
    final current = counts[muscle] ?? (primary: 0, total: 0);
    counts[muscle] = (
      primary: current.primary + (isPrimary ? 1 : 0),
      total: current.total + 1,
    );
  }

  for (final entry in exercises) {
    final primary = entry.primary;
    if (primary != null) bump(primary, isPrimary: true);
    for (final muscle in entry.secondary) {
      bump(muscle, isPrimary: false);
    }
  }
  return counts;
}
