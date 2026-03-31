import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/core/notifications/notification_service.dart';
import '../../../main.dart';
import '../data/session_repository.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import '../data/split_repository.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String sessionTitle;
  final int? routineId;

  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    this.routineId,
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Exercise? _selectedExercise;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  // Rest timer
  static const int _defaultRestSeconds = 90;
  int _restDuration = _defaultRestSeconds;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool get _isTimerRunning => _timer != null && _timer!.isActive;

  // PR banner
  PrResult? _latestPr;
  Timer? _prBannerTimer;
  static const _prBannerDuration = Duration(seconds: 5);

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _timer?.cancel();
    _prBannerTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Timer
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
    final setsAsync = ref.watch(watchSetsForSessionProvider(widget.sessionId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEndSession(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => _confirmEndSession(context),
          ),
          title: Column(
            children: [
              Text(
                widget.sessionTitle.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: OneRepColors.textPrimary,
                ),
              ),
              const Text(
                'IN PROGRESS',
                style: TextStyle(
                  fontSize: 10,
                  color: OneRepColors.gold,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _confirmEndSession(context),
              child: const Text(
                'FINISH',
                style: TextStyle(
                  color: OneRepColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // PR banner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _latestPr != null
                  ? _PrBanner(
                      pr: _latestPr!,
                      onDismiss: _dismissPrBanner,
                    )
                  : const SizedBox.shrink(),
            ),

            // Rest timer — only visible when active
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: (_remainingSeconds > 0 || _isTimerRunning)
                  ? _RestTimerBar(
                      remainingSeconds: _remainingSeconds,
                      totalSeconds: _restDuration,
                      onSkip: _stopTimer,
                      onRestart: _startTimer,
                      onDurationChanged: (d) {
                        setState(() {
                          _restDuration = d;
                          if (_isTimerRunning) _startTimer();
                        });
                      },
                    )
                  : const SizedBox.shrink(),
            ),

            // Exercise selector
            _buildExerciseSelector(),

            // Set logger
            if (_selectedExercise != null) _buildSetLogger(),

            Container(height: 1, color: OneRepColors.surfaceElevated),

            // Sets list
            Expanded(
              child: setsAsync.when(
                data: (sets) => sets.isEmpty
                    ? const _EmptySessionState()
                    : _buildSetsList(sets),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Exercise selector
  // ---------------------------------------------------------------------------

  Widget _buildExerciseSelector() {
    if (widget.routineId != null) {
      final routineExAsync = ref.watch(
        watchExercisesForRoutineWithNamesProvider(widget.routineId!),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: routineExAsync.when(
          data: (routineExercises) => DropdownButtonFormField<Exercise>(
            value: _selectedExercise,
            decoration: const InputDecoration(
              labelText: 'Exercise',
              prefixIcon: Icon(Icons.fitness_center, size: 18),
            ),
            dropdownColor: OneRepColors.surfaceElevated,
            style: const TextStyle(color: OneRepColors.textPrimary),
            items: routineExercises.map((re) {
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
            onChanged: (exercise) => setState(() {
              _selectedExercise = exercise;
              _weightController.clear();
              _repsController.clear();
            }),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => Text('Error: $err'),
        ),
      );
    }

    final exercisesAsync = ref.watch(watchExercisesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: exercisesAsync.when(
        data: (exercises) => DropdownButtonFormField<Exercise>(
          value: _selectedExercise,
          decoration: const InputDecoration(
            labelText: 'Exercise',
            prefixIcon: Icon(Icons.fitness_center, size: 18),
          ),
          dropdownColor: OneRepColors.surfaceElevated,
          style: const TextStyle(color: OneRepColors.textPrimary),
          items: exercises
              .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
              .toList(),
          onChanged: (exercise) => setState(() {
            _selectedExercise = exercise;
            _weightController.clear();
            _repsController.clear();
          }),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => Text('Error: $err'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Set logger
  // ---------------------------------------------------------------------------

  Widget _buildSetLogger() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Reps',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _logSet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('LOG'),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final exerciseName = grouped.keys.elementAt(index);
        final exerciseSets = grouped[exerciseName]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: OneRepColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: const Border(
                left: BorderSide(color: OneRepColors.gold, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Text(
                    exerciseName,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ...exerciseSets.asMap().entries.map((entry) {
                  final setNum = entry.key + 1;
                  final s = entry.value;
                  return Dismissible(
                    key: ValueKey(s.set.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: OneRepColors.error.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.delete_outline,
                        color: OneRepColors.error,
                        size: 18,
                      ),
                    ),
                    onDismissed: (_) => ref
                        .read(sessionRepositoryProvider.notifier)
                        .deleteSet(s.set.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        children: [
                          // Set number chip
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: OneRepColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '$setNum',
                                style: const TextStyle(
                                  color: OneRepColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${s.set.weight}kg',
                            style: const TextStyle(
                              color: OneRepColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '×',
                            style: TextStyle(
                              color: OneRepColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.set.reps} reps',
                            style: const TextStyle(
                              color: OneRepColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
  // Log set
  // ---------------------------------------------------------------------------

  Future<void> _logSet() async {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null || _selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an exercise and enter valid weight and reps.'),
        ),
      );
      return;
    }

    _startTimer();

    final prResult = await ref
        .read(sessionRepositoryProvider.notifier)
        .logSet(
          sessionId: widget.sessionId,
          exerciseId: _selectedExercise!.id,
          exerciseName: _selectedExercise!.name,
          weight: weight,
          reps: reps,
        );

    if (mounted && prResult != null) _showPrBanner(prResult);

    _repsController.clear();
  }

  // ---------------------------------------------------------------------------
  // End session dialog — three options
  // ---------------------------------------------------------------------------

  void _confirmEndSession(BuildContext context) {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Workout'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_remainingSeconds > 0) _startTimer();
            },
            child: const Text('Keep Going'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: OneRepColors.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Workout?'),
                  content: const Text(
                    'This session and all logged sets will be permanently '
                    'deleted. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Back'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: OneRepColors.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete Session'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(sessionRepositoryProvider.notifier)
                    .deleteSession(widget.sessionId);
                await NotificationService().cancelAll();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Cancel Workout'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: OneRepColors.gold,
            ),
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

// ---------------------------------------------------------------------------
// PR Banner
// ---------------------------------------------------------------------------

class _PrBanner extends StatelessWidget {
  final PrResult pr;
  final VoidCallback onDismiss;

  const _PrBanner({required this.pr, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        key: ValueKey('${pr.exerciseId}-${pr.reps}-${pr.weight}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              OneRepColors.gold.withValues(alpha: 0.25),
              OneRepColors.gold.withValues(alpha: 0.10),
            ],
          ),
          border: const Border(
            bottom: BorderSide(color: OneRepColors.gold, width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: OneRepColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEW PERSONAL RECORD',
                    style: TextStyle(
                      color: OneRepColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pr.exerciseName}  ${pr.weight}kg × ${pr.reps} reps',
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.close, color: OneRepColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest Timer Bar
// ---------------------------------------------------------------------------

class _RestTimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onSkip;
  final VoidCallback onRestart;
  final ValueChanged<int> onDurationChanged;

  const _RestTimerBar({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onSkip,
    required this.onRestart,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Colour transitions: gold → orange → red as time runs out
    final timerColor = progress > 0.5
        ? OneRepColors.gold
        : progress > 0.25
            ? OneRepColors.coral
            : OneRepColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OneRepColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(
            color: timerColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: OneRepColors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Timer display
              Text(
                timeString,
                style: TextStyle(
                  color: timerColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'REST',
                style: TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // Duration picker
              DropdownButton<int>(
                value: totalSeconds,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: OneRepColors.surfaceElevated,
                style: const TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 13,
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30s')),
                  DropdownMenuItem(value: 60, child: Text('60s')),
                  DropdownMenuItem(value: 90, child: Text('90s')),
                  DropdownMenuItem(value: 120, child: Text('2min')),
                  DropdownMenuItem(value: 180, child: Text('3min')),
                  DropdownMenuItem(value: 300, child: Text('5min')),
                ],
                onChanged: (v) {
                  if (v != null) onDurationChanged(v);
                },
              ),
              const SizedBox(width: 4),
              // Skip
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 22),
                color: OneRepColors.textSecondary,
                tooltip: 'Skip rest',
                onPressed: onSkip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
              // Restart
              IconButton(
                icon: const Icon(Icons.replay_rounded, size: 20),
                color: OneRepColors.textSecondary,
                tooltip: 'Restart timer',
                onPressed: onRestart,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
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
// Empty session state
// ---------------------------------------------------------------------------

class _EmptySessionState extends StatelessWidget {
  const _EmptySessionState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              color: OneRepColors.textDisabled,
              size: 44,
            ),
            SizedBox(height: 16),
            Text(
              'No sets logged yet.',
              style: TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Select an exercise above and log your first set.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OneRepColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}