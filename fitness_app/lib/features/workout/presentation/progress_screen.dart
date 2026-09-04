import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/domain/progress_series.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/session_repository.dart';
import '../../../core/utils/set_formatter.dart';
import '../domain/session_highlights.dart';
import 'widgets/exercise_field.dart';
import 'widgets/session_chips.dart';
import 'widgets/session_note_dialog.dart';
import 'widgets/exercise_picker_sheet.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Exercise? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(watchCompletedSessionDetailsProvider);
    final highlightsAsync = ref.watch(watchSessionHighlightsProvider);
    final attendanceAsync = ref.watch(getAttendanceDataProvider);
    final streakAsync = ref.watch(getWeeklyStreakProvider);

    // A CustomScrollView, not a ListView. The history used to be a
    // shrinkWrap ListView nested inside this one with scrolling disabled,
    // so every session row was built on every frame with no viewport
    // culling — which only got more expensive once the rows started
    // carrying highlight chips.
    return CustomScrollView(
      slivers: [
        SliverList.list(
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
                            .where(
                              (s) =>
                                  s.startTime.month == now.month &&
                                  s.startTime.year == now.year,
                            )
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load this.',
                    style: TextStyle(color: OneRepColors.textSecondary),
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // PR Progression tracker
            // ----------------------------------------------------------------
            const _SectionLabel(title: 'PR PROGRESSION'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExerciseField(
                exercise: _selectedExercise,
                label: 'Select Exercise',
                hint: 'Tap to choose',
                onTap: () async {
                  final picked = await showExercisePicker(
                    context,
                    title: 'Choose exercise',
                  );
                  if (picked == null || !mounted) return;
                  setState(() => _selectedExercise = picked);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedExercise != null)
              _PrChart(exercise: _selectedExercise!)
            else
              // Without this the section is a heading, a picker and then
              // nothing, which reads as a screen that failed to load rather
              // than as one waiting on a choice.
              const _PrPlaceholder(
                icon: Icons.show_chart,
                message: 'Pick an exercise above.',
                detail: 'Its best effort in every session is plotted here.',
              ),

            // ----------------------------------------------------------------
            // Session history
            // ----------------------------------------------------------------
            const _SectionLabel(title: 'SESSION HISTORY'),
          ],
        ),
        sessionsAsync.when(
          data: (sessions) => sessions.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No completed sessions yet.\nFinish a workout to see it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: OneRepColors.textSecondary),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SessionRow(
                          session: session,
                          highlights: highlightsAsync.valueOrNull?[session.id],
                          onTap: () => _showSessionDetail(context, session),
                          onDelete: () => _confirmDelete(context, ref, session),
                        ),
                      );
                    },
                  ),
                ),
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load this.',
                  style: TextStyle(color: OneRepColors.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Confirms before deleting, and says what will be lost.
  ///
  /// A workout is worth more than an exercise, so it does not go on one
  /// gesture. Copy follows the discard-in-progress dialog, with the extra
  /// clause that matters here: records the session alone was holding are
  /// withdrawn with it.
  Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CompletedSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text(
          'The session and every set in it will be removed. Any personal best '
          'it was holding falls back to your next best.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep It'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref
          .read(sessionRepositoryProvider.notifier)
          .deleteSession(session.id);
      return true;
    }
    return false;
  }

  void _showSessionDetail(BuildContext context, CompletedSession session) {
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
          border: Border(top: BorderSide(color: color, width: 2)),
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
  final CompletedSession session;
  final SessionHighlights? highlights;
  final VoidCallback onTap;

  /// Resolves true when the session was actually deleted, so the row only
  /// dismisses if the user confirmed.
  final Future<bool> Function() onDelete;

  const _SessionRow({
    required this.session,
    required this.highlights,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      // Always false, even when the delete succeeds: the list is driven by a
      // stream, so the row disappears when the data does. Letting Dismissible
      // remove it as well risks it being dismissed while still in the tree.
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: OneRepColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: OneRepColors.error),
      ),
      child: _buildRow(),
    );
  }

  Widget _buildRow() {
    final duration = session.duration;

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
                    session.title,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (session.subtitle != null) session.subtitle!,
                      formatSessionDate(session.startTime),
                      if (duration != null) formatSessionDuration(duration),
                    ].join(' \u00b7 '),
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (highlights != null && !highlights!.isEmpty) ...[
                    const SizedBox(height: 8),
                    SessionChips(highlights: highlights, compact: true),
                  ],
                ],
              ),
            ),
            // A note is worth finding without opening every session, but not
            // worth quoting in a list — so the row marks it and the sheet
            // shows it.
            if (session.note != null) ...[
              const Icon(Icons.notes, color: OneRepColors.gold, size: 14),
              const SizedBox(width: 8),
            ],
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

