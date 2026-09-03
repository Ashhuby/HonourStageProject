import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/theme/app_colors.dart';
import '../data/badge_service.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import 'exercise_detail_screen.dart';
import 'widgets/body_map.dart';
import 'widgets/body_part.dart';
import 'widgets/exercise_filter.dart';
import 'widgets/exercise_list_tile.dart';

/// The Exercises tab: a tappable body diagram over the exercise list.
///
/// This screen is an `IndexedStack` child of `HomeScreen` and so has no AppBar
/// of its own — the diagram and search box live in the body, scrolling away
/// with the list rather than pinned above it.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  BodyPart? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Scaffold(
      body: exercisesAsync.when(
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

  Widget _buildLibrary(List<Exercise> exercises) {
    if (exercises.isEmpty) return const _EmptyState();

    final matches = filterExercises(
      exercises,
      query: _query,
      bodyPart: _selected,
    );
    final sections = groupExercisesByBodyPart(matches);

    // Flatten sections into header/exercise rows so one sliver renders them.
    final items = <Object>[];
    for (final section in sections) {
      items.add(section.title);
      items.addAll(section.exercises);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                BodyMap(
                  counts: countByBodyPart(exercises),
                  selected: _selected,
                  onSelected: (part) => setState(() => _selected = part),
                ),
                const SizedBox(height: 16),
                TextField(
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
              ],
            ),
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

    final exercise = item as Exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(exercise.id),
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
            .deleteExercise(exercise.id),
        child: ExerciseListTile(
          exercise: exercise,
          showPrCount: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(exercise: exercise),
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
    BodyPart? selectedBodyPart;
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
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Exercise Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BodyPart>(
                  initialValue: selectedBodyPart,
                  decoration: const InputDecoration(labelText: 'Body Part'),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: BodyPart.values
                      .map(
                        (bp) =>
                            DropdownMenuItem(value: bp, child: Text(bp.label)),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBodyPart = v),
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
                if (nameController.text.isNotEmpty &&
                    selectedBodyPart != null &&
                    selectedEquipment != null) {
                  await ref
                      .read(exerciseRepositoryProvider.notifier)
                      .addExercise(
                        nameController.text,
                        selectedBodyPart!.label,
                        selectedEquipment!,
                        metricType: selectedMetricType,
                      );

                  final prCount = await ref
                      .read(personalBestRepositoryProvider.notifier)
                      .getTotalPrCount();

                  await ref
                      .read(badgeServiceProvider.notifier)
                      .evaluateAll(totalPrCount: prCount);

                  if (context.mounted) Navigator.pop(context);
                }
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
