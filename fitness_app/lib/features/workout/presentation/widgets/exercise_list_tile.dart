import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/exercise_catalogue.dart';
import '../../data/personal_best_repository.dart';

/// One exercise row: muscle-colour edge, name, primary muscle and equipment.
///
/// Shared by the exercise library and the picker sheet so both read the same.
/// The PR-count badge costs a provider watch per visible row, so it is opt-in
/// via [showPrCount] — the library shows it, the picker does not.
///
/// The subtitle names the primary *muscle* rather than its group: "Lats •
/// Barbell" is more use than "Back • Barbell", and it is the distinction the
/// old single-value taxonomy could not draw.
class ExerciseListTile extends ConsumerWidget {
  const ExerciseListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.showPrCount = false,
    this.trailingLabel,
  });

  final ExerciseWithMuscles entry;
  final VoidCallback onTap;
  final bool showPrCount;

  /// Optional right-aligned text, e.g. a routine's `3 × 10` target.
  final String? trailingLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = entry.exercise;
    final accent = entry.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          exercise.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: OneRepColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (exercise.isCustom) ...[
                        const SizedBox(width: 8),
                        const _CustomPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.muscleLabel} • ${exercise.equipmentType}',
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: const TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (showPrCount)
              _PrCountBadge(exerciseId: exercise.id)
            else
              const Icon(
                Icons.chevron_right,
                color: OneRepColors.textDisabled,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomPill extends StatelessWidget {
  const _CustomPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: OneRepColors.gold.withValues(alpha: 0.15),
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
    );
  }
}

class _PrCountBadge extends ConsumerWidget {
  final int exerciseId;

  const _PrCountBadge({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(watchPrsForExerciseProvider(exerciseId));

    return prsAsync.when(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }
}
