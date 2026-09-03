import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/activity.dart';

/// The top level of the taxonomy: Strength, Cardio or Mobility.
///
/// Everything below this row is scoped by it, which is why it sits above the
/// body diagram rather than beneath — anything below the diagram reads as
/// narrowing a muscle selection, which is what the muscle chips already mean.
///
/// "All" is the default and behaves exactly as the library did before
/// categories existed: one list, sectioned by muscle group. That matters
/// because someone hunting for Bench Press should not have to know which
/// category it is in.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final ExerciseCategory? selected;

  /// How many exercises each category holds. A category with none is hidden
  /// rather than shown empty.
  final Map<ExerciseCategory, int> counts;

  final ValueChanged<ExerciseCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final present = ExerciseCategory.values
        .where((category) => (counts[category] ?? 0) > 0)
        .toList();
    // One category is not a choice.
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: present.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _chip(
              label: 'All',
              color: OneRepColors.accent,
              isSelected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final category = present[index - 1];
          return _chip(
            label: category.label,
            color: category.color,
            isSelected: selected == category,
            onTap: () => onSelected(selected == category ? null : category),
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.25),
      side: BorderSide(color: isSelected ? color : OneRepColors.surfaceHighest),
      labelStyle: TextStyle(
        color: isSelected
            ? OneRepColors.textPrimary
            : OneRepColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// The second level for Cardio, standing in for the body diagram.
///
/// Cardio is the one category whose sections are not anatomical: you look for
/// the rowers, not for your lats. Strength and Mobility both keep the diagram.
class ModalityChips extends StatelessWidget {
  const ModalityChips({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final CardioModality? selected;
  final Map<CardioModality, int> counts;
  final ValueChanged<CardioModality?> onSelected;

  @override
  Widget build(BuildContext context) {
    final present = CardioModality.values
        .where((modality) => (counts[modality] ?? 0) > 0)
        .toList();
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: present.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final modality = present[index];
          final isSelected = selected == modality;
          return FilterChip(
            label: Text('${modality.label}  ${counts[modality]}'),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: modality.color.withValues(alpha: 0.25),
            side: BorderSide(
              color: isSelected ? modality.color : OneRepColors.surfaceHighest,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? OneRepColors.textPrimary
                  : OneRepColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => onSelected(isSelected ? null : modality),
          );
        },
      ),
    );
  }
}
