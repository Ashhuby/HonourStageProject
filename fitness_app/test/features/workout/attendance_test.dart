import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/attendance.dart';

/// Tests the twelve-week attendance grid.
///
/// The geometry used to live inside the widget that drew it, where none of it
/// could be checked: the Monday alignment, the window boundary, the day
/// lookup and the day arithmetic. All of it is date maths, and date maths is
/// where the mistakes are — a day that lands in the wrong cell looks exactly
/// like a day the user did not train.
void main() {
  /// A Wednesday, so the current week is genuinely partial and the alignment
  /// has something to get wrong.
  final wednesday = DateTime(2026, 4, 15, 14, 30);

  Map<DateTime, int> on(List<(DateTime, int)> entries) => {
    for (final entry in entries) entry.$1: entry.$2,
  };

  group('the grid', () {
    test('is twelve rows of seven days', () {
      final grid = attendanceGrid(const {}, now: wednesday);

      expect(grid, hasLength(kAttendanceWeeks));
      for (final week in grid) {
        expect(week, hasLength(7));
      }
    });

    test('runs Monday to Sunday', () {
      final grid = attendanceGrid(const {}, now: wednesday);

      for (final week in grid) {
        expect(week.first.date.weekday, DateTime.monday);
        expect(week.last.date.weekday, DateTime.sunday);
      }
    });

    test('ends on the Sunday of the week containing today', () {
      final grid = attendanceGrid(const {}, now: wednesday);
      final last = grid.last.last.date;

      // Wednesday 15 April 2026 sits in the week ending Sunday the 19th.
      expect(last, DateTime(2026, 4, 19));
      expect(grid.last.first.date, DateTime(2026, 4, 13));
    });

    test('covers exactly the twelve weeks up to that Sunday', () {
      final grid = attendanceGrid(const {}, now: wednesday);
      final days = [for (final week in grid) ...week];

      expect(days, hasLength(kAttendanceWeeks * 7));
      expect(days.first.date, DateTime(2026, 1, 26));

      // Consecutive, with nothing repeated or skipped — which is what breaks
      // when days are added as twenty-four-hour durations.
      //
      // Compared as calendar dates rather than as a Duration, because a
      // Duration is the very thing under test: across the spring transition
      // one midnight to the next is twenty-three hours, so `inDays` reads
      // zero for a pair of days that are perfectly consecutive.
      for (var i = 1; i < days.length; i++) {
        final previous = days[i - 1].date;
        expect(
          days[i].date,
          DateTime(previous.year, previous.month, previous.day + 1),
          reason: '$previous is not followed by ${days[i].date}',
        );
      }
    });

    test('survives a daylight-saving boundary', () {
      // In Europe the clocks go back at the end of October. Adding twenty-four
      // hours to midnight that morning lands at 23:00 the same evening, and
      // the grid quietly repeats a day.
      final grid = attendanceGrid(const {}, now: DateTime(2026, 11, 4));
      final days = [for (final week in grid) ...week];

      expect(days.map((d) => d.date).toSet(), hasLength(days.length));
      for (final day in days) {
        expect(day.date.hour, 0, reason: '${day.date} is not a whole day');
      }
    });

    test('places a session on its own day', () {
      final grid = attendanceGrid(
        on([(DateTime(2026, 4, 13), 2)]),
        now: wednesday,
      );

      expect(grid.last.first.sessions, 2);
      expect(grid.last[1].sessions, 0);
    });

    test('a key carrying a time of day still lands', () {
      // The provider normalises its keys, but a key with an hour on it would
      // simply never match and the day would read as unattended.
      final grid = attendanceGrid(
        on([(DateTime(2026, 4, 14, 19, 45), 1)]),
        now: wednesday,
      );

      expect(grid.last[1].sessions, 1);
    });

    test('sessions outside the window are ignored rather than clamped', () {
      final grid = attendanceGrid(
        on([(DateTime(2025, 12, 1), 9), (DateTime(2026, 5, 1), 9)]),
        now: wednesday,
      );

      final total = [
        for (final week in grid)
          for (final day in week) day.sessions,
      ].fold<int>(0, (a, b) => a + b);
      expect(total, 0);
    });

    test('marks today, and marks the rest of the week as still to come', () {
      final grid = attendanceGrid(const {}, now: wednesday);
      final thisWeek = grid.last;

      expect(thisWeek.map((d) => d.isToday).toList(), [
        false,
        false,
        true,
        false,
        false,
        false,
        false,
      ]);
      // Thursday onwards has not been missed — it has not happened.
      expect(thisWeek.map((d) => d.isFuture).toList(), [
        false,
        false,
        false,
        true,
        true,
        true,
        true,
      ]);
    });

    test('no earlier day is ever in the future', () {
      final grid = attendanceGrid(const {}, now: wednesday);

      for (final week in grid.take(kAttendanceWeeks - 1)) {
        expect(week.every((d) => !d.isFuture), isTrue);
        expect(week.every((d) => !d.isToday), isTrue);
      }
    });
  });

  group('the summary', () {
    test('an empty grid reads as zero, not as nothing', () {
      final summary = summariseAttendance(
        attendanceGrid(const {}, now: wednesday),
      );

      expect(summary.sessions, 0);
      expect(summary.daysTrained, 0);
      expect(summary.weeksTrained, 0);
      expect(summary.bestWeek, 0);
      expect(summary.sessionsPerWeek, 0);
    });

    test('counts sessions and the days they fall on separately', () {
      // Two sessions in one day is one day trained. The distinction is the
      // reason both figures are shown.
      final summary = summariseAttendance(
        attendanceGrid(
          on([(DateTime(2026, 4, 13), 2), (DateTime(2026, 4, 15), 1)]),
          now: wednesday,
        ),
      );

      expect(summary.sessions, 3);
      expect(summary.daysTrained, 2);
    });

    test('counts the weeks that saw any training', () {
      final summary = summariseAttendance(
        attendanceGrid(
          on([(DateTime(2026, 4, 13), 1), (DateTime(2026, 4, 6), 1)]),
          now: wednesday,
        ),
      );

      expect(summary.weeksTrained, 2);
    });

    test('the best week is the busiest, not the most recent', () {
      final summary = summariseAttendance(
        attendanceGrid(
          on([
            (DateTime(2026, 4, 6), 3),
            (DateTime(2026, 4, 8), 2),
            (DateTime(2026, 4, 13), 1),
          ]),
          now: wednesday,
        ),
      );

      expect(summary.bestWeek, 5);
    });

    test('the average is over the whole window, partial week included', () {
      // Dividing by the elapsed fraction of a week would make the figure jump
      // every Monday and mean nothing on a Tuesday.
      final summary = summariseAttendance(
        attendanceGrid(on([(DateTime(2026, 4, 13), 12)]), now: wednesday),
      );

      expect(summary.sessionsPerWeek, closeTo(1, 0.0001));
    });
  });
}
