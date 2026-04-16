import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/badge_service.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Scaffold(
      body: exercisesAsync.when(
        data: (exercises) {
          if (exercises.isEmpty) return _EmptyState();

          // Define display order for body part sections.
          const sectionOrder = [
            'Chest', 'Back', 'Legs', 'Shoulders',
            'Biceps', 'Triceps', 'Core', 'Whole Body',
          ];

          // Sort exercises: first by sectionOrder, then alphabetically within.
          final sorted = [...exercises];
          sorted.sort((a, b) {
            final ai = sectionOrder.indexOf(a.bodyPart);
            final bi = sectionOrder.indexOf(b.bodyPart);
            final aIdx = ai == -1 ? sectionOrder.length : ai;
            final bIdx = bi == -1 ? sectionOrder.length : bi;
            if (aIdx != bIdx) return aIdx.compareTo(bIdx);
            return a.name.compareTo(b.name);
          });

          // Build flat list of section headers + exercise cards.
          final items = <_LibraryItem>[];
          String? lastBodyPart;
          for (final exercise in sorted) {
            if (exercise.bodyPart != lastBodyPart) {
              items.add(_LibraryItem.header(exercise.bodyPart));
              lastBodyPart = exercise.bodyPart;
            }
            items.add(_LibraryItem.exercise(exercise));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isHeader) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    item.header!.toUpperCase(),
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                );
              }
              final exercise = item.exercise!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExerciseCard(
                  exercise: exercise,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExerciseDetailScreen(exercise: exercise),
                    ),
                  ),
                  onDelete: () => ref
                      .read(exerciseRepositoryProvider.notifier)
                      .deleteExercise(exercise.id),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
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

  static const _bodyParts = [
    'Chest', 'Back', 'Legs', 'Shoulders',
    'Biceps', 'Triceps', 'Core', 'Whole Body',
  ];

  static const _equipment = [
    'Barbell', 'Dumbbell', 'Cable', 'Machine',
    'Body Weight', 'Kettlebell', 'Resistance Band', 'Other',
  ];

  static const _metricTypes = [
    ('weightReps', 'Weight + Reps'),
    ('bodyweightReps', 'Bodyweight Reps'),
    ('timeOnly', 'Time Only (e.g. Plank)'),
    ('distanceTime', 'Distance + Time (e.g. Run)'),
  ];

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String? selectedBodyPart;
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
                DropdownButtonFormField<String>(
                  initialValue: selectedBodyPart,
                  decoration: const InputDecoration(labelText: 'Body Part'),
                  dropdownColor: OneRepColors.surfaceElevated,
                  items: _bodyParts
                      .map((bp) => DropdownMenuItem(value: bp, child: Text(bp)))
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
                      .map((mt) => DropdownMenuItem(
                            value: mt.$1,
                            child: Text(mt.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedMetricType = v ?? 'weightReps'),
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
                        selectedBodyPart!,
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
// Library list item — either a section header or an exercise card
// ---------------------------------------------------------------------------

class _LibraryItem {
  final bool isHeader;
  final String? header;
  final dynamic exercise;

  const _LibraryItem._({required this.isHeader, this.header, this.exercise});

  factory _LibraryItem.header(String title) =>
      _LibraryItem._(isHeader: true, header: title);

  factory _LibraryItem.exercise(dynamic ex) =>
      _LibraryItem._(isHeader: false, exercise: ex);
}

// ---------------------------------------------------------------------------
// Exercise card — body part colour dot, no avatar
// ---------------------------------------------------------------------------

class _ExerciseCard extends ConsumerWidget {
  final dynamic exercise;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodyPartColor = _bodyPartColor(exercise.bodyPart as String);
    final prsAsync =
        ref.watch(watchPrsForExerciseProvider(exercise.id as int));

    return Dismissible(
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
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: OneRepColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: bodyPartColor, width: 3),
            ),
          ),
          child: Row(
            children: [
              // Body part colour dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: bodyPartColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          exercise.name as String,
                          style: const TextStyle(
                            color: OneRepColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (exercise.isCustom == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: OneRepColors.gold
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM',
                              style: TextStyle(
                                color: OneRepColors.gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.bodyPart} • ${exercise.equipmentType}',
                      style: const TextStyle(
                        color: OneRepColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // PR count badge
              prsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (prs) {
                  if (prs.isEmpty) {
                    return const Icon(
                      Icons.chevron_right,
                      color: OneRepColors.textDisabled,
                      size: 18,
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OneRepColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: OneRepColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${prs.length} PR${prs.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: OneRepColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        color: OneRepColors.textDisabled,
                        size: 18,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps body part string to a colour from OneRepColors.
  Color _bodyPartColor(String bodyPart) {
    return switch (bodyPart.toLowerCase()) {
      'chest' => OneRepColors.chest,
      'back' => OneRepColors.back,
      'legs' => OneRepColors.legs,
      'shoulders' => OneRepColors.shoulders,
      'biceps' => OneRepColors.biceps,
      'triceps' => OneRepColors.triceps,
      'core' => OneRepColors.core,
      'whole body' => OneRepColors.wholeBody,
      _ => OneRepColors.textSecondary,
    };
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
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
              style: TextStyle(
                color: OneRepColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}