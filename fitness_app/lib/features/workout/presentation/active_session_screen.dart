import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/core/notifications/notification_service.dart';
import '../data/session_repository.dart';
import '../data/exercise_repository.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String sessionTitle;

  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
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

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _timer?.cancel();
    super.dispose();
  }

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
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
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
                Row(
                  children: [
                    const Text('Duration: '),
                    DropdownButton<int>(
                      value: _restDuration,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30s')),
                        DropdownMenuItem(value: 60, child: Text('60s')),
                        DropdownMenuItem(value: 90, child: Text('90s')),
                        DropdownMenuItem(value: 120, child: Text('2min')),
                        DropdownMenuItem(value: 180, child: Text('3min')),
                        DropdownMenuItem(value: 300, child: Text('5min')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _restDuration = value;
                            if (_isTimerRunning) _startTimer();
                          });
                        }
                      },
                    ),
                  ],
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

  Widget _buildExerciseSelector() {
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: exercisesAsync.when(
        data: (exercises) => DropdownButtonFormField<Exercise>(
          initialValue: _selectedExercise,
          decoration: const InputDecoration(
            labelText: 'Select Exercise',
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: exercises
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name),
                ),
              )
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
        error: (err, stack) => Text('Error: $err'),
      ),
    );
  }

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

  void _logSet() {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null || _selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an exercise and enter valid weight and reps.'),
        ),
      );
      return;
    }

    ref.read(sessionRepositoryProvider.notifier).logSet(
          sessionId: widget.sessionId,
          exerciseId: _selectedExercise!.id,
          weight: weight,
          reps: reps,
        );

    // Start rest timer automatically after logging a set
    _startTimer();

    // Clear reps only — weight likely stays the same for next set
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
              // Restart timer if it was running
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