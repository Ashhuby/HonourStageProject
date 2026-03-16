import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_app/core/database/local_database.dart';
import '../data/session_repository.dart';
import '../data/exercise_repository.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Exercise? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(watchCompletedSessionsProvider);
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: exercisesAsync.when(
            data: (exercises) => DropdownButtonFormField<Exercise>(
              value: _selectedExercise,
              decoration: const InputDecoration(
                labelText: 'Select Exercise to Track',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: exercises
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name),
                      ))
                  .toList(),
              onChanged: (exercise) {
                setState(() => _selectedExercise = exercise);
              },
            ),
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text('Error: $err'),
          ),
        ),
        if (_selectedExercise != null)
          _VolumeChart(exerciseId: _selectedExercise!.id),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Session History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessionsAsync.when(
            data: (sessions) => sessions.isEmpty
                ? const Center(
                    child: Text(
                      'No completed sessions yet.\nFinish a workout to see it here.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final duration = session.endTime != null
                          ? session.endTime!.difference(session.startTime)
                          : null;

                      return ListTile(
                        title: Text(_formatDate(session.startTime)),
                        subtitle: duration != null
                            ? Text(_formatDuration(duration))
                            : null,
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center),
                        ),
                        onTap: () =>
                            _showSessionDetail(context, session),
                      );
                    },
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  void _showSessionDetail(BuildContext context, WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: SessionDetailSheet(session: session),
      ),
    );
  }
}

// --- Volume chart widget ---

class _VolumeChart extends ConsumerWidget {
  final int exerciseId;

  const _VolumeChart({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeAsync =
        ref.watch(getVolumeForExerciseProvider(exerciseId));

    return SizedBox(
      height: 200,
      child: volumeAsync.when(
        data: (dataPoints) {
          if (dataPoints.isEmpty) {
            return const Center(
              child: Text('No data yet for this exercise.'),
            );
          }

          final spots = dataPoints.asMap().entries.map((entry) {
            return FlSpot(
              entry.key.toDouble(),
              entry.value.totalVolume,
            );
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
                        if (index < 0 || index >= dataPoints.length) {
                          return const SizedBox();
                        }
                        final date = dataPoints[index].date;
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
                        '${value.toInt()}kg',
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// --- Session detail bottom sheet ---

class SessionDetailSheet extends ConsumerWidget {
  final WorkoutSession session;

  const SessionDetailSheet({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync =
        ref.watch(watchSetsForSessionProvider(session.id));

    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.startTime.day}/${session.startTime.month}/${session.startTime.year}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (duration != null)
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: setsAsync.when(
              data: (sets) {
                if (sets.isEmpty) {
                  return const Center(child: Text('No sets logged.'));
                }

                final Map<String, List<WorkoutSetWithExercise>> grouped =
                    {};
                for (final s in sets) {
                  grouped.putIfAbsent(s.exerciseName, () => []).add(s);
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final exerciseName = grouped.keys.elementAt(index);
                    final exerciseSets = grouped[exerciseName]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exerciseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...exerciseSets.asMap().entries.map(
                              (entry) {
                                final setNum = entry.key + 1;
                                final s = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2),
                                  child: Text(
                                    'Set $setNum: ${s.set.weight}kg × ${s.set.reps} reps',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}