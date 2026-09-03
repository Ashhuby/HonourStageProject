import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/muscle.dart';
import 'exercise_filter.dart';

/// The second level of the taxonomy: chips narrowing a selected group down to
/// one of its muscles.
///
/// This exists so the body diagram never has to offer a forearm or a calf as a
/// tap target. It appears only once a group is selected, and only when that
/// group has more than one muscle to choose between — which hides it for Full
/// Body, whose single chip would just repeat the heading.
///
/// A muscle with no exercises at all is shown disabled rather than omitted, so
/// the row does not reflow as the library grows — unless [counts] is null,
/// which means the row is choosing a muscle rather than filtering by one.
class MuscleChips extends StatelessWidget {
  const MuscleChips({
    super.key,
    required this.group,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final MuscleGroup group;
  final Muscle? selected;

  /// Null when choosing rather than filtering: every muscle is then a valid
  /// answer, so none is disabled.
  final Map<Muscle, MuscleCount>? counts;
  final ValueChanged<Muscle?> onSelected;

  @override
  Widget build(BuildContext context) {
    final muscles = group.muscles;
    if (muscles.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: muscles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final muscle = muscles[index];
          final total = counts?[muscle]?.total ?? 1;
          final isSelected = selected == muscle;

          return FilterChip(
            label: Text(muscle.label),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: muscle.color.withValues(alpha: 0.25),
            side: BorderSide(
              color: isSelected ? muscle.color : OneRepColors.surfaceHighest,
            ),
            labelStyle: TextStyle(
              color: total == 0
                  ? OneRepColors.textDisabled
                  : isSelected
                  ? OneRepColors.textPrimary
                  : OneRepColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: total == 0
                ? null
                : (_) => onSelected(isSelected ? null : muscle),
          );
        },
      ),
    );
  }
}