// ---------------------------------------------------------------------------
// Attendance heatmap
// ---------------------------------------------------------------------------

/// How many sessions a day can show before the shading stops deepening.
///
/// Three, because `_attendanceColor` saturates there — a legend offering a
/// fourth step would be describing a colour the grid never draws.
const int _kAttendanceMaxShade = 3;

/// The colour one day of the heatmap is drawn in.
///
/// Shared by the grid and the legend. They used to compute their own ramps —
/// `0.25 + count * 0.25` against `0.2 + i * 0.22` — which had no value in
/// common, so the legend was a key to a scale that appeared nowhere on the
/// chart it sat under.
Color _attendanceColor(int sessions) {
  if (sessions <= 0) return OneRepColors.surfaceElevated;
  return OneRepColors.gold.withValues(
    alpha: (0.25 + sessions * 0.25).clamp(0.25, 1.0),
  );
}

class _AttendanceHeatmap extends StatelessWidget {
  final Map<DateTime, int> attendance;

  const _AttendanceHeatmap({required this.attendance});

  // Convert attendance map (DateTime keys) to string keys to avoid
  // any DateTime isUtc equality issues.
  Map<String, int> _toStringMap(Map<DateTime, int> attendance) {
    return {
      for (final e in attendance.entries)
        '${e.key.year}-${e.key.month.toString().padLeft(2, '0')}-${e.key.day.toString().padLeft(2, '0')}':
            e.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Without this the grid renders 84 blank cells, which reads as broken
    // rather than as empty. Every other section on this tab says so in words.
    if (attendance.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Center(
          child: Text(
            'No sessions in the last 12 weeks.',
            style: TextStyle(color: OneRepColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final stringMap = _toStringMap(attendance);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Align grid to start on Monday
    final daysToLastMonday = (todayNorm.weekday - 1) % 7;
    final gridStart = todayNorm.subtract(Duration(days: daysToLastMonday + 77));

    // Build exactly 12 weeks (84 days) from that Monday
    final List<DateTime> days = List.generate(
      84,
      (i) => gridStart.add(Duration(days: i)),
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
          ...weeks.map(
            (week) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  ...week.map((day) {
                    final key =
                        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final count = stringMap[key] ?? 0;
                    final isToday =
                        day.year == todayNorm.year &&
                        day.month == todayNorm.month &&
                        day.day == todayNorm.day;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 18,
                        decoration: BoxDecoration(
                          color: _attendanceColor(count),
                          borderRadius: BorderRadius.circular(3),
                          border: isToday
                              ? Border.all(color: OneRepColors.gold, width: 1.5)
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
            ),
          ),
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
              // Starts at zero sessions, so the leftmost swatch is the empty
              // cell the grid actually draws, and stops where the shading
              // stops deepening rather than inventing a fourth step.
              ...List.generate(_kAttendanceMaxShade + 1, (sessions) {
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _attendanceColor(sessions),
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
// PR progression — the best effort per session for one exercise.
//
// What counts as "best" depends on how the exercise is measured:
//   weightReps      heaviest weight across all rep counts
//   bodyweightReps  most reps in a single set
//   timeOnly        longest hold
//   distanceTime    fastest pace, not furthest distance — a longer run is not
//                   a better one, and this chart answers "am I improving"
//
// Every series is oriented so that up is better, which is what lets the
// summary above the plot state a direction of travel without asking the
// metric which way is good.
// ---------------------------------------------------------------------------

class _PrChart extends ConsumerWidget {
  final Exercise exercise;

  const _PrChart({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A provider, not a FutureBuilder over a raw query. Building the future
    // inside `build` — which is what this did — meant a fresh query on every
    // rebuild and no way for the chart to notice a record it had just earned.
    final seriesAsync = ref.watch(
      getRecordSeriesForExerciseProvider(exercise.id),
    );

    return seriesAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _PrPlaceholder(
        icon: Icons.error_outline,
        message: 'Could not load this history.',
      ),
      data: (series) {
        final summary = summariseSeries(series.points);
        if (summary == null) {
          return const _PrPlaceholder(
            icon: Icons.timeline,
            message: 'No records yet for this exercise.',
            detail: 'Log a set and the first one lands here.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrSummary(summary: summary, metric: series.metric),
            const SizedBox(height: 4),
            _PrGraph(points: series.points, summary: summary, series: series),
          ],
        );
      },
    );
  }
}

/// The numbers the chart cannot say on its own.
///
/// A line shows movement but not where you have got to, and reading a value
/// off a plot is guesswork. Three cells: the best effort and when it was set,
/// the most recent one, and the direction of travel between the first and the
/// latest.
class _PrSummary extends StatelessWidget {
  const _PrSummary({required this.summary, required this.metric});

  final SeriesSummary summary;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final change = summary.changeFraction;
    // A single session has nothing to compare against, and one point is not a
    // trend — saying "0%" there would be a claim rather than a blank.
    final hasTrend = summary.sessions > 1 && change != 0;

    final rising = change > 0;
    final trendColour = !hasTrend
        ? OneRepColors.textSecondary
        : rising
        ? OneRepColors.success
        : OneRepColors.coral;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PrStat(
              label: 'BEST',
              value: formatSeriesValue(summary.best.value, metric),
              caption: formatShortDate(summary.best.date),
              emphasis: OneRepColors.gold,
            ),
          ),
          const _PrDivider(),
          Expanded(
            child: _PrStat(
              label: 'LATEST',
              value: formatSeriesValue(summary.latest.value, metric),
              caption: formatShortDate(summary.latest.date),
            ),
          ),
          const _PrDivider(),
          Expanded(
            child: _PrStat(
              label: 'TREND',
              value: hasTrend
                  ? '${rising ? '+' : ''}${(change * 100).round()}%'
                  : '—',
              caption: hasTrend
                  ? 'over ${summary.sessions} sessions'
                  : '${summary.sessions} '
                        '${summary.sessions == 1 ? 'session' : 'sessions'}',
              emphasis: hasTrend ? trendColour : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrStat extends StatelessWidget {
  const _PrStat({
    required this.label,
    required this.value,
    required this.caption,
    this.emphasis,
  });

  final String label;
  final String value;
  final String caption;

  /// Colour for the value. Null leaves it in the ordinary text colour, which
  /// is what a figure with no verdict attached to it should look like.
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: OneRepColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: emphasis ?? OneRepColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: OneRepColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _PrDivider extends StatelessWidget {
  const _PrDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: OneRepColors.surfaceElevated,
    );
  }
}

/// The plot itself.
class _PrGraph extends StatelessWidget {
  const _PrGraph({
    required this.points,
    required this.summary,
    required this.series,
  });

  final List<SeriesPoint> points;
  final SeriesSummary summary;
  final ExerciseProgress series;

  /// Roughly how many labels each axis should carry.
  ///
  /// Four is what fits without the dates colliding on a narrow phone; more
  /// labels than that stop being read and start being texture.
  static const int _targetLabels = 4;

  @override
  Widget build(BuildContext context) {
    final metric = series.metric;
    final range = chartRangeFor(points);

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    final dateInterval = (points.length / _targetLabels).ceilToDouble().clamp(
      1.0,
      double.infinity,
    );

    // Derived from the span rather than fixed, so a chart of five kilos and a
    // chart of five hundred both end up with about the same number of lines.
    final valueInterval = ((range.max - range.min) / _targetLabels).clamp(
      0.0001,
      double.infinity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                metric.axisLabel,
                style: const TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Says what the gold point is without a legend key, which at
              // this size would take more room than the thing it explains.
              const Icon(Icons.circle, size: 7, color: OneRepColors.gold),
              const SizedBox(width: 5),
              const Text(
                'best',
                style: TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: LineChart(
              LineChartData(
                minY: range.min,
                maxY: range.max,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: valueInterval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: OneRepColors.surfaceElevated,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: dateInterval,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final date = points[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
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
                      reservedSize: 46,
                      interval: valueInterval,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          formatSeriesValue(value, metric),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: OneRepColors.textSecondary,
                            fontSize: 9,
                          ),
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
                // Reading a value off a plot is guesswork, and this one is
                // small. Touching a point says exactly what it was and when.
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: OneRepColors.surfaceHighest,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    getTooltipItems: (touched) => [
                      for (final spot in touched)
                        LineTooltipItem(
                          formatSeriesValue(spot.y, metric),
                          const TextStyle(
                            color: OneRepColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '\n${formatShortDate(points[spot.x.round()].date)}',
                              style: const TextStyle(
                                color: OneRepColors.textSecondary,
                                fontWeight: FontWeight.w400,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  getTouchedSpotIndicator: (bar, indices) => [
                    for (final _ in indices)
                      TouchedSpotIndicatorData(
                        const FlLine(
                          color: OneRepColors.gold,
                          strokeWidth: 1,
                          dashArray: [3, 3],
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, data, index) =>
                              FlDotCirclePainter(
                                radius: 5,
                                color: OneRepColors.gold,
                                strokeColor: OneRepColors.background,
                                strokeWidth: 2,
                              ),
                        ),
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: OneRepColors.gold,
                    barWidth: 2,
                    dotData: FlDotData(
                      // The best is drawn as a filled gold point and the rest
                      // hollow, so the peak is findable without reading the
                      // axis. A series of identical dots hides the one figure
                      // the chart exists to show.
                      getDotPainter: (spot, percent, bar, index) {
                        final isBest = index == summary.bestIndex;
                        return FlDotCirclePainter(
                          radius: isBest ? 5 : 3,
                          color: isBest
                              ? OneRepColors.gold
                              : OneRepColors.background,
                          strokeColor: OneRepColors.gold,
                          strokeWidth: isBest ? 2 : 1.5,
                        );
                      },
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
  }
}

/// Stands in for the chart when there is nothing to draw.
///
/// A panel rather than a bare line of text: the section is a heading, a picker
/// and then a two-hundred-pixel hole, and an empty state that occupies the
/// space explains the hole instead of leaving the screen looking broken.
class _PrPlaceholder extends StatelessWidget {
  const _PrPlaceholder({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: OneRepColors.textDisabled),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OneRepColors.textDisabled,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session detail bottom sheet
// ---------------------------------------------------------------------------

class SessionDetailSheet extends ConsumerWidget {
  final CompletedSession session;

  const SessionDetailSheet({super.key, required this.session});

  /// Opens the note editor and saves whatever comes back.
  ///
  /// A dialog rather than an inline field: this sheet is a
  /// `DraggableScrollableSheet` inside a modal route, and putting a
  /// multi-line input in it means fighting the keyboard for the drag.
  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    CompletedSession live,
  ) async {
    final result = await showSessionNoteDialog(context, initial: live.note);
    // Null means dismissed; a record carrying a null note means cleared.
    if (result == null) return;

    await ref
        .read(sessionRepositoryProvider.notifier)
        .setSessionNote(live.id, result.note);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The sheet is handed a snapshot when it opens, so it re-reads the live
    // row: editing the note here has to be visible here, not only after the
    // sheet is closed and reopened.
    final live =
        ref
            .watch(watchCompletedSessionDetailsProvider)
            .valueOrNull
            ?.where((s) => s.id == session.id)
            .firstOrNull ??
        session;

    final setsAsync = ref.watch(watchSetsForSessionProvider(session.id));
    final duration = live.duration;
    final highlights = ref
        .watch(watchSessionHighlightsProvider)
        .valueOrNull?[session.id];

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
                        live.title,
                        style: const TextStyle(
                          color: OneRepColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          if (live.subtitle != null) live.subtitle!,
                          formatSessionDate(live.startTime),
                          if (duration != null) formatSessionDuration(duration),
                        ].join(' · '),
                        style: const TextStyle(
                          color: OneRepColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (highlights != null && !highlights.isEmpty) ...[
                        const SizedBox(height: 10),
                        SessionChips(highlights: highlights),
                      ],
                    ],
                  ),
                ),
                // A "COMPLETED" badge used to sit here. It had no condition
                // at all, and could not have had a useful one: this sheet is
                // only reachable from a list filtered on `endTime IS NOT NULL`.
                // What a session achieved is worth a badge; that it happened
                // is not.
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: SessionNoteSection(
              note: live.note,
              onEdit: () => _editNote(context, ref, live),
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
                final grouped = <String, List<WorkoutSetWithExercise>>{};
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
                                    formatWorkoutSet(set.set),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load this.',
                    style: TextStyle(color: OneRepColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
