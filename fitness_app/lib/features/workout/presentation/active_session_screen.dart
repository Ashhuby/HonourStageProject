import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
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
  // Tracks which exercise is currently selected for logging
  Exercise? _selectedExercise;

  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
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
            // Exercise selector
            _buildExerciseSelector(),
            const Divider(height: 1),
            // Set logger
            if (_selectedExercise != null) _buildSetLogger(),
            const Divider(height: 1),
            // Logged sets list
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

  Widget _buildExerciseSelector() {
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
    // Group sets by exercise name for cleaner display
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
                                fontWeight: FontWeight.w500),
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

    // Clear reps only — weight likely stays the same for next set
    _repsController.clear();
  }

  void _confirmEndSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text(
          'This will end your session. You cannot add sets after finishing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(sessionRepositoryProvider.notifier)
                  .endSession(widget.sessionId);
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // exit session screen
              }
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}