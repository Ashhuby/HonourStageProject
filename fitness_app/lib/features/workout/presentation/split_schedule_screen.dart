/// Laying a split's days out over its rotation.
///
/// Drag a routine onto a day. The same screen serves a weekly split and a
/// "train one, rest two" cycle, because both are a ring of slots — only the
/// labels and the length differ, and building two editors would have meant
/// maintaining the same drag logic twice.
///
/// Everything is reachable by tap as well as by drag. Dragging is the good
/// interaction when it works, but it is the one that fails on a small screen
/// with a scrolling list behind it, and a scheduling screen that can only be
/// used one way is a scheduling screen some people cannot use.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../../core/theme/app_colors.dart';
import '../data/split_repository.dart';
import '../data/split_schedule_repository.dart';
import '../domain/split_schedule.dart';

/// A routine being dragged, and where it came from.
///
/// The source slot travels with it so a drag between two days can clear the
/// old one — without it, dragging Push from Monday to Tuesday would leave it
/// on both.
typedef _RoutineDrag = ({int routineId, String name, int? fromSlot});

class SplitScheduleScreen extends ConsumerWidget {
  const SplitScheduleScreen({super.key, required this.split});

  final WorkoutSplit split;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(watchSplitScheduleProvider(split.id));
    final routinesAsync = ref.watch(watchRoutinesForSplitProvider(split.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Schedule', style: TextStyle(fontSize: 17)),
            Text(
              split.name,
              style: const TextStyle(
                fontSize: 12,
                color: OneRepColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (schedule) {
          final routines =
              routinesAsync.valueOrNull ?? const <WorkoutRoutine>[];

          if (routines.isEmpty) {
            return const _NoRoutines();
          }

          return _Editor(
            splitId: split.id,
            schedule: schedule,
            routines: routines,
          );
        },
      ),
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({
    required this.splitId,
    required this.schedule,
    required this.routines,
  });

  final int splitId;
  final SplitSchedule schedule;
  final List<WorkoutRoutine> routines;

  SplitScheduleRepository _repo(WidgetRef ref) =>
      ref.read(splitScheduleRepositoryProvider.notifier);

  Future<void> _drop(WidgetRef ref, _RoutineDrag drag, int slot) async {
    if (drag.fromSlot == slot) return;
    if (drag.fromSlot != null) {
      await _repo(ref).clearSlot(drag.routineId, drag.fromSlot!);
    }
    await _repo(ref).assignSlot(drag.routineId, slot);
  }

  /// Offers the routines not already on [slot].
  Future<void> _pick(BuildContext context, WidgetRef ref, int slot) async {
    final taken = {for (final r in schedule.at(slot)) r.routineId};
    final available = routines.where((r) => !taken.contains(r.id)).toList();
    if (available.isEmpty) return;

    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: OneRepColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Add to ${slotLabel(schedule, slot)}',
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final routine in available)
              ListTile(
                title: Text(
                  routine.name,
                  style: const TextStyle(color: OneRepColors.textPrimary),
                ),
                onTap: () => Navigator.pop(sheetContext, routine.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await _repo(ref).assignSlot(chosen, slot);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              _ModeSelector(
                splitId: splitId,
                schedule: schedule,
                onChanged: (mode) => _repo(
                  ref,
                ).setScheduleMode(splitId, mode, cycleLength: schedule.length),
              ),
              if (schedule.mode == ScheduleMode.cycle) ...[
                const SizedBox(height: 12),
                _LengthStepper(
                  length: schedule.length,
                  onChanged: (length) => _repo(ref).setScheduleMode(
                    splitId,
                    ScheduleMode.cycle,
                    cycleLength: length,
                  ),
                ),
              ],
              if (schedule.mode == ScheduleMode.none) ...[
                const SizedBox(height: 24),
                const _NoSchedule(),
              ] else ...[
                const SizedBox(height: 18),
                const _Hint(),
                const SizedBox(height: 10),
                for (var slot = 0; slot < schedule.length; slot++)
                  _SlotRow(
                    label: slotLabel(schedule, slot),
                    assigned: schedule.at(slot),
                    onAccept: (drag) => _drop(ref, drag, slot),
                    onAdd: () => _pick(context, ref, slot),
                    onRemove: (routineId) =>
                        _repo(ref).clearSlot(routineId, slot),
                    slot: slot,
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (schedule.mode != ScheduleMode.none)
          _RoutineTray(routines: routines, schedule: schedule),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mode and length
// ---------------------------------------------------------------------------

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.splitId,
    required this.schedule,
    required this.onChanged,
  });

  final int splitId;
  final SplitSchedule schedule;
  final ValueChanged<ScheduleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in ScheduleMode.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ModeChip(
                label: mode.label,
                selected: schedule.mode == mode,
                onTap: () => onChanged(mode),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? OneRepColors.gold.withValues(alpha: 0.15)
              : OneRepColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OneRepColors.gold : OneRepColors.surfaceElevated,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? OneRepColors.gold : OneRepColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LengthStepper extends StatelessWidget {
  const _LengthStepper({required this.length, required this.onChanged});

  final int length;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Cycle length',
              style: TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: length > 2 ? () => onChanged(length - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: OneRepColors.gold,
            disabledColor: OneRepColors.textDisabled,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$length days',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: length < kMaxCycleLength
                ? () => onChanged(length + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: OneRepColors.gold,
            disabledColor: OneRepColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slots
// ---------------------------------------------------------------------------

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.assigned,
    required this.slot,
    required this.onAccept,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final List<ScheduledRoutine> assigned;
  final int slot;
  final ValueChanged<_RoutineDrag> onAccept;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_RoutineDrag>(
      onWillAcceptWithDetails: (details) => details.data.fromSlot != slot,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hovering
                ? OneRepColors.gold.withValues(alpha: 0.12)
                : OneRepColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovering
                  ? OneRepColors.gold
                  : OneRepColors.surfaceElevated,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style: TextStyle(
                    color: assigned.isEmpty
                        ? OneRepColors.textDisabled
                        : OneRepColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: assigned.isEmpty
                    ? const Text(
                        'Rest',
                        style: TextStyle(
                          color: OneRepColors.textDisabled,
                          fontSize: 13,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final routine in assigned)
                            _AssignedChip(
                              routine: routine,
                              slot: slot,
                              onRemove: () => onRemove(routine.routineId),
                            ),
                        ],
                      ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                color: OneRepColors.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Add a routine to $label',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A routine sitting on a day: draggable to another day, tappable to remove.
class _AssignedChip extends StatelessWidget {
  const _AssignedChip({
    required this.routine,
    required this.slot,
    required this.onRemove,
  });

  final ScheduledRoutine routine;
  final int slot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final drag = (
      routineId: routine.routineId,
      name: routine.name,
      fromSlot: slot,
    );

    // Long-press rather than a plain drag: these sit inside a vertically
    // scrolling list, and a plain Draggable would swallow the scroll.
    return LongPressDraggable<_RoutineDrag>(
      data: drag,
      feedback: _DragFeedback(name: routine.name),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _Chip(name: routine.name, onRemove: null),
      ),
      child: _Chip(name: routine.name, onRemove: onRemove),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 6, onRemove == null ? 10 : 4, 6),
      decoration: BoxDecoration(
        color: OneRepColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OneRepColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: OneRepColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close, size: 13, color: OneRepColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: OneRepColors.gold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: const TextStyle(
            color: OneRepColors.background,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// The routines available to place, along the bottom.
class _RoutineTray extends StatelessWidget {
  const _RoutineTray({required this.routines, required this.schedule});

  final List<WorkoutRoutine> routines;
  final SplitSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final placed = {
      for (final routine in schedule.routines)
        if (routine.slots.isNotEmpty) routine.routineId,
    };

    return Container(
      decoration: const BoxDecoration(
        color: OneRepColors.surface,
        border: Border(top: BorderSide(color: OneRepColors.surfaceElevated)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROUTINES',
                style: TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final routine in routines)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: LongPressDraggable<_RoutineDrag>(
                          data: (
                            routineId: routine.id,
                            name: routine.name,
                            fromSlot: null,
                          ),
                          feedback: _DragFeedback(name: routine.name),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _TrayChip(
                              name: routine.name,
                              placed: placed.contains(routine.id),
                            ),
                          ),
                          child: _TrayChip(
                            name: routine.name,
                            placed: placed.contains(routine.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrayChip extends StatelessWidget {
  const _TrayChip({required this.name, required this.placed});

  final String name;

  /// Whether this routine already sits somewhere in the rotation. Dimmed
  /// rather than hidden, because a six-day split places the same routine
  /// twice and removing it from the tray would make the second placement
  /// impossible.
  final bool placed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: OneRepColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: placed
              ? OneRepColors.gold.withValues(alpha: 0.35)
              : OneRepColors.surfaceHighest,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: 15,
            color: placed ? OneRepColors.gold : OneRepColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              color: placed ? OneRepColors.gold : OneRepColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explanations
// ---------------------------------------------------------------------------

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: OneRepColors.textDisabled),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Hold a routine and drag it onto a day, or tap + on the day.',
            style: TextStyle(color: OneRepColors.textDisabled, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _NoSchedule extends StatelessWidget {
  const _NoSchedule();

  @override
  Widget build(BuildContext context) {
    return const _Explainer(
      icon: Icons.event_busy,
      title: 'No rotation',
      body:
          'This split is just a list of routines. Pick Weekly to lay it out '
          'over the days of the week, or Cycle for a rotation that repeats '
          'however often you like — train one day, rest two.',
    );
  }
}

class _NoRoutines extends StatelessWidget {
  const _NoRoutines();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: _Explainer(
        icon: Icons.playlist_add,
        title: 'Nothing to schedule yet',
        body:
            'Add some routines to this split first, then come back and lay '
            'them out over the week.',
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: OneRepColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: OneRepColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
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
