/// The Splits tab.
///
/// Opens on the default split's Today card when there is one, and on the list
/// of splits when there is not. Most people run a single split for months at a
/// time, and making them pick it out of a list every session was a tap that
/// never told anyone anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/split_repository.dart';
import '../data/split_schedule_repository.dart';
import '../domain/split_schedule.dart';
import 'split_detail_screen.dart';
import 'split_schedule_screen.dart';
import 'widgets/rename_dialog.dart';
import 'widgets/start_session.dart';

class SplitListScreen extends ConsumerStatefulWidget {
  const SplitListScreen({super.key});

  @override
  ConsumerState<SplitListScreen> createState() => _SplitListScreenState();
}

class _SplitListScreenState extends ConsumerState<SplitListScreen> {
  /// Set when the user asks for the full list from the Today card. Held here
  /// rather than pushed as a route, so leaving the tab and coming back returns
  /// them to Today — which is where they wanted to be.
  bool _showingAll = false;

  @override
  Widget build(BuildContext context) {
    final defaultSplit = ref.watch(watchDefaultSplitProvider).valueOrNull;

    if (defaultSplit != null && !_showingAll) {
      return _TodayScreen(
        split: defaultSplit,
        onShowAll: () => setState(() => _showingAll = true),
      );
    }

    return _AllSplitsScreen(
      onBackToToday: defaultSplit == null
          ? null
          : () => setState(() => _showingAll = false),
    );
  }
}

// ---------------------------------------------------------------------------
// Today
// ---------------------------------------------------------------------------

class _TodayScreen extends ConsumerWidget {
  const _TodayScreen({required this.split, required this.onShowAll});

  final WorkoutSplit split;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(watchSplitPlanProvider(split.id));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TodayHeader(name: split.name, onShowAll: onShowAll),
            Expanded(
              child: planAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (plan) => plan == null
                    ? const SizedBox.shrink()
                    : _TodayBody(plan: plan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.name, required this.onShowAll});

  final String name;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onShowAll,
            icon: const Icon(Icons.swap_horiz, size: 17),
            label: const Text('All splits'),
            style: TextButton.styleFrom(
              foregroundColor: OneRepColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.plan});

  final SplitPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _NextUpCard(plan: plan),
        if (plan.schedule.isActive) ...[
          const SizedBox(height: 22),
          _SectionLabel(
            title: plan.schedule.mode == ScheduleMode.weekly
                ? 'THIS WEEK'
                : 'THE ROTATION',
          ),
          const SizedBox(height: 8),
          _RotationStrip(plan: plan),
        ],
        const SizedBox(height: 22),
        _TodayActions(plan: plan),
      ],
    );
  }
}

/// What to train, and the button that starts it.
class _NextUpCard extends ConsumerWidget {
  const _NextUpCard({required this.plan});

  final SplitPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = plan.due;

    if (due == null) {
      return _EmptyToday(plan: plan);
    }

    final exercises = plan.exerciseCounts[due.routineId] ?? 0;
    final today = plan.isToday;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: today ? OneRepColors.gold : OneRepColors.surfaceHighest,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heading(plan),
            style: TextStyle(
              color: today ? OneRepColors.gold : OneRepColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            due.name,
            style: const TextStyle(
              color: OneRepColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            exercises == 0
                ? 'No exercises planned yet'
                : '$exercises ${exercises == 1 ? 'exercise' : 'exercises'}',
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => startRoutineSession(
                context,
                ref,
                routineId: due.routineId,
                routineName: due.name,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                today ? 'START WORKOUT' : 'START ANYWAY',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The line above the routine name.
  ///
  /// Says where the session sits relative to now rather than naming the day,
  /// because "Today" and "in 2 days" is what the user is actually asking, and
  /// the rotation strip below already spells out the days.
  static String _heading(SplitPlan plan) {
    if (plan.trainedToday) return 'DONE TODAY · NEXT UP';
    return switch (plan.verdict.daysAway) {
      0 =>
        'TODAY · ${slotLabel(plan.schedule, plan.verdict.slot).toUpperCase()}',
      1 => 'TOMORROW',
      final days => 'IN $days DAYS',
    };
  }
}

/// Shown when the split has nothing to offer.
class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.plan});

