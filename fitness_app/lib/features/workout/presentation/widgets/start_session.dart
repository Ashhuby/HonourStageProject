/// Starting a routine, from wherever the user asked for it.
///
/// Lifted out of the routine sheet once the Today card gained its own Start
/// button. The interesting part is not the start — it is what happens when a
/// session is already open, and two copies of that would have drifted into two
/// different answers to the same question.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/session_repository.dart';
import '../active_session_screen.dart';

/// What to do about a session that is already in progress.
enum _InProgressChoice { resume, discard }

/// Starts [routineName], or resumes whatever is already running.
///
/// [popFirst] closes the sheet or dialog the request came from before doing
/// anything else. The navigator is captured up front because popping
/// deactivates that context and everything here runs after it.
Future<void> startRoutineSession(
  BuildContext context,
  WidgetRef ref, {
  required int routineId,
  required String routineName,
  bool popFirst = false,
}) async {
  final navigator = Navigator.of(context);
  if (popFirst) Navigator.pop(context);

  final active = await ref.read(watchActiveSessionProvider.future);

  if (active != null) {
    if (!navigator.mounted) return;

    final choice = await showDialog<_InProgressChoice>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Workout In Progress'),
        content: Text(
          'You have an unfinished ${active.title} session. Resume it, or '
          'discard it and start $routineName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
            onPressed: () =>
                Navigator.pop(dialogContext, _InProgressChoice.discard),
            child: const Text('Discard & Start'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.gold),
            onPressed: () =>
                Navigator.pop(dialogContext, _InProgressChoice.resume),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    switch (choice) {
      case null:
        return;
      case _InProgressChoice.resume:
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ActiveSessionScreen(
              sessionId: active.session.id,
              sessionTitle: active.title,
              routineId: active.routineId,
            ),
          ),
        );
        return;
      case _InProgressChoice.discard:
        await ref
            .read(sessionRepositoryProvider.notifier)
            .deleteSession(active.session.id);
    }
  }

  final sessionId = await ref
      .read(sessionRepositoryProvider.notifier)
      .startSession(routineId: routineId);

  if (!navigator.mounted) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        sessionId: sessionId,
        sessionTitle: routineName,
        routineId: routineId,
      ),
    ),
  );
}
