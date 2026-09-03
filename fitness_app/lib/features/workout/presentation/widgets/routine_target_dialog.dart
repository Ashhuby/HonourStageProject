import 'package:flutter/material.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/theme/app_colors.dart';

/// What a routine plans for one exercise.
typedef RoutineTarget = ({
  int sets,
  int reps,
  double? distanceMetres,
  int? durationSeconds,
});

/// Asks for the routine's target, in the units the exercise is measured in.
///
/// A run planned as "3 sets of 10 reps" was the only thing a routine could
/// say, so the fields follow `metricType`: distance for a run, minutes and
/// seconds for a hold, reps for a lift.
///
/// Returns null if dismissed.
Future<RoutineTarget?> showRoutineTargetDialog(
  BuildContext context,
  Exercise exercise, {
  RoutineTarget? initial,
}) {
  final setsController = TextEditingController(text: '${initial?.sets ?? 3}');
  final repsController = TextEditingController(text: '${initial?.reps ?? 10}');
  final distanceController = TextEditingController(
    text: initial?.distanceMetres == null
        ? ''
        : '${initial!.distanceMetres!.round()}',
  );
  final minutesController = TextEditingController(
    text: initial?.durationSeconds == null
        ? ''
        : '${initial!.durationSeconds! ~/ 60}',
  );
  final secondsController = TextEditingController(
    text: initial?.durationSeconds == null
        ? ''
        : '${initial!.durationSeconds! % 60}',
  );

  return showDialog<RoutineTarget>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(exercise.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sets'),
            ),
            const SizedBox(height: 16),
            ..._targetFields(
              exercise.metricType,
              repsController: repsController,
              distanceController: distanceController,
              minutesController: minutesController,
              secondsController: secondsController,
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave a target blank to plan the set count only.',
              style: TextStyle(color: OneRepColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final minutes = int.tryParse(minutesController.text) ?? 0;
            final seconds = int.tryParse(secondsController.text) ?? 0;
            final duration = minutes * 60 + seconds;

            Navigator.pop(context, (
              sets: int.tryParse(setsController.text) ?? 3,
              reps: int.tryParse(repsController.text) ?? 10,
              distanceMetres: exercise.metricType == 'distanceTime'
                  ? double.tryParse(distanceController.text)
                  : null,
              durationSeconds: exercise.metricType == 'timeOnly' && duration > 0
                  ? duration
                  : null,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

List<Widget> _targetFields(
  String metricType, {
  required TextEditingController repsController,
  required TextEditingController distanceController,
  required TextEditingController minutesController,
  required TextEditingController secondsController,
}) {
  switch (metricType) {
    case 'distanceTime':
      return [
        TextField(
          controller: distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Target distance',
            suffixText: 'm',
          ),
        ),
      ];
    case 'timeOnly':
      return [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: secondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seconds'),
              ),
            ),
          ],
        ),
      ];
    default:
      return [
        TextField(
          controller: repsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target reps'),
        ),
      ];
  }
}
