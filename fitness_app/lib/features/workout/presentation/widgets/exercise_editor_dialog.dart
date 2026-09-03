import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/badge_service.dart';
import '../../data/exercise_catalogue.dart';
import '../../data/exercise_repository.dart';
import '../../data/personal_best_repository.dart';
import '../../domain/activity.dart';
import '../../domain/muscle.dart';

/// Creates a custom exercise, or re-files an existing one.
///
/// One dialog for both, because they ask the same questions. The edit path is
/// what makes the v10 category backfill survivable: it files custom exercises
/// from their metric type and says openly that it will misfile a loaded carry
/// logged by distance, and until now there was no way to correct one.
///
/// [existing] null creates; otherwise edits. Returns true if anything was
/// written.
Future<bool> showExerciseEditor(
  BuildContext context,
  WidgetRef ref, {
  ExerciseWithMuscles? existing,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ExerciseEditorDialog(existing: existing),
  );
  return result ?? false;
}

class _ExerciseEditorDialog extends ConsumerStatefulWidget {
  const _ExerciseEditorDialog({required this.existing});

  final ExerciseWithMuscles? existing;

  @override
  ConsumerState<_ExerciseEditorDialog> createState() =>
      _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends ConsumerState<_ExerciseEditorDialog> {
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

  late final TextEditingController _nameController;
  late ExerciseCategory _category;
  CardioModality? _modality;
  Muscle? _primary;
  late Set<Muscle> _secondary;
  String? _equipmentType;
  String _metricType = 'weightReps';
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _category = existing?.category ?? ExerciseCategory.strength;
    _modality = existing?.modality;
    _primary = existing?.primary;
    _secondary = {...?existing?.secondary};
    _equipmentType = existing?.exercise.equipmentType;
    _metricType = existing?.exercise.metricType ?? 'weightReps';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Exercise' : 'New Exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(labelText: 'Exercise Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ExerciseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Activity',
                helperText: 'What kind of training this is',
              ),
              dropdownColor: OneRepColors.surfaceElevated,
              items: [
                for (final option in ExerciseCategory.values)
                  DropdownMenuItem(value: option, child: Text(option.label)),
              ],
              onChanged: (value) => setState(() {
                _category = value ?? ExerciseCategory.strength;
                // Modality is required exactly when the category is cardio —
                // the same rule the database trigger enforces.
                _modality = _category.isSectionedByModality
                    ? (_modality ?? CardioModality.other)
                    : null;
                if (!_isEditing) {
                  _metricType = switch (_category) {
                    ExerciseCategory.cardio => 'distanceTime',
                    ExerciseCategory.mobility => 'timeOnly',
                    ExerciseCategory.strength => 'weightReps',
                  };
                }
              }),
            ),
            if (_category.isSectionedByModality) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<CardioModality>(
                initialValue: _modality,
                decoration: const InputDecoration(
                  labelText: 'Kind',
                  helperText: 'Where this is filed under Cardio',
                ),
                dropdownColor: OneRepColors.surfaceElevated,
                items: [
                  for (final option in CardioModality.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) =>
                    setState(() => _modality = value ?? CardioModality.other),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<Muscle>(
              initialValue: _primary,
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
              onChanged: (value) => setState(() {
                _primary = value;
                _secondary.remove(value);
              }),
            ),
            const SizedBox(height: 16),
            _SecondaryMusclePicker(
              primary: _primary,
              selected: _secondary,
              onToggle: (muscle) => setState(() {
                if (!_secondary.remove(muscle)) _secondary.add(muscle);
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _equipmentType,
              decoration: const InputDecoration(labelText: 'Equipment'),
              dropdownColor: OneRepColors.surfaceElevated,
              items: _equipment
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => _equipmentType = value),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              // Changing how an exercise is measured would invalidate every
              // record computed under the old comparator, so it is shown but
              // not editable rather than silently rebuilding the user's
              // personal bests underneath them.
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Measured by',
                  helperText: 'Set when the exercise was created',
                ),
                child: Text(
                  _metricTypes.firstWhere((mt) => mt.$1 == _metricType).$2,
                  style: const TextStyle(
                    color: OneRepColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _metricType,
                decoration: const InputDecoration(labelText: 'Metric Type'),
                dropdownColor: OneRepColors.surfaceElevated,
                items: _metricTypes
                    .map(
                      (mt) =>
                          DropdownMenuItem(value: mt.$1, child: Text(mt.$2)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _metricType = value ?? 'weightReps'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: OneRepColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    // The old dialog returned silently on invalid input, so the button simply
    // did nothing and never said why.
    final name = _nameController.text.trim();
    final primary = _primary;
    final equipment = _equipmentType;
    if (name.isEmpty) {
      setState(() => _error = 'Give the exercise a name.');
      return;
    }
    if (primary == null) {
      setState(() => _error = 'Choose the main muscle it works.');
      return;
    }
    if (equipment == null) {
      setState(() => _error = 'Choose the equipment it uses.');
      return;
    }

    final repository = ref.read(exerciseRepositoryProvider.notifier);
    final existing = widget.existing;

    if (existing == null) {
      await repository.addExercise(
        name,
        equipment,
        primary: primary,
        secondary: _secondary,
        metricType: _metricType,
        category: _category,
        modality: _modality,
      );

      final prCount = await ref
          .read(personalBestRepositoryProvider.notifier)
          .getTotalPrCount();
      await ref
          .read(badgeServiceProvider.notifier)
          .evaluateAll(totalPrCount: prCount);
    } else {
      await repository.updateExercise(
        existing.id,
        name: name,
        equipmentType: equipment,
        category: _category,
        modality: _modality,
        primary: primary,
        secondary: _secondary,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }
}

/// Multi-select for the muscles an exercise also works.
///
/// Optional by design: leaving it empty is a legitimate answer for an
/// isolation movement, and several seeded exercises have no secondaries.
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
