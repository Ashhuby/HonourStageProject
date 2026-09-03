import 'package:flutter/material.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/muscle.dart';

/// A form field that shows the chosen exercise and opens the picker on tap.
///
/// Styled with [InputDecorator] so it inherits the same theme as the
/// `DropdownButtonFormField`s it replaces and sits flush with the weight and
/// reps inputs beside it.
class ExerciseField extends StatelessWidget {
  const ExerciseField({
    super.key,
    required this.exercise,
    required this.onTap,
    this.label = 'Exercise',
    this.hint = 'Tap to choose',
  });

  final Exercise? exercise;
  final VoidCallback onTap;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final selected = exercise;

    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.fitness_center, size: 18),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      muscleForBodyPartOrNull(selected.bodyPart)?.color ??
                      OneRepColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                selected?.name ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected == null
                      ? OneRepColors.textSecondary
                      : OneRepColors.textPrimary,
                  fontSize: 15,
                  fontWeight: selected == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more,
              color: OneRepColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
