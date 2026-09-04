import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/rest_timer.dart';
import '../../../core/utils/set_formatter.dart';
import '../data/session_repository.dart';
import '../data/personal_best_repository.dart';
import '../data/split_repository.dart';
import 'widgets/exercise_field.dart';
import 'widgets/exercise_picker_sheet.dart';

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

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  Exercise? _selectedExercise;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  // Duration controllers for timeOnly / distanceTime
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();
  // Distance controller for distanceTime
  final _distanceController = TextEditingController();

  // Rest timer.
  //
  // [_restEndsAt] is the source of truth, not [_remainingSeconds]: the ticker
  // only refreshes the display from the wall clock, so a locked or evicted app
  // resumes with the correct time left instead of a stale countdown.
  static const int _defaultRestSeconds = 90;
  int _restDuration = _defaultRestSeconds;
  int _remainingSeconds = 0;
  DateTime? _restEndsAt;
  Timer? _timer;
  bool get _isTimerRunning => _timer != null && _timer!.isActive;

  // PR banner
  PrResult? _latestPr;
  Timer? _prBannerTimer;
  static const _prBannerDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers are frozen while the app is backgrounded, so the countdown is
    // recomputed the moment the user comes back rather than a tick later.
    // No haptic here: if rest finished while away, the scheduled notification
    // already did the alerting.
    if (state == AppLifecycleState.resumed) _syncRest(alert: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weightController.dispose();
    _repsController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _distanceController.dispose();
    _timer?.cancel();
    _prBannerTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  /// Starts rest, scheduling the alert for the instant it ends.
  ///
  /// The notification is scheduled up front rather than fired when the ticker
  /// runs out, so it still arrives if the phone is locked or the app is
  /// evicted during the set.
  /// Whether logging this kind of set should start the rest countdown.
  ///
  /// True for the two rep-based metrics. Timed holds are borderline — a plank
  /// is a set you rest after — but `timeOnly` also covers every stretch and a
  /// jump-rope round, so the metric alone cannot tell them apart and the
  /// quieter default is the right one.
  bool _restsBetweenSets(String metricType) =>
      metricType == 'weightReps' || metricType == 'bodyweightReps';

  void _startTimer() {
    final endsAt = DateTime.now().add(Duration(seconds: _restDuration));
    setState(() {
      _restEndsAt = endsAt;
      _remainingSeconds = _restDuration;
    });
    NotificationService().scheduleRestCompleteNotification(endsAt);
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncRest());
  }

  /// Refreshes the countdown from the wall clock, ending rest once [_restEndsAt]
  /// has passed.
  void _syncRest({bool alert = true}) {
    final endsAt = _restEndsAt;
    if (endsAt == null) return;

    final remaining = restSecondsRemaining(endsAt, DateTime.now());
    if (remaining > 0) {
      if (remaining != _remainingSeconds) {
        setState(() => _remainingSeconds = remaining);
      }
      return;
    }

    _timer?.cancel();
    _timer = null;
    setState(() {
      _remainingSeconds = 0;
      _restEndsAt = null;
    });
    // The scheduled notification carries the alert; this is the in-app cue.
    if (alert) HapticFeedback.vibrate();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    NotificationService().cancelRestNotification();
    setState(() {
      _remainingSeconds = 0;
      _restEndsAt = null;
    });
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
          // X button removed — FINISH button in actions is sufficient
          automaticallyImplyLeading: false,
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
                  ? _PrBanner(pr: _latestPr!, onDismiss: _dismissPrBanner)
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

            // Last session + personal best for the selected exercise
            if (_selectedExercise != null)
              _ExerciseReferenceCard(
                exercise: _selectedExercise!,
                sessionId: widget.sessionId,
                onSetTap: _prefillFromSet,
              ),

            // Progress against the routine's plan for this exercise
            if (_selectedExercise != null && widget.routineId != null)
              _RoutineTargetBar(
                routineId: widget.routineId!,
                exercise: _selectedExercise!,
                sessionId: widget.sessionId,
              ),

            // Set logger
            if (_selectedExercise != null) _buildSetLogger(),

            Container(height: 1, color: OneRepColors.surfaceElevated),

            // Sets list
            Expanded(
              child: setsAsync.when(
                data: (sets) => sets.isEmpty
                    ? const _EmptySessionState()
                    : _buildSetsList(sets),
                loading: () => const Center(child: CircularProgressIndicator()),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ExerciseField(
        exercise: _selectedExercise,
        onTap: _openExercisePicker,
      ),
    );
  }

  /// Opens the shared picker and adopts the choice.
  ///
  /// A routine-backed session stays restricted to the exercises planned for
  /// that day — the picker just presents them far better than the dropdown it
  /// replaces, showing each one's target alongside it.
  Future<void> _openExercisePicker() async {
    Set<int>? restrictToIds;
    var trailingLabels = const <int, String>{};

    final routineId = widget.routineId;
    if (routineId != null) {
      final planned = await ref.read(
        watchExercisesForRoutineWithNamesProvider(routineId).future,
      );
      restrictToIds = {for (final entry in planned) entry.exercise.id};
      trailingLabels = {
        for (final entry in planned)
          entry.exercise.id:
              '${entry.routineExercise.targetSets} × '
              '${entry.routineExercise.targetReps}',
      };
    }

    if (!mounted) return;
    final picked = await showExercisePicker(
      context,
      restrictToIds: restrictToIds,
      trailingLabels: trailingLabels,
      title: 'Choose exercise',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedExercise = picked;
      _weightController.clear();
      _repsController.clear();
      _minutesController.clear();
      _secondsController.clear();
      _distanceController.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Set logger
  // ---------------------------------------------------------------------------

  Widget _buildSetLogger() {
    final metricType = _selectedExercise?.metricType ?? 'weightReps';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // ---- weightReps ----
              if (metricType == 'weightReps') ...[
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
              ],

              // ---- bodyweightReps ----
              if (metricType == 'bodyweightReps') ...[
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Added Weight',
                      suffixText: 'kg',
                      hintText: 'Optional',
                    ),
                  ),
                ),
              ],

              // ---- timeOnly ----
              if (metricType == 'timeOnly') ...[
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      suffixText: 'min',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      suffixText: 'sec',
                    ),
                  ),
                ),
              ],

              // ---- distanceTime ----
              if (metricType == 'distanceTime') ...[
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Distance',
                      suffixText: 'm',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      suffixText: 'min',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      suffixText: 'sec',
                    ),
                  ),
                ),
              ],

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
                    child: InkWell(
                      onTap: () => _editSet(s),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Row(
                          children: [
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
                            Expanded(
                              child: Text(
                                formatWorkoutSet(s.set),
                                style: const TextStyle(
                                  color: OneRepColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: OneRepColors.textDisabled,
                            ),
                          ],
                        ),
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

  // ---------------------------------------------------------------------------
  // Edit a logged set
  // ---------------------------------------------------------------------------

  /// Opens the editor for an already-logged set.
  ///
  /// Corrections have to be possible without deleting and relogging: a
  /// mistyped weight that set a personal best would otherwise leave the record
  /// behind when the set is removed.
  Future<void> _editSet(WorkoutSetWithExercise entry) async {
    final result = await showDialog<_SetValues>(
      context: context,
      builder: (_) => _EditSetDialog(entry: entry),
    );
    if (result == null) return;

    await ref
        .read(sessionRepositoryProvider.notifier)
        .updateSet(
          setId: entry.set.id,
          weight: result.weight,
          reps: result.reps,
          durationSeconds: result.durationSeconds,
          distanceMetres: result.distanceMetres,
        );
  }

  // ---------------------------------------------------------------------------
  // Prefill — copies a previous set into the input fields
  // ---------------------------------------------------------------------------

  /// Fills the logger with the values from [set] so a repeated set can be
  /// logged without retyping, or nudged up from last session's numbers.
  void _prefillFromSet(WorkoutSet set) {
    HapticFeedback.selectionClick();
    if (set.durationSeconds != null) {
      _minutesController.text = '${set.durationSeconds! ~/ 60}';
      _secondsController.text = '${set.durationSeconds! % 60}';
    } else {
      _repsController.text = '${set.reps}';
    }
    _weightController.text = set.weight > 0 ? formatNumber(set.weight) : '';
    _distanceController.text = set.distanceMetres != null
        ? formatNumber(set.distanceMetres!)
        : '';
  }

  Future<void> _logSet() async {
    if (_selectedExercise == null) return;
    final metricType = _selectedExercise!.metricType;

    double weight = 0.0;
    int reps = 0;
    int? durationSeconds;
    double? distanceMetres;

    switch (metricType) {
      case 'weightReps':
        final w = double.tryParse(_weightController.text);
        final r = int.tryParse(_repsController.text);
        if (w == null || r == null) {
          _showInputError('Enter valid weight and reps.');
          return;
        }
        weight = w;
        reps = r;
        break;

      case 'bodyweightReps':
        final r = int.tryParse(_repsController.text);
        if (r == null) {
          _showInputError('Enter valid reps.');
          return;
        }
        reps = r;
        weight = double.tryParse(_weightController.text) ?? 0.0;
        break;

      case 'timeOnly':
        final mins = int.tryParse(_minutesController.text) ?? 0;
        final secs = int.tryParse(_secondsController.text) ?? 0;
        if (mins == 0 && secs == 0) {
          _showInputError('Enter a duration.');
          return;
        }
        durationSeconds = mins * 60 + secs;
        break;

      case 'distanceTime':
        final dist = double.tryParse(_distanceController.text);
        final mins = int.tryParse(_minutesController.text) ?? 0;
        final secs = int.tryParse(_secondsController.text) ?? 0;
        if (dist == null || (mins == 0 && secs == 0)) {
          _showInputError('Enter valid distance and time.');
          return;
        }
        distanceMetres = dist;
        durationSeconds = mins * 60 + secs;
        break;
    }

    // Rest between sets is a lifting idea. A run or a stretch is the session,
    // not one effort within it, so counting down 90 seconds afterwards — and
    // scheduling a notification for it — is noise. The user can still start
    // the timer by hand from the rest card.
    if (_restsBetweenSets(metricType)) {
      _startTimer();
    }

    final prResult = await ref
        .read(sessionRepositoryProvider.notifier)
        .logSet(
          sessionId: widget.sessionId,
          exerciseId: _selectedExercise!.id,
          exerciseName: _selectedExercise!.name,
          metricType: metricType,
          weight: weight,
          reps: reps,
          durationSeconds: durationSeconds,
          distanceMetres: distanceMetres,
        );

    if (mounted && prResult != null) _showPrBanner(prResult);
    _repsController.clear();
    _minutesController.clear();
    _secondsController.clear();
    _distanceController.clear();
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // End session dialog — three options
  // ---------------------------------------------------------------------------

  void _confirmEndSession(BuildContext context) {
    // The countdown keeps running behind the dialog — it is anchored to a
    // wall-clock instant, so pausing it would only make it wrong.

    // Capture the screen's navigator HERE — before any dialogs open.
    // Dialog builders shadow 'context' with their own local context,
    // and after async gaps those dialog contexts are deactivated.
    // The screen's navigator reference stays valid for the lifetime
    // of this widget regardless of how many dialogs open and close.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    /// Reports a failure instead of leaving the button looking dead.
    ///
    /// Both of these buttons ended in an `await` followed by a pop, so
    /// anything that threw took the navigation with it and the user was left
    /// on a screen whose buttons did nothing and said nothing. Whatever else
    /// goes wrong, a press has to visibly do something.
    void report(String what, Object error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not $what: $error'),
          backgroundColor: OneRepColors.error,
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Workout'),
        content: const Text('What would you like to do?'),
        actions: [
          // Keep Going
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep Going'),
          ),

          // Cancel Workout — destructive, requires second confirmation
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext); // close first dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Cancel Workout?'),
                  content: const Text(
                    'This session and all logged sets will be permanently '
                    'deleted. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Back'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: OneRepColors.error,
                      ),
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const Text('Delete Session'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              try {
                await ref
                    .read(sessionRepositoryProvider.notifier)
                    .deleteSession(widget.sessionId);
              } catch (error) {
                report('delete the session', error);
                return;
              }

              await NotificationService().cancelAll();
              // Use the pre-captured screen navigator — always valid.
              navigator.popUntil((route) => route.isFirst);
            },
            child: const Text('Cancel Workout'),
          ),

          // Finish — end session, badge evaluation fires in endSession
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.gold),
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await ref
                    .read(sessionRepositoryProvider.notifier)
                    .endSession(widget.sessionId);
              } catch (error) {
                // The session is still open, so the user stays on it rather
                // than being returned to the home screen as though the
                // workout had been saved.
                report('finish the workout', error);
                return;
              }

              await NotificationService().cancelAll();
              navigator.popUntil((route) => route.isFirst);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Routine target progress
// ---------------------------------------------------------------------------

/// Progress against the routine's plan for the selected exercise.
///
/// The plan is set when a routine is built but was invisible while training,
/// leaving the user to remember how many sets were meant to be left. Shows
/// nothing for an exercise the routine does not include.
class _RoutineTargetBar extends ConsumerWidget {
  final int routineId;
  final Exercise exercise;
  final int sessionId;

  const _RoutineTargetBar({
    required this.routineId,
    required this.exercise,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = ref
        .watch(watchExercisesForRoutineWithNamesProvider(routineId))
        .valueOrNull;
    if (planned == null) return const SizedBox.shrink();

    RoutineExerciseWithName? target;
    for (final entry in planned) {
      if (entry.routineExercise.exerciseId == exercise.id) {
        target = entry;
        break;
      }
    }
    if (target == null) return const SizedBox.shrink();

    final sets = ref.watch(watchSetsForSessionProvider(sessionId)).valueOrNull;
    final logged =
        sets?.where((s) => s.set.exerciseId == exercise.id).length ?? 0;
    final targetSets = target.routineExercise.targetSets;
    final targetReps = target.routineExercise.targetReps;
    final met = logged >= targetSets;

    final label = formatTargetProgress(
      logged: logged,
      targetSets: targetSets,
      targetReps: targetReps,
      metricType: exercise.metricType,
      targetDistanceMetres: target.routineExercise.targetDistanceMetres,
      targetDurationSeconds: target.routineExercise.targetDurationSeconds,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          for (int i = 0; i < targetSets; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < logged
                      ? OneRepColors.gold
                      : OneRepColors.surfaceHighest,
                ),
              ),
            ),
          if (logged > targetSets)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '+${logged - targetSets}',
                style: const TextStyle(
                  color: OneRepColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: met ? OneRepColors.gold : OneRepColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit set dialog
// ---------------------------------------------------------------------------

/// The values a set records. Which ones matter depends on the metric type.
class _SetValues {
  final double weight;
  final int reps;
  final int? durationSeconds;
  final double? distanceMetres;

  const _SetValues({
    this.weight = 0.0,
    this.reps = 0,
    this.durationSeconds,
    this.distanceMetres,
  });
}

/// Edits one logged set, showing the fields its metric type actually records.
class _EditSetDialog extends StatefulWidget {
  final WorkoutSetWithExercise entry;

  const _EditSetDialog({required this.entry});

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;
  late final TextEditingController _distance;
  String? _error;

  String get _metricType => widget.entry.metricType;

  @override
  void initState() {
    super.initState();
    final set = widget.entry.set;
    final duration = set.durationSeconds ?? 0;

    _weight = TextEditingController(
      text: set.weight > 0 ? formatNumber(set.weight) : '',
    );
    _reps = TextEditingController(text: set.reps > 0 ? '${set.reps}' : '');
    _minutes = TextEditingController(
      text: duration > 0 ? '${duration ~/ 60}' : '',
    );
    _seconds = TextEditingController(
      text: duration > 0 ? '${duration % 60}' : '',
    );
    _distance = TextEditingController(
      text: set.distanceMetres != null ? formatNumber(set.distanceMetres!) : '',
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _minutes.dispose();
    _seconds.dispose();
    _distance.dispose();
    super.dispose();
  }

  /// Reads the fields for this metric type, or sets [_error] and returns null.
  _SetValues? _read() {
    switch (_metricType) {
      case 'bodyweightReps':
        final reps = int.tryParse(_reps.text);
        if (reps == null || reps <= 0) {
          _error = 'Enter valid reps.';
          return null;
        }
        return _SetValues(
          reps: reps,
          weight: double.tryParse(_weight.text) ?? 0.0,
        );

      case 'timeOnly':
        final seconds = _readDuration();
        if (seconds == null) {
          _error = 'Enter a duration.';
          return null;
        }
        return _SetValues(durationSeconds: seconds);

      case 'distanceTime':
        final distance = double.tryParse(_distance.text);
        final seconds = _readDuration();
        if (distance == null || distance <= 0 || seconds == null) {
          _error = 'Enter valid distance and time.';
          return null;
        }
        return _SetValues(distanceMetres: distance, durationSeconds: seconds);

      default: // weightReps
        final weight = double.tryParse(_weight.text);
        final reps = int.tryParse(_reps.text);
        if (weight == null || reps == null || reps <= 0) {
          _error = 'Enter valid weight and reps.';
          return null;
        }
        return _SetValues(weight: weight, reps: reps);
    }
  }

  int? _readDuration() {
    final minutes = int.tryParse(_minutes.text) ?? 0;
    final seconds = int.tryParse(_seconds.text) ?? 0;
    final total = minutes * 60 + seconds;
    return total > 0 ? total : null;
  }

  void _save() {
    setState(() => _error = null);
    final values = _read();
    if (values == null) {
      setState(() {});
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.entry.exerciseName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: _fields()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: OneRepColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: OneRepColors.gold),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<Widget> _fields() {
    switch (_metricType) {
      case 'bodyweightReps':
        return [
          Expanded(child: _numberField(_reps, 'Reps')),
          const SizedBox(width: 10),
          Expanded(
            child: _numberField(
              _weight,
              'Added Weight',
              suffix: 'kg',
              decimal: true,
            ),
          ),
        ];
      case 'timeOnly':
        return [
          Expanded(child: _numberField(_minutes, 'Minutes')),
          const SizedBox(width: 10),
          Expanded(child: _numberField(_seconds, 'Seconds')),
        ];
      case 'distanceTime':
        return [
          Expanded(
            child: _numberField(
              _distance,
              'Distance',
              suffix: 'm',
              decimal: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _numberField(_minutes, 'Min')),
          const SizedBox(width: 10),
          Expanded(child: _numberField(_seconds, 'Sec')),
        ];
      default: // weightReps
        return [
          Expanded(
            child: _numberField(_weight, 'Weight', suffix: 'kg', decimal: true),
          ),
          const SizedBox(width: 10),
          Expanded(child: _numberField(_reps, 'Reps')),
        ];
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(
        color: OneRepColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise reference card — last session's sets and the personal best
// ---------------------------------------------------------------------------

/// Shows what was lifted for [exercise] in the previous session alongside the
/// current personal best, so the numbers to beat are on screen while logging.
///
/// Each of last session's sets is tappable and prefills the logger via
/// [onSetTap].
class _ExerciseReferenceCard extends ConsumerWidget {
  final Exercise exercise;
  final int sessionId;
  final ValueChanged<WorkoutSet> onSetTap;

  const _ExerciseReferenceCard({
    required this.exercise,
    required this.sessionId,
    required this.onSetTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastAsync = ref.watch(
      watchLastPerformanceForExerciseProvider(exercise.id, sessionId),
    );
    final prAsync = ref.watch(watchBestPrForExerciseProvider(exercise.id));

    // Stay hidden until both streams have emitted — a card that pops in
    // half-populated is more distracting than one that arrives a frame later.
    if (!lastAsync.hasValue || !prAsync.hasValue) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OneRepColors.surfaceElevated),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _LastSessionColumn(
                  performance: lastAsync.value,
                  onSetTap: onSetTap,
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: OneRepColors.surfaceElevated,
              ),
              Expanded(flex: 2, child: _PersonalBestColumn(pb: prAsync.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSessionColumn extends StatelessWidget {
  final LastSessionPerformance? performance;
  final ValueChanged<WorkoutSet> onSetTap;

  const _LastSessionColumn({required this.performance, required this.onSetTap});

  @override
  Widget build(BuildContext context) {
    final performance = this.performance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _ColumnLabel(
              text: 'LAST TIME',
              color: OneRepColors.textSecondary,
            ),
            if (performance != null) ...[
              const SizedBox(width: 6),
              Text(
                formatShortDate(performance.date),
                style: const TextStyle(
                  color: OneRepColors.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (performance == null)
          const Text(
            'No previous sets logged.',
            style: TextStyle(color: OneRepColors.textDisabled, fontSize: 12),
          )
        else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final set in performance.sets)
                _PreviousSetChip(set: set, onTap: () => onSetTap(set)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a set to fill it in',
            style: TextStyle(color: OneRepColors.textDisabled, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

class _PreviousSetChip extends StatelessWidget {
  final WorkoutSet set;
  final VoidCallback onTap;

  const _PreviousSetChip({required this.set, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: OneRepColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          formatWorkoutSet(set),
          style: const TextStyle(
            color: OneRepColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PersonalBestColumn extends StatelessWidget {
  final PersonalBest? pb;

  const _PersonalBestColumn({required this.pb});

  @override
  Widget build(BuildContext context) {
    final pb = this.pb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ColumnLabel(text: 'PERSONAL BEST', color: OneRepColors.gold),
        const SizedBox(height: 6),
        if (pb == null)
          const Text(
            'Not set yet.',
            style: TextStyle(color: OneRepColors.textDisabled, fontSize: 12),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.emoji_events,
                  color: OneRepColors.gold,
                  size: 14,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  formatPersonalBest(pb),
                  style: const TextStyle(
                    color: OneRepColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatShortDate(pb.achievedAt),
            style: const TextStyle(
              color: OneRepColors.textDisabled,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _ColumnLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
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
                    '${pr.exerciseName}  ${pr.summary}',
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.close,
              color: OneRepColors.textSecondary,
              size: 16,
            ),
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
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 22),
                color: OneRepColors.textSecondary,
                tooltip: 'Skip rest',
                onPressed: onSkip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded, size: 20),
                color: OneRepColors.textSecondary,
                tooltip: 'Restart timer',
                onPressed: onRestart,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
              style: TextStyle(color: OneRepColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
