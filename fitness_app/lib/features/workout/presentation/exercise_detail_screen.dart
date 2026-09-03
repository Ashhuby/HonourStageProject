import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/set_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/profile/data/profile_provider.dart';
import 'package:fitness_app/features/workout/data/strength_standards_data.dart';
import '../data/exercise_catalogue.dart';
import '../domain/progress_series.dart';
import 'widgets/exercise_editor_dialog.dart';
import '../data/personal_best_repository.dart';
import '../data/session_repository.dart';
import 'package:fitness_app/features/profile/presentation/profile_screen.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  /// The exercise together with the muscles it trains.
  ///
  /// Carries the whole catalogue entry rather than a bare [Exercise] so the
  /// subtitle can name the primary muscle and list the secondaries. `bodyPart`
  /// alone would say "Arms" where "Biceps, also Forearms" is the useful thing.
  final ExerciseWithMuscles entry;

  const ExerciseDetailScreen({super.key, required this.entry});

  Exercise get exercise => entry.exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(watchPrsForExerciseProvider(exercise.id));
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit exercise',
            onPressed: () async {
              final changed = await showExerciseEditor(
                context,
                ref,
                existing: entry,
              );
              // The screen holds the entry it was pushed with, so a rename or
              // a re-file would otherwise keep showing the old values.
              if (changed && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----------------------------------------------------------------
          // Exercise metadata
          // ----------------------------------------------------------------
          _SectionHeader(title: exercise.name),
          const SizedBox(height: 4),
          Text(
            '${entry.muscleLabel} • ${exercise.equipmentType}',
            style: const TextStyle(color: OneRepColors.textSecondary),
          ),
          if (entry.secondary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Also works ${entry.secondary.map((m) => m.label).join(', ')}',
                style: const TextStyle(
                  color: OneRepColors.textDisabled,
                  fontSize: 12,
                ),
              ),
            ),
          if (exercise.isCustom)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Chip(
                label: Text('Custom Exercise'),
                padding: EdgeInsets.zero,
              ),
            ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Personal records
          // ----------------------------------------------------------------
          const _SectionHeader(title: 'Personal Records'),
          const SizedBox(height: 12),
          prsAsync.when(
            data: (prs) => prs.isEmpty
                ? const _EmptyState(
                    message:
                        'No personal records yet.\nLog sets for this exercise to track your PRs.',
                  )
                : _PrList(prs: prs),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Strength percentile — only shown when profile is complete
          // ----------------------------------------------------------------
          profileAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              if (!profile.isCompleteForPercentile) {
                return _PercentileUnavailable(exerciseName: exercise.name);
              }
              // Gate on what the exercise *is*, not on whether its name
              // happens to miss the standards table. A custom timeOnly
              // exercise called "Squat" would otherwise be handed a percentile
              // computed from a weight it never recorded.
              if (!entry.hasStrengthPercentile) {
                return const SizedBox.shrink();
              }
              return _PercentileSection(exercise: exercise, profile: profile);
            },
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Progress chart — the series depends on how the exercise is
          // measured. Volume is meaningful only for weightReps; for the other
          // three it is identically zero.
          // ----------------------------------------------------------------
          _SectionHeader(title: detailMetricFor(exercise.metricType).heading),
          const SizedBox(height: 12),
          _ProgressChart(exerciseId: exercise.id),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR list
// ---------------------------------------------------------------------------

/// The personal records held for an exercise.
///
/// Most exercises hold exactly one record. Distance-and-time exercises hold
/// one per distance, since a 400m time and a 5k time are separate
/// achievements.
class _PrList extends StatelessWidget {
  final List<PersonalBest> prs;

  const _PrList({required this.prs});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final pr in prs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: OneRepColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      formatPersonalBest(pr),
                      style: const TextStyle(
                        color: OneRepColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatShortDate(pr.achievedAt),
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strength percentile section
// ---------------------------------------------------------------------------

class _PercentileSection extends ConsumerWidget {
  final Exercise exercise;
  final UserProfile profile;

  const _PercentileSection({required this.exercise, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestLiftAsync = ref.watch(
      getBestLiftForExerciseProvider(exercise.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Strength Percentile'),
        const SizedBox(height: 12),
        bestLiftAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (bestLift) {
            if (bestLift == null) {
              return const _EmptyState(
                message:
                    'Log sets for this exercise to see your strength percentile.',
              );
            }

            final result = calculatePercentile(
              exerciseName: exercise.name,
              sex: profile.sex!,
              bodyweightKg: profile.bodyweightKg!,
              liftKg: bestLift.weight,
            );

            if (result == null) return const SizedBox.shrink();

            return _PercentileCard(
              exerciseName: exercise.name,
              liftKg: bestLift.weight,
              reps: bestLift.reps,
              result: result,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PercentileCard extends StatelessWidget {
  final String exerciseName;
  final double liftKg;
  final int reps;
  final StrengthPercentileResult result;

  const _PercentileCard({
    required this.exerciseName,
    required this.liftKg,
    required this.reps,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = result.percentile;

    // Pick a colour that reflects the level intuitively.
    final levelColor = switch (result.label) {
      'Elite' => Colors.purple,
      'Advanced' => Colors.blue,
      'Intermediate' => Colors.green,
      'Novice' => Colors.orange,
      _ => Colors.grey,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline
            Text(
              'Your best $exerciseName (${liftKg}kg × $reps reps) is '
              'stronger than approximately $pct% of lifters.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 12,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(levelColor),
              ),
            ),
            const SizedBox(height: 8),

            // Label + percentile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: levelColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    result.label,
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  'Top ${100 - pct}%',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Attribution
            const Text(
              'Data sourced from Strengthlevel.com',
              style: TextStyle(color: OneRepColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentileUnavailable extends StatelessWidget {
  final String exerciseName;

  const _PercentileUnavailable({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    // Only show this nudge if the exercise actually has standards data.
    // No point nudging the user to set up their profile for Cable Fly.
    if (!hasStrengthStandards(exerciseName)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Set up your profile'),
          subtitle: const Text(
            'Add your bodyweight and sex to see how your lifts '
            'compare to the general population.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume chart — reused from progress_screen.dart, scoped to one exercise
// ---------------------------------------------------------------------------

class _ProgressChart extends ConsumerWidget {
  final int exerciseId;

  const _ProgressChart({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(
      getProgressSeriesForExerciseProvider(exerciseId),
    );

    return SizedBox(
      height: 200,
      child: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (progress) {
          if (progress.points.isEmpty) {
            return const _EmptyState(message: 'No data yet for this exercise.');
          }

          final sorted = progress.points;
          final metric = progress.metric;

          final spots = sorted.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.value);
          }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sorted.length) {
                          return const SizedBox();
                        }
                        final date = sorted[index].date;
                        return Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        formatSeriesValue(value, metric),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: OneRepColors.textSecondary),
        ),
      ),
    );
  }
}
