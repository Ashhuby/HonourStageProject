import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/split_schedule.dart';

/// Tests the rotation that decides which day of a split is due.
///
/// A wrong answer here is not an error the user can see. It is the app
/// confidently offering the wrong workout, which is worse than offering none,
/// so the arithmetic is separated from the screen and pinned down here.
void main() {
  ScheduledRoutine routine(int id, String name, List<int> slots) =>
      (routineId: id, name: name, slots: slots);

  SplitSchedule weekly(List<ScheduledRoutine> routines) => SplitSchedule.of(
    mode: ScheduleMode.weekly,
    length: kWeekLength,
    routines: routines,
  );

  SplitSchedule cycle(int length, List<ScheduledRoutine> routines) =>
      SplitSchedule.of(
        mode: ScheduleMode.cycle,
        length: length,
        routines: routines,
      );

  // Monday 13 April 2026 through the following Sunday.
  DateTime day(int date) => DateTime(2026, 4, date, 9);

  group('parseSlots', () {
    test('reads a list', () {
      expect(parseSlots('0,3'), [0, 3]);
    });

    test('is total, because a bad cell must not take out the screen', () {
      expect(parseSlots(null), isEmpty);
      expect(parseSlots(''), isEmpty);
      expect(parseSlots('   '), isEmpty);
      expect(parseSlots('rest day'), isEmpty);
      expect(parseSlots('0,,x,2'), [0, 2]);
      expect(parseSlots('-1,2'), [2]);
    });

    test('sorts and de-duplicates, so order can never disagree', () {
      expect(parseSlots('5, 1 ,5,1'), [1, 5]);
    });

    test('drops slots the rotation is too short for', () {
      // Shortening a cycle must not leave a routine pinned to a day that no
      // longer exists.
      expect(parseSlots('0,9', length: 3), [0]);
    });
  });

  group('formatSlots', () {
    test('round-trips', () {
      expect(parseSlots(formatSlots([3, 0])), [0, 3]);
    });

    test('an unscheduled routine is null, not an empty string', () {
      // One representation of "nowhere", so a query for scheduled routines
      // cannot miss half of them.
      expect(formatSlots(const []), isNull);
      expect(formatSlots(const [-1]), isNull);
    });
  });

  group('a schedule with nothing in it', () {
    test('is not active, whatever mode it claims', () {
      expect(weekly(const []).isActive, isFalse);
      expect(weekly([routine(1, 'Push', const [])]).isActive, isFalse);
      expect(SplitSchedule.none.isActive, isFalse);
    });

    test('offers no routine rather than searching forever', () {
      final verdict = nextUp(weekly(const []), day(13));
      expect(verdict.routine, isNull);
    });
  });

  group('weekly', () {
    final ppl = weekly([
      routine(1, 'Push', const [0, 3]),
      routine(2, 'Pull', const [2]),
      routine(3, 'Legs', const [5]),
    ]);

    test('is always seven long, whatever length it was given', () {
      // A weekly rotation of any other length would put Thursday's session on
      // a Tuesday.
      final odd = SplitSchedule.of(
        mode: ScheduleMode.weekly,
        length: 3,
        routines: [
          routine(1, 'Push', const [0]),
        ],
      );
      expect(odd.length, kWeekLength);
    });

    test('slot 0 is Monday', () {
      expect(slotOn(ppl, day(13)), 0);
      expect(slotOn(ppl, day(15)), 2);
      expect(slotOn(ppl, day(19)), 6);
    });

    test('offers the routine sitting on today', () {
      final verdict = nextUp(ppl, day(15));

      expect(verdict.routine?.name, 'Pull');
      expect(verdict.daysAway, 0);
      expect(verdict.slot, 2);
    });

    test('looks forward past a rest day', () {
      // Tuesday is empty, so Tuesday points at Wednesday rather than at
      // nothing.
      final verdict = nextUp(ppl, day(14));

      expect(verdict.routine?.name, 'Pull');
      expect(verdict.daysAway, 1);
    });

    test('wraps round the end of the week', () {
      // Sunday looks forward into Monday.
      final verdict = nextUp(ppl, day(19));

      expect(verdict.routine?.name, 'Push');
      expect(verdict.daysAway, 1);
    });

    test('a missed day does not shift the week', () {
      // The whole point of a weekly split. Skipping Monday's Push does not
      // make Wednesday owe it — Wednesday is Pull because the schedule says
      // Wednesday is Pull.
      final verdict = nextUp(ppl, day(15));
      expect(verdict.routine?.name, 'Pull');
    });

    test('a routine can hold more than one day', () {
      // Six-day PPL trains Push twice a week, which is why a routine keeps a
      // list of slots rather than one.
      expect(ppl.at(0).single.name, 'Push');
      expect(ppl.at(3).single.name, 'Push');
    });

    test('skipping today moves on to the next training day', () {
      // Used once today's session is logged, so the card stops offering a
      // workout that is already done.
      final verdict = nextUp(ppl, day(15), skipToday: true);

      // Thursday is the split's second Push day, not Legs.
      expect(verdict.routine?.name, 'Push');
      expect(verdict.daysAway, 1);
    });
  });

  group('cycle', () {
    // Train, then two days off.
    final onOffOff = cycle(3, [
      routine(1, 'Full Body', const [0]),
    ]);

    test('starts on day one when nothing has been trained yet', () {
      // A new cycle must not open by telling the user to rest.
      final verdict = nextUp(onOffOff, day(13));

      expect(verdict.routine?.name, 'Full Body');
      expect(verdict.daysAway, 0);
    });

    test('turns from the day last trained', () {
      // Trained Monday on slot 0; Tuesday and Wednesday are rest, Thursday
      // comes round again.
      expect(
        slotOn(onOffOff, day(14), lastTrainedSlot: 0, lastTrainedOn: day(13)),
        1,
      );
      expect(
        slotOn(onOffOff, day(16), lastTrainedSlot: 0, lastTrainedOn: day(13)),
        0,
      );
    });

    test('rest days point at the next session and say how far off it is', () {
      final verdict = nextUp(
        onOffOff,
        day(14),
        lastTrainedSlot: 0,
        lastTrainedOn: day(13),
      );

      expect(verdict.routine?.name, 'Full Body');
      expect(verdict.daysAway, 2);
    });

    test('a long break does not leave the ring stranded', () {
      // Self-correction is the reason the anchor is the last session rather
      // than a start date: a month off simply lands wherever the maths puts
      // it, and the next session re-anchors it.
      final verdict = nextUp(
        onOffOff,
        DateTime(2026, 5, 20),
        lastTrainedSlot: 0,
        lastTrainedOn: day(13),
      );

      expect(verdict.routine, isNotNull);
      expect(verdict.daysAway, lessThan(onOffOff.length));
    });

    test('survives the clocks going forward', () {
      // 29 March 2026 is the spring change in Europe. Counted in local
      // twenty-four-hour blocks the gap reads a day short, which is a whole
      // slot on a three-day ring — the app would offer the wrong workout,
      // silently, twice a year.
      final before = DateTime(2026, 3, 28, 9);
      final after = DateTime(2026, 3, 31, 9);

      expect(
        slotOn(onOffOff, after, lastTrainedSlot: 0, lastTrainedOn: before),
        0,
      );
    });

    test('a longer rotation holds several training days', () {
      final upperLower = cycle(4, [
        routine(1, 'Upper', const [0]),
        routine(2, 'Lower', const [2]),
      ]);

      expect(
        nextUp(
          upperLower,
          day(14),
          lastTrainedSlot: 0,
          lastTrainedOn: day(13),
        ).routine?.name,
        'Lower',
      );
    });

    test('is clamped to something a person can hold in their head', () {
      expect(cycle(1, const []).length, 2);
      expect(cycle(99, const []).length, kMaxCycleLength);
    });

    test('shortening drops the routines that fell off the end', () {
      final shortened = cycle(3, [
        routine(1, 'Push', const [0, 9]),
      ]);
      expect(shortened.routines.single.slots, [0]);
    });
  });

  group('labels', () {
    test('a weekly slot is a weekday', () {
      expect(slotLabel(weekly(const []), 0), 'Mon');
      expect(slotLabel(weekly(const []), 6), 'Sun');
    });

    test('a cycle slot counts from one, as anyone would say it', () {
      expect(slotLabel(cycle(3, const []), 0), 'Day 1');
      expect(slotLabel(cycle(3, const []), 2), 'Day 3');
    });
  });

  group('ScheduleMode', () {
    test('reads its own names', () {
      for (final mode in ScheduleMode.values) {
        expect(ScheduleMode.byNameOrNone(mode.name), mode);
      }
    });

    test('anything else degrades to unscheduled', () {
      // A split written by a newer version of the app must not take the
      // splits list down with it.
      expect(ScheduleMode.byNameOrNone(null), ScheduleMode.none);
      expect(ScheduleMode.byNameOrNone('fortnightly'), ScheduleMode.none);
    });
  });
}