  final SplitPlan plan;

  @override
  Widget build(BuildContext context) {
    final unscheduled = !plan.schedule.isActive;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available,
            size: 30,
            color: OneRepColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            unscheduled ? 'No rotation set' : 'Nothing scheduled',
            style: const TextStyle(
              color: OneRepColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            unscheduled
                ? 'Lay this split out over the week, or over a rotation of '
                      'your own, and this card will tell you what is due.'
                : 'This split has a rotation but no routines on it yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rotation laid out, with today marked.
class _RotationStrip extends StatelessWidget {
  const _RotationStrip({required this.plan});

  final SplitPlan plan;

  @override
  Widget build(BuildContext context) {
    final schedule = plan.schedule;
    final current = plan.verdict.daysAway == 0
        ? plan.verdict.slot
        : _todaySlot(plan);

    return Column(
      children: [
        for (var slot = 0; slot < schedule.length; slot++)
          _RotationRow(
            label: slotLabel(schedule, slot),
            routines: schedule.at(slot),
            isNow: slot == current,
            isNext: slot == plan.verdict.slot && plan.verdict.daysAway > 0,
          ),
      ],
    );
  }

  /// Where today falls even when today is a rest day, so the strip can still
  /// mark it — the verdict points at the next session, which may be days off.
  static int _todaySlot(SplitPlan plan) => slotOn(
    plan.schedule,
    DateTime.now(),
    lastTrainedSlot: plan.verdict.slot,
    lastTrainedOn: plan.lastTrainedOn,
  );
}

class _RotationRow extends StatelessWidget {
  const _RotationRow({
    required this.label,
    required this.routines,
    required this.isNow,
    required this.isNext,
  });

  final String label;
  final List<ScheduledRoutine> routines;
  final bool isNow;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final accent = isNow
        ? OneRepColors.gold
        : isNext
        ? OneRepColors.gold.withValues(alpha: 0.5)
        : OneRepColors.surfaceElevated;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isNow
            ? OneRepColors.gold.withValues(alpha: 0.10)
            : OneRepColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                color: isNow
                    ? OneRepColors.gold
                    : routines.isEmpty
                    ? OneRepColors.textDisabled
                    : OneRepColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              routines.isEmpty
                  ? 'Rest'
                  : routines.map((r) => r.name).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: routines.isEmpty
                    ? OneRepColors.textDisabled
                    : OneRepColors.textPrimary,
                fontSize: 13,
                fontWeight: routines.isEmpty
                    ? FontWeight.w400
                    : FontWeight.w600,
              ),
            ),
          ),
          if (isNow)
            const Text(
              'TODAY',
              style: TextStyle(
                color: OneRepColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayActions extends ConsumerWidget {
  const _TodayActions({required this.plan});

  final SplitPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SplitScheduleScreen(split: plan.split),
              ),
            ),
            icon: const Icon(Icons.calendar_month, size: 17),
            label: const Text('Schedule'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SplitDetailScreen(split: plan.split),
              ),
            ),
            icon: const Icon(Icons.list_alt, size: 17),
            label: const Text('Routines'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: OneRepColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All splits
// ---------------------------------------------------------------------------

class _AllSplitsScreen extends ConsumerWidget {
  const _AllSplitsScreen({required this.onBackToToday});

  /// Null when there is no default split to go back to.
  final VoidCallback? onBackToToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(watchSplitsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (onBackToToday != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextButton.icon(
                    onPressed: onBackToToday,
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: const Text('Back to today'),
                    style: TextButton.styleFrom(
                      foregroundColor: OneRepColors.textSecondary,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: splitsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (splits) => splits.isEmpty
                    ? const _EmptyState(
                        icon: Icons.view_week_outlined,
                        message: 'No splits yet.',
                        sub:
                            'Create a training split to organise your '
                            'workouts.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: splits.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SplitCard(split: splits[index]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'split_fab',
        onPressed: () => _showCreateSplitDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(
          'NEW SPLIT',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }
}

/// What the overflow menu on a split offers.
enum _SplitAction { setDefault, clearDefault, schedule, rename, delete }

class _SplitCard extends ConsumerWidget {
  const _SplitCard({required this.split});

  final WorkoutSplit split;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _SplitAction action,
  ) async {
    final navigator = Navigator.of(context);
    final splits = ref.read(splitRepositoryProvider.notifier);
    final schedules = ref.read(splitScheduleRepositoryProvider.notifier);

    switch (action) {
      case _SplitAction.setDefault:
        await schedules.setDefaultSplit(split.id);
      case _SplitAction.clearDefault:
        await schedules.setDefaultSplit(null);
      case _SplitAction.schedule:
        navigator.push(
          MaterialPageRoute(builder: (_) => SplitScheduleScreen(split: split)),
        );
      case _SplitAction.rename:
        final name = await showRenameDialog(
          context,
          title: 'Rename split',
          current: split.name,
        );
        if (name == null) return;
        await splits.renameSplit(split.id, name);
      case _SplitAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete ${split.name}?'),
            // Deleting a split takes every routine and every planned exercise
            // in it. It used to happen on a swipe, with no confirmation and
            // no undo.
            content: const Text(
              'Every routine in this split and the exercises planned in them '
              'will be deleted. Sessions you have already logged are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: OneRepColors.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await splits.deleteSplit(split.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines =
        ref.watch(watchRoutinesForSplitProvider(split.id)).valueOrNull ??
        const <WorkoutRoutine>[];
    final mode = ScheduleMode.byNameOrNone(split.scheduleMode);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SplitDetailScreen(split: split)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 6, 14),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: split.isDefault
                  ? OneRepColors.gold
                  : OneRepColors.surfaceHighest,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          split.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: OneRepColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (split.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // The facts about a split that matter. It used to say the
                    // date it was created, which never told anyone anything.
                    [
                      '${routines.length} '
                          '${routines.length == 1 ? 'day' : 'days'}',
                      if (mode != ScheduleMode.none) mode.label.toLowerCase(),
                      'since ${formatShortDate(split.createdAt)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_SplitAction>(
              icon: const Icon(
                Icons.more_vert,
                color: OneRepColors.textSecondary,
                size: 20,
              ),
              color: OneRepColors.surfaceElevated,
              onSelected: (action) => _act(context, ref, action),
              itemBuilder: (context) => [
                if (split.isDefault)
                  const PopupMenuItem(
                    value: _SplitAction.clearDefault,
                    child: Text('Stop opening on this'),
                  )
                else
                  const PopupMenuItem(
                    value: _SplitAction.setDefault,
                    child: Text('Open on this split'),
                  ),
                const PopupMenuItem(
                  value: _SplitAction.schedule,
                  child: Text('Schedule'),
                ),
                const PopupMenuItem(
                  value: _SplitAction.rename,
                  child: Text('Rename'),
                ),
                const PopupMenuItem(
                  value: _SplitAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: OneRepColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'OPENS HERE',
        style: TextStyle(
          color: OneRepColors.gold,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

void _showCreateSplitDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) => _CreateSplitDialog(ref: ref),
  );
}

/// Stateful so the controller is disposed and the empty-name case can say
/// something.
///
/// The previous dialog did neither: it leaked its controller, and pressing
/// Create with an empty field silently did nothing, which is indistinguishable
/// from a broken button.
class _CreateSplitDialog extends StatefulWidget {
  const _CreateSplitDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_CreateSplitDialog> createState() => _CreateSplitDialogState();
}

class _CreateSplitDialogState extends State<_CreateSplitDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the split a name.');
      return;
    }

    final navigator = Navigator.of(context);
    await widget.ref.read(splitRepositoryProvider.notifier).createSplit(name);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Split'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Split Name',
          hintText: 'e.g. 6-Day PPL',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: OneRepColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: OneRepColors.textSecondary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
