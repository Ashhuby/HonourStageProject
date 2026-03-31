// lib/features/workout/presentation/active_session_screen.dart
// lib/features/workout/presentation/active_session_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/core/notifications/notification_service.dart';
import '../data/session_repository.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import '../data/split_repository.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String sessionTitle;
  final int? routineId; // null means freestyle

  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    this.routineId, // defaults to null
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Exercise? _selectedExercise;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  // Rest timer state
  static const int _defaultRestSeconds = 90;
  int _restDuration = _defaultRestSeconds;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool get _isTimerRunning => _timer != null && _timer!.isActive;

  // PR banner state
  // Holds the most recently detected PR so the banner widget can render it.
  // Null means no banner is shown. Cleared automatically after a fixed duration.
  PrResult? _latestPr;
  Timer? _prBannerTimer;

  // PR banner state
  // Holds the most recently detected PR so the banner widget can render it.
  // Null means no banner is shown. Cleared automatically after a fixed duration.
  PrResult? _latestPr;
  Timer? _prBannerTimer;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _timer?.cancel();
    _prBannerTimer?.cancel();
    _prBannerTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Rest timer
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Rest timer
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = _restDuration);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimerComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 0);
  }

  void _onTimerComplete() {
    HapticFeedback.vibrate();
    NotificationService().showRestCompleteNotification();
    setState(() => _remainingSeconds = 0);
  }

  // ---------------------------------------------------------------------------
  // PR banner
  // ---------------------------------------------------------------------------

  /// Shows the PR banner for [_prBannerDuration] then clears it.
  /// If a second PR fires while the banner is already visible, the banner
  /// resets to the new PR and the timer restarts — the user always sees
  /// the most recent result.
  static const _prBannerDuration = Duration(seconds: 5);

  void _showPrBanner(PrResult pr) {
    _prBannerTimer?.cancel();
    setState(() => _latestPr = pr);
    HapticFeedback.heavyImpact();

    _prBannerTimer = Timer(_prBannerDuration, () {
      if (mounted) setState(() => _latestPr = null);
    });
  }

  void _dismissPrBanner() {
    _prBannerTimer?.cancel();
    setState(() => _latestPr = null);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // PR banner
  // ---------------------------------------------------------------------------

  /// Shows the PR banner for [_prBannerDuration] then clears it.
  /// If a second PR fires while the banner is already visible, the banner
  /// resets to the new PR and the timer restarts — the user always sees
  /// the most recent result.
  static const _prBannerDuration = Duration(seconds: 5);

  void _showPrBanner(PrResult pr) {
    _prBannerTimer?.cancel();
    setState(() => _latestPr = pr);
    HapticFeedback.heavyImpact();

    _prBannerTimer = Timer(_prBannerDuration, () {
      if (mounted) setState(() => _latestPr = null);
    });
  }

  void _dismissPrBanner() {
    _prBannerTimer?.cancel();
    setState(() => _latestPr = null);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final setsAsync =
        ref.watch(watchSetsForSessionProvider(widget.sessionId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEndSession(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sessionTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmEndSession(context),
          ),
          actions: [
            TextButton(
              onPressed: () => _confirmEndSession(context),
              child: const Text(
                'Finish',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildExerciseSelector(),
            const Divider(height: 1),
            if (_selectedExercise != null) _buildSetLogger(),
            const Divider(height: 1),
            if (_remainingSeconds > 0 || _isTimerRunning)
              _buildRestTimer(),
            // PR banner sits above the sets list, below the rest timer.
            // AnimatedSwitcher gives a smooth fade — no jarring pop.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _latestPr != null
                  ? _buildPrBanner(_latestPr!)
                  : const SizedBox.shrink(),
            ),
            // PR banner sits above the sets list, below the rest timer.
            // AnimatedSwitcher gives a smooth fade — no jarring pop.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _latestPr != null
                  ? _buildPrBanner(_latestPr!)
                  : const SizedBox.shrink(),
            ),
            const Divider(height: 1),
            Expanded(
              child: setsAsync.when(
                data: (sets) => sets.isEmpty
                    ? const Center(
                        child: Text(
                          'No sets logged yet.\nSelect an exercise and log your first set.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _buildSetsList(sets),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PR banner widget
  // ---------------------------------------------------------------------------

  Widget _buildPrBanner(PrResult pr) {
    return GestureDetector(
      onTap: _dismissPrBanner,
      child: Container(
        // Use a key so AnimatedSwitcher treats each new PR as a distinct widget
        // and re-runs the fade animation even if two consecutive PRs fire.
        key: ValueKey('${pr.exerciseId}-${pr.reps}-${pr.weight}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700,
              Colors.orange.shade600,
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🏆 New Personal Record!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${pr.exerciseName} — ${pr.weight}kg × ${pr.reps} reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Dismiss handle — small affordance so the user knows it's tappable.
            const Icon(Icons.close, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rest timer widget (unchanged)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // PR banner widget
  // ---------------------------------------------------------------------------

  Widget _buildPrBanner(PrResult pr) {
    return GestureDetector(
      onTap: _dismissPrBanner,
      child: Container(
        // Use a key so AnimatedSwitcher treats each new PR as a distinct widget
        // and re-runs the fade animation even if two consecutive PRs fire.
        key: ValueKey('${pr.exerciseId}-${pr.reps}-${pr.weight}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700,
              Colors.orange.shade600,
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🏆 New Personal Record!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${pr.exerciseName} — ${pr.weight}kg × ${pr.reps} reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Dismiss handle — small affordance so the user knows it's tappable.
            const Icon(Icons.close, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rest timer widget (unchanged)
  // ---------------------------------------------------------------------------

  Widget _buildRestTimer() {
    final progress = _remainingSeconds / _restDuration;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer
                      .withValues(alpha: 0.2),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer
                      .withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Center(
                  child: Text(
                    timeString,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rest Timer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _restDuration.toDouble(),
                  min: 30,
                  max: 300,
                  divisions: 9,
                  label: '${_restDuration}s',
                  onChanged: (value) {
                    setState(() => _restDuration = value.toInt());
                  },
                Slider(
                  value: _restDuration.toDouble(),
                  min: 30,
                  max: 300,
                  divisions: 9,
                  label: '${_restDuration}s',
                  onChanged: (value) {
                    setState(() => _restDuration = value.toInt());
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: 'Skip rest',
            onPressed: _stopTimer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart timer',
            onPressed: _startTimer,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Exercise selector 
  // ---------------------------------------------------------------------------

  Widget _buildExerciseSelector() {
  // If this session has a routine, show only that routine's exercises.
  // If freestyle (no routineId), show the full library.
  if (widget.routineId != null) {
    final routineExercisesAsync = ref.watch(
      watchExercisesForRoutineWithNamesProvider(widget.routineId!),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: routineExercisesAsync.when(
        data: (routineExercises) {
          // Convert RoutineExerciseWithName → Exercise-like dropdown items.
          // We need the Exercise object for logSet, so we match by exerciseId.
          return DropdownButtonFormField<Exercise>(
            value: _selectedExercise,
            decoration: const InputDecoration(
              labelText: 'Select Exercise',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: routineExercises.map((re) {
              // Build a minimal Exercise from the joined data.
              // We only need id and name for logSet + PR detection.
              return DropdownMenuItem<Exercise>(
                value: Exercise(
                  id: re.routineExercise.exerciseId,
                  name: re.exerciseName,
                  bodyPart: re.bodyPart,
                  equipmentType: re.equipmentType,
                  isCustom: false,
                ),
                child: Text(re.exerciseName),
              );
            }).toList(),
            onChanged: (exercise) {
              setState(() {
                _selectedExercise = exercise;
                _weightController.clear();
                _repsController.clear();
              });
            },
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (err, _) => Text('Error: $err'),
      ),
    );
  }

  // Freestyle — full exercise library
  final exercisesAsync = ref.watch(watchExercisesProvider);
  return Padding(
    padding: const EdgeInsets.all(12),
    child: exercisesAsync.when(
      data: (exercises) => DropdownButtonFormField<Exercise>(
        value: _selectedExercise,
        decoration: const InputDecoration(
          labelText: 'Select Exercise',
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: exercises
            .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
            .toList(),
        onChanged: (exercise) {
          setState(() {
            _selectedExercise = exercise;
            _weightController.clear();
            _repsController.clear();
          });
        },
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Text('Error: $err'),
    ),
  );
}

  // ---------------------------------------------------------------------------
  // Set logger 
  // ---------------------------------------------------------------------------

  Widget _buildSetLogger() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _logSet,
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sets list 
  // ---------------------------------------------------------------------------

  Widget _buildSetsList(List<WorkoutSetWithExercise> sets) {
    final Map<String, List<WorkoutSetWithExercise>> grouped = {};
    for (final s in sets) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final exerciseName = grouped.keys.elementAt(index);
        final exerciseSets = grouped[exerciseName]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                ...exerciseSets.asMap().entries.map((entry) {
                  final setNum = entry.key + 1;
                  final s = entry.value;
                  return Dismissible(
                    key: ValueKey(s.set.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(sessionRepositoryProvider.notifier)
                          .deleteSet(s.set.id);
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Set $setNum',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          Text('${s.set.weight}kg × ${s.set.reps} reps'),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Logs a set, starts the rest timer, and surfaces any PR immediately.
  /// This method is now async — it awaits logSet so the PR result is available
  /// before the UI updates. The rest timer starts regardless of PR detection.
  Future<void> _logSet() async {
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Logs a set, starts the rest timer, and surfaces any PR immediately.
  /// This method is now async — it awaits logSet so the PR result is available
  /// before the UI updates. The rest timer starts regardless of PR detection.
  Future<void> _logSet() async {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null || _selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select an exercise and enter valid weight and reps.'),
          content: Text(
              'Please select an exercise and enter valid weight and reps.'),
        ),
      );
      return;
    }

    // Start the rest timer immediately — don't wait for PR detection.
    // The DB write + PR check is fast but the UX should feel instant.
    _startTimer();

    // Await the full logSet pipeline: insert → PR check → badge evaluation.
    final prResult = await ref
        .read(sessionRepositoryProvider.notifier)
        .logSet(
    // Start the rest timer immediately — don't wait for PR detection.
    // The DB write + PR check is fast but the UX should feel instant.
    _startTimer();

    // Await the full logSet pipeline: insert → PR check → badge evaluation.
    final prResult = await ref
        .read(sessionRepositoryProvider.notifier)
        .logSet(
          sessionId: widget.sessionId,
          exerciseId: _selectedExercise!.id,
          exerciseName: _selectedExercise!.name,
          exerciseName: _selectedExercise!.name,
          weight: weight,
          reps: reps,
        );

    // Show the PR banner if a new record was set.
    // Guard with mounted — the user could theoretically navigate away
    // in the ~50ms it takes for the DB write to complete.
    if (mounted && prResult != null) {
      _showPrBanner(prResult);
    }
    // Show the PR banner if a new record was set.
    // Guard with mounted — the user could theoretically navigate away
    // in the ~50ms it takes for the DB write to complete.
    if (mounted && prResult != null) {
      _showPrBanner(prResult);
    }

    // Clear reps only — weight likely stays the same for the next set.
    // Clear reps only — weight likely stays the same for the next set.
    _repsController.clear();
  }

  void _confirmEndSession(BuildContext context) {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text(
          'This will end your session. You cannot add sets after finishing.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_remainingSeconds > 0) _startTimer();
            },
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(sessionRepositoryProvider.notifier)
                  .endSession(widget.sessionId);
              await NotificationService().cancelAll();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}