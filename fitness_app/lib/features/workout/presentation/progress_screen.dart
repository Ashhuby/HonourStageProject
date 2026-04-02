import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import '../../../main.dart';
import '../data/session_repository.dart';
import '../data/exercise_repository.dart';
import '../../../core/database/database_provider.dart';

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
    final attendanceAsync = ref.watch(getAttendanceDataProvider);
    final streakAsync = ref.watch(getWeeklyStreakProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // ----------------------------------------------------------------
        // Stat cards
        // ----------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _StatCard(
                label: 'WEEKLY\nSTREAK',
                value: streakAsync.when(
                  data: (s) => '$s',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                unit: 'wks',
                icon: Icons.local_fire_department,
                color: OneRepColors.coral,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'TOTAL\nSESSIONS',
                value: sessionsAsync.when(
                  data: (s) => '${s.length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                unit: 'done',
                icon: Icons.fitness_center,
                color: OneRepColors.gold,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'THIS\nMONTH',
                value: sessionsAsync.when(
                  data: (sessions) {
                    final now = DateTime.now();
                    final count = sessions
                        .where((s) =>
                            s.startTime.month == now.month &&
                            s.startTime.year == now.year)
                        .length;
                    return '$count';
                  },
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                unit: 'sessions',
                icon: Icons.calendar_month,
                color: OneRepColors.back,
              ),
            ],
          ),
        ),

        // ----------------------------------------------------------------
        // Attendance heatmap
        // ----------------------------------------------------------------
        const _SectionLabel(title: 'ATTENDANCE — LAST 12 WEEKS'),
        attendanceAsync.when(
          data: (attendance) => _AttendanceHeatmap(attendance: attendance),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),

        // ----------------------------------------------------------------
        // PR Progression tracker
        // ----------------------------------------------------------------
        const _SectionLabel(title: 'PR PROGRESSION'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: exercisesAsync.when(
            data: (exercises) => DropdownButtonFormField<Exercise>(
              initialValue: _selectedExercise,
              decoration: const InputDecoration(
                labelText: 'Select Exercise',
                prefixIcon: Icon(Icons.fitness_center, size: 18),
              ),
              dropdownColor: OneRepColors.surfaceElevated,
              style: const TextStyle(color: OneRepColors.textPrimary),
              items: exercises
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name),
                      ))
                  .toList(),
              onChanged: (exercise) =>
                  setState(() => _selectedExercise = exercise),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error: $err'),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedExercise != null)
          _PrChart(exercise: _selectedExercise!),

        // ----------------------------------------------------------------
        // Session history
        // ----------------------------------------------------------------
        const _SectionLabel(title: 'SESSION HISTORY'),
        sessionsAsync.when(
          data: (sessions) => sessions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No completed sessions yet.\nFinish a workout to see it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: OneRepColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final duration = session.endTime?.difference(session.startTime);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionRow(
                        session: session,
                        duration: duration,
                        onTap: () => _showSessionDetail(context, session),
                      ),
                    );
                  },
                ),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ],
    );
  }

  void _showSessionDetail(BuildContext context, WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OneRepColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: SessionDetailSheet(session: session),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            top: BorderSide(color: color, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                color: OneRepColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: OneRepColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: OneRepColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session row — no circle avatar
// ---------------------------------------------------------------------------

class _SessionRow extends StatelessWidget {
  final WorkoutSession session;
  final Duration? duration;
  final VoidCallback onTap;

  const _SessionRow({
    required this.session,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: OneRepColors.gold, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(session.startTime),
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(duration!),
                      style: const TextStyle(
                        color: OneRepColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

// ---------------------------------------------------------------------------
// Attendance heatmap
// ---------------------------------------------------------------------------

class _AttendanceHeatmap extends StatelessWidget {
  final Map<DateTime, int> attendance;

  const _AttendanceHeatmap({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final List<DateTime> days = List.generate(
      84,
      (i) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 83 - i)),
    );

    final List<List<DateTime>> weeks = [];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: OneRepColors.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // Grid
          ...weeks.map((week) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    ...week.map((day) {
                      final count = attendance[day] ?? 0;
                      final isToday = day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 18,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? OneRepColors.gold.withValues(
                                    alpha:
                                        (0.25 + (count * 0.25)).clamp(0.25, 1.0),
                                  )
                                : OneRepColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(3),
                            border: isToday
                                ? Border.all(
                                    color: OneRepColors.gold,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                    // Pad incomplete final week
                    if (week.length < 7)
                      ...List.generate(
                        7 - week.length,
                        (_) => const Expanded(child: SizedBox()),
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Less',
                style: TextStyle(
                  color: OneRepColors.textDisabled,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              ...List.generate(4, (i) {
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: OneRepColors.gold
                        .withValues(alpha: 0.2 + (i * 0.22)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              const Text(
                'More',
                style: TextStyle(
                  color: OneRepColors.textDisabled,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR Progression chart — plots best performance over time for an exercise.
// For weightReps: shows heaviest weight across all rep counts per session.
// For timeOnly: shows longest duration per session.
// For distanceTime: shows fastest time for any distance per session.
// For bodyweightReps: shows most reps in a single set per session.
// ---------------------------------------------------------------------------

class _PrChart extends ConsumerWidget {
  final Exercise exercise;

  const _PrChart({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder(
      future: _loadPrHistory(db, exercise),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final points = snapshot.data ?? [];
        if (points.isEmpty) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'No PRs recorded yet for this exercise.',
                style: TextStyle(color: OneRepColors.textSecondary),
              ),
            ),
          );
        }

        final metricType = exercise.metricType;
        final yLabel = _yAxisLabel(metricType);

        final spots = points.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.value))
            .toList();

        final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
        final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
        final padding = (maxY - minY) * 0.15;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                yLabel,
                style: const TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                child: LineChart(
                  LineChartData(
                    minY: (minY - padding).clamp(0, double.infinity),
                    maxY: maxY + padding,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: OneRepColors.surfaceElevated,
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (_) => const FlLine(
                        color: Colors.transparent,
                        strokeWidth: 0,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (points.length / 5).ceilToDouble().clamp(1, double.infinity),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox();
                            }
                            final date = points[index].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(
                                  color: OneRepColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (value, meta) => Text(
                            _formatYValue(value, metricType),
                            style: const TextStyle(
                              color: OneRepColors.textSecondary,
                              fontSize: 9,
                            ),
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
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(color: OneRepColors.surfaceElevated),
                        left: BorderSide(color: OneRepColors.surfaceElevated),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: OneRepColors.gold,
                        barWidth: 2,
                        dotData: FlDotData(
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: OneRepColors.gold,
                            strokeColor: OneRepColors.background,
                            strokeWidth: 1.5,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              OneRepColors.gold.withValues(alpha: 0.2),
                              OneRepColors.gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _yAxisLabel(String metricType) {
    return switch (metricType) {
      'timeOnly' => 'DURATION (seconds)',
      'distanceTime' => 'BEST TIME (seconds)',
      'bodyweightReps' => 'MAX REPS',
      _ => 'BEST WEIGHT (kg)',
    };
  }

  String _formatYValue(double value, String metricType) {
    if (metricType == 'timeOnly' || metricType == 'distanceTime') {
      final secs = value.toInt();
      final m = secs ~/ 60;
      final s = secs % 60;
      return m > 0 ? '${m}m${s}s' : '${s}s';
    }
    return '${value.toInt()}';
  }

  Future<List<_PrPoint>> _loadPrHistory(
      AppDatabase db, Exercise exercise) async {
    // Fetch all sets for this exercise that have a non-zero performance value,
    // grouped by session date. Plot the best value per session date.
    final query = db.select(db.workoutSets).join([
      innerJoin(
        db.workoutSessions,
        db.workoutSessions.id.equalsExp(db.workoutSets.sessionId),
      ),
    ])
      ..where(db.workoutSets.exerciseId.equals(exercise.id))
      ..where(db.workoutSessions.endTime.isNotNull())
      ..where(db.workoutSessions.deletedAt.isNull())
      ..where(db.workoutSets.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.workoutSessions.startTime)]);

    final rows = await query.get();

    final Map<String, double> bestPerDay = {};
    final Map<String, DateTime> dateByKey = {};

    for (final row in rows) {
      final set = row.readTable(db.workoutSets);
      final session = row.readTable(db.workoutSessions);
      final day =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      dateByKey[day] = session.startTime;

      double value;
      switch (exercise.metricType) {
        case 'timeOnly':
          value = (set.durationSeconds ?? 0).toDouble();
        case 'distanceTime':
          // Lower is better — store as negative so chart trends upward
          final secs = set.durationSeconds ?? 0;
          value = secs > 0 ? secs.toDouble() : 0;
        case 'bodyweightReps':
          value = set.reps.toDouble();
        default: // weightReps
          value = set.weight;
      }

      if (value > 0) {
        final existing = bestPerDay[day] ?? 0;
        if (value > existing) bestPerDay[day] = value;
      }
    }

    final sorted = bestPerDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted
        .map((e) => _PrPoint(date: dateByKey[e.key]!, value: e.value))
        .toList();
  }
}

class _PrPoint {
  final DateTime date;
  final double value;
  const _PrPoint({required this.date, required this.value});
}

// ---------------------------------------------------------------------------
// Session detail bottom sheet
// ---------------------------------------------------------------------------

class SessionDetailSheet extends ConsumerWidget {
  final WorkoutSession session;

  const SessionDetailSheet({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(watchSetsForSessionProvider(session.id));
    final duration = session.endTime?.difference(session.startTime);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: OneRepColors.surfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(session.startTime),
                        style: const TextStyle(
                          color: OneRepColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (duration != null)
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: OneRepColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: OneRepColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: OneRepColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: OneRepColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: OneRepColors.surfaceElevated),
          // Sets list
          Expanded(
            child: setsAsync.when(
              data: (sets) {
                if (sets.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sets logged.',
                      style: TextStyle(color: OneRepColors.textSecondary),
                    ),
                  );
                }
                final grouped = <String, List<dynamic>>{};
                for (final s in sets) {
                  grouped.putIfAbsent(s.exerciseName, () => []).add(s);
                }
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: grouped.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: OneRepColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...entry.value.asMap().entries.map((e) {
                            final set = e.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: OneRepColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${e.key + 1}',
                                        style: const TextStyle(
                                          color: OneRepColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatSet(set.set),
                                    style: const TextStyle(
                                      color: OneRepColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSet(WorkoutSet set) {
    if (set.durationSeconds != null) {
      final secs = set.durationSeconds!;
      final m = secs ~/ 60;
      final s = secs % 60;
      final timeStr = m > 0
          ? '${m}m ${s.toString().padLeft(2, '0')}s'
          : '${s}s';
      if (set.distanceMetres != null && set.distanceMetres! > 0) {
        final dist = set.distanceMetres!;
        final distStr = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(1)}km'
            : '${dist.toStringAsFixed(0)}m';
        return '$distStr in $timeStr';
      }
      return timeStr;
    }
    if (set.weight == 0.0) return '${set.reps} reps';
    return '${set.weight}kg × ${set.reps} reps';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}