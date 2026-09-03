import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/badge_service.dart';
import '../data/exercise_catalogue.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import '../domain/activity.dart';
import '../domain/muscle.dart';
import 'exercise_detail_screen.dart';
import 'widgets/body_map.dart';
import 'widgets/category_chips.dart';
import 'widgets/exercise_filter.dart';
import 'widgets/exercise_list_tile.dart';
import 'widgets/muscle_chips.dart';

/// The Exercises tab: a tappable body diagram over the exercise list.
///
/// This screen is an `IndexedStack` child of `HomeScreen` and so has no AppBar
/// of its own — the diagram and search box live in the body, scrolling away
/// with the list rather than pinned above it.
///
/// Browsing is three levels. A category row scopes everything below it; the
/// diagram then selects a [MuscleGroup], and the chip row that appears narrows
/// to a single [Muscle]. Nothing on the diagram is ever smaller than a
/// fingertip, which is what makes forearms and calves reachable at all.
///
/// Cardio is the exception: it swaps the diagram for [ModalityChips], because
/// you look for the rowers rather than for your lats. Strength and Mobility
/// both keep the diagram — a stretch is looked up by the muscle it targets.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ExerciseCategory? _category;
  CardioModality? _modality;
  MuscleGroup? _group;
  Muscle? _muscle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(watchExerciseCatalogueProvider);

    return Scaffold(
      body: catalogueAsync.when(
        data: _buildLibrary,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exercise_fab',
        onPressed: () => _showAddExerciseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD EXERCISE',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildLibrary(List<ExerciseWithMuscles> catalogue) {
    if (catalogue.isEmpty) return const _EmptyState();

    // Counts are computed over the category-filtered pool, so the diagram
    // under Mobility shows mobility counts rather than the whole library's.
    final inCategory = _category == null
        ? catalogue
        : [
            for (final e in catalogue)
              if (e.category == _category) e,
          ];

    final matches = filterExercises(
      catalogue,
      query: _query,
      category: _category,
      group: _group,
      muscle: _muscle,
    ).where((e) => _modality == null || e.modality == _modality).toList();

    final sections = groupExercises(
      matches,
      category: _category,
      group: _group,
      muscle: _muscle,
    );

    // Flatten sections into header/exercise rows so one sliver renders them.
    // groupExercises guarantees each exercise appears in exactly one section,
    // which is what keeps the Dismissible keys below unique.
    final items = <Object>[];
    for (final section in sections) {
      items.add(section.title);
      items.addAll(section.exercises);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              CategoryChips(
                selected: _category,
                counts: _categoryCounts(catalogue),
                onSelected: (category) => setState(() {
                  _category = category;
                  // A new category abandons everything narrowed within the
                  // old one, mirroring how a new group abandons its muscle.
                  _modality = null;
                  _group = null;
                  _muscle = null;
                }),
              ),
              if (_category?.isSectionedByModality ?? false) ...[
                const SizedBox(height: 4),
                ModalityChips(
                  selected: _modality,
                  counts: countByModality(inCategory),
                  onSelected: (modality) =>
                      setState(() => _modality = modality),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: BodyMap(
                    counts: countByMuscleGroup(inCategory),
                    selected: _group,
                    onSelected: (group) => setState(() {
                      _group = group;
                      // A new group abandons the muscle narrowed within it.
                      _muscle = null;
                    }),
                  ),
                ),
                if (_group != null) ...[
                  const SizedBox(height: 12),
                  MuscleChips(
                    group: _group!,
                    selected: _muscle,
                    counts: countByMuscle(inCategory),
                    onSelected: (muscle) => setState(() => _muscle = muscle),
                  ),
                ],
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search exercises',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const SliverToBoxAdapter(child: _NoMatches())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _buildItem(items[index]),
            ),
          ),
      ],
    );
  }

  Map<ExerciseCategory, int> _categoryCounts(
    List<ExerciseWithMuscles> catalogue,
  ) {
    final counts = <ExerciseCategory, int>{};
    for (final entry in catalogue) {
      counts[entry.category] = (counts[entry.category] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildItem(Object item) {
    if (item is String) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          item.toUpperCase(),
          style: const TextStyle(
            color: OneRepColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    final entry = item as ExerciseWithMuscles;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: OneRepColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: OneRepColors.error),
        ),
        onDismissed: (_) => ref
            .read(exerciseRepositoryProvider.notifier)
            .deleteExercise(entry.id),
        child: ExerciseListTile(
          entry: entry,
          showPrCount: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(entry: entry),
            ),
          ),
        ),
      ),
    );
  }

  static const _equipment = [
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Body Weight',
    'Kettlebell',
    'Resistance Band',
    'Other',
  ];

  static const _metricTypes = [
    ('weightReps', 'Weight + Reps'),
    ('bodyweightReps', 'Bodyweight Reps'),
    ('timeOnly', 'Time Only (e.g. Plank)'),
    ('distanceTime', 'Distance + Time (e.g. Run)'),
  ];

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    var category = ExerciseCategory.strength;
    CardioModality? modality;
    Muscle? primary;
    final secondary = <Muscle>{};
    String? selectedEquipment;
    String selectedMetricType = 'weightReps';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Exercise Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExerciseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    helperText: 'What kind of training this is',
                  ),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: [
                    for (final option in ExerciseCategory.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    category = value ?? ExerciseCategory.strength;
                    // The trigger and the repository both require modality to
                    // be present exactly when the category is cardio.
                    modality = category.isSectionedByModality
                        ? (modality ?? CardioModality.other)
                        : null;
                    selectedMetricType = switch (category) {
                      ExerciseCategory.cardio => 'distanceTime',
                      ExerciseCategory.mobility => 'timeOnly',
                      ExerciseCategory.strength => 'weightReps',
                    };
                  }),
                ),
                if (category.isSectionedByModality) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CardioModality>(
                    initialValue: modality,
                    decoration: const InputDecoration(
                      labelText: 'Kind',
                      helperText: 'Where this is filed under Cardio',
                    ),
                    dropdownColor: OneRepColors.surfaceElevated,
                    items: [
                      for (final option in CardioModality.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => modality = value ?? CardioModality.other,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<Muscle>(
                  initialValue: primary,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Main muscle',
                    helperText: 'Where this exercise is filed',
                  ),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: [
                    for (final group in MuscleGroup.values)
                      for (final muscle in group.muscles)
                        DropdownMenuItem(
                          value: muscle,
                          child: Text('${group.label} • ${muscle.label}'),
                        ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    primary = value;
                    // The primary can never also be a secondary.
                    secondary.remove(value);
                  }),
                ),
                const SizedBox(height: 16),
                _SecondaryMusclePicker(
                  primary: primary,
                  selected: secondary,
                  onToggle: (muscle) => setDialogState(() {
                    if (!secondary.remove(muscle)) secondary.add(muscle);
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedEquipment,
                  decoration: const InputDecoration(labelText: 'Equipment'),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: _equipment
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedEquipment = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMetricType,
                  decoration: const InputDecoration(labelText: 'Metric Type'),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: _metricTypes
                      .map(
                        (mt) =>
                            DropdownMenuItem(value: mt.$1, child: Text(mt.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(
                    () => selectedMetricType = v ?? 'weightReps',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    primary == null ||
                    selectedEquipment == null) {
                  return;
                }

                await ref
                    .read(exerciseRepositoryProvider.notifier)
                    .addExercise(
                      nameController.text,
                      selectedEquipment!,
                      primary: primary!,
                      secondary: secondary,
                      metricType: selectedMetricType,
                      category: category,
                      modality: modality,
                    );

                final prCount = await ref
                    .read(personalBestRepositoryProvider.notifier)
                    .getTotalPrCount();

                await ref
                    .read(badgeServiceProvider.notifier)
                    .evaluateAll(totalPrCount: prCount);

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary muscles
// ---------------------------------------------------------------------------

/// Multi-select for the muscles an exercise also works.
///
/// Optional by design: leaving it empty is a legitimate answer for an isolation
/// movement, and several of the seeded exercises have no secondaries at all.
class _SecondaryMusclePicker extends StatelessWidget {
  const _SecondaryMusclePicker({
    required this.primary,
    required this.selected,
    required this.onToggle,
  });

  final Muscle? primary;
  final Set<Muscle> selected;
  final ValueChanged<Muscle> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ALSO WORKS',
          style: TextStyle(
            color: OneRepColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final muscle in Muscle.values)
              if (muscle != primary)
                FilterChip(
                  label: Text(muscle.label),
                  selected: selected.contains(muscle),
                  showCheckmark: false,
                  selectedColor: muscle.color.withValues(alpha: 0.25),
                  side: BorderSide(
                    color: selected.contains(muscle)
                        ? muscle.color
                        : OneRepColors.surfaceHighest,
                  ),
                  labelStyle: TextStyle(
                    color: selected.contains(muscle)
                        ? OneRepColors.textPrimary
                        : OneRepColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onToggle(muscle),
                ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(40, 48, 40, 40),
      child: Column(
        children: [
          Icon(Icons.search_off, color: OneRepColors.textDisabled, size: 40),
          SizedBox(height: 12),
          Text(
            'No exercises match.',
            style: TextStyle(color: OneRepColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              color: OneRepColors.textDisabled,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No exercises yet.',
              style: TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap Add Exercise to build your library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: OneRepColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
