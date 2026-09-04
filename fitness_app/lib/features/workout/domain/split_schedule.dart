/// When each day of a split comes round, and which one is due now.
///
/// A weekly split and a "train one, rest two" cycle look like different ideas
/// but are the same one at different lengths: an ordered ring of slots, each
/// either a training day or rest. Weekly is a ring of seven pinned to the
/// calendar week; a cycle is a ring of any length that turns from whenever you
/// last trained. Modelling them separately would have meant two schedule
/// editors, two resolvers and two sets of edge cases.
///
/// Pure over plain values — no database, no Flutter — because this is date
/// arithmetic against user history, which is where the mistakes are and where
/// a mistake is invisible: a wrong answer here is not an error, it is the app
/// confidently offering the wrong workout.
library;

/// How a split repeats.
enum ScheduleMode {
  /// No rotation. The split is a list of routines and nothing more, which is
  /// what every split was before scheduling existed.
  none('None'),

  /// Seven slots pinned to the calendar week, slot 0 being Monday.
  weekly('Weekly'),

  /// A ring of [SplitSchedule.length] slots that turns from the last session
  /// trained, rather than from any fixed date.
  cycle('Cycle');

  const ScheduleMode(this.label);

  final String label;

  /// Reads a stored value, treating anything unrecognised as unscheduled.
  ///
  /// Total on purpose: a split synced from a newer version of the app must
  /// degrade to "no schedule", not take the splits list down with it.
  static ScheduleMode byNameOrNone(String? name) {
    for (final mode in ScheduleMode.values) {
      if (mode.name == name) return mode;
    }
    return ScheduleMode.none;
  }
}

/// The longest ring worth offering. Beyond a fortnight a rotation stops being
/// something anyone holds in their head.
const int kMaxCycleLength = 14;

/// Slots in a week, and the length [ScheduleMode.weekly] is fixed at.
const int kWeekLength = 7;

/// Reads the stored slot list for a routine.
///
/// Total: blanks, spaces, non-numbers and out-of-range positions are dropped
/// rather than thrown, because the alternative is a corrupt cell taking out
/// the schedule screen. Duplicates are collapsed and the result is sorted, so
/// two routines can never disagree about the order they were written in.
List<int> parseSlots(String? stored, {int? length}) {
  if (stored == null || stored.trim().isEmpty) return const [];

  final slots = <int>{};
  for (final part in stored.split(',')) {
    final slot = int.tryParse(part.trim());
    if (slot == null || slot < 0) continue;
    if (length != null && slot >= length) continue;
    slots.add(slot);
  }

  return slots.toList()..sort();
}

/// Writes a slot list back, or null when the routine occupies none.
///
/// Null rather than an empty string so "unscheduled" has one representation in
/// the column instead of two.
String? formatSlots(Iterable<int> slots) {
  final unique = slots.where((s) => s >= 0).toSet().toList()..sort();
  return unique.isEmpty ? null : unique.join(',');
}

/// One routine's place in a schedule.
typedef ScheduledRoutine = ({int routineId, String name, List<int> slots});

/// A split's rotation, resolved.
class SplitSchedule {
  const SplitSchedule({
    required this.mode,
    required this.length,
    required this.routines,
  });

  /// An unscheduled split.
  static const SplitSchedule none = SplitSchedule(
    mode: ScheduleMode.none,
    length: kWeekLength,
    routines: [],
  );

  final ScheduleMode mode;

  /// How many slots the ring has. Always [kWeekLength] for a weekly split,
  /// whatever the split row happens to say — a weekly rotation that was not
  /// seven long would put Thursday's session on a Tuesday.
  final int length;

  final List<ScheduledRoutine> routines;

  /// Builds a schedule, clamping the length to something usable.
  factory SplitSchedule.of({
    required ScheduleMode mode,
    required int length,
    required List<ScheduledRoutine> routines,
  }) {
    final resolved = mode == ScheduleMode.weekly
        ? kWeekLength
        : length.clamp(2, kMaxCycleLength);

    return SplitSchedule(
      mode: mode,
      length: resolved,
      routines: [
        for (final routine in routines)
          (
            routineId: routine.routineId,
            name: routine.name,
            slots: routine.slots.where((s) => s < resolved).toList(),
          ),
      ],
    );
  }

  /// Whether anything is actually scheduled. A mode of weekly with every slot
  /// empty is a schedule in name only, and the UI should treat it as none.
  bool get isActive =>
      mode != ScheduleMode.none && routines.any((r) => r.slots.isNotEmpty);

  /// The routines sitting in [slot], in the order the split lists them.
  List<ScheduledRoutine> at(int slot) => [
    for (final routine in routines)
      if (routine.slots.contains(slot)) routine,
  ];
}

/// What the split says to train, and when.
typedef ScheduleVerdict = ({
  /// The routine due, or null when nothing is scheduled at all.
  ScheduledRoutine? routine,

  /// Which slot it sits in.
  int slot,

  /// How many days away it is. Zero is today.
  int daysAway,
});

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Calendar days between two dates.
///
/// Measured in UTC, which has no daylight saving. A local `difference().inDays`
/// counts twenty-four-hour blocks, so across the spring clock change it reads a
/// day short — enough to put a three-day cycle a whole slot out and offer the
/// wrong workout, silently and only twice a year.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Which slot of [schedule] the day [on] falls in.
///
/// Weekly follows the calendar: Monday is slot 0 and stays slot 0 whether or
/// not last Monday's session happened. A cycle turns from [lastTrainedSlot] on
/// [lastTrainedOn] — the last session actually logged against this split —
/// which is what makes it self-correcting: train late, or miss a turn, and the
/// ring picks up from what you did rather than from a date that has to be
/// maintained.
int slotOn(
  SplitSchedule schedule,
  DateTime on, {
  int? lastTrainedSlot,
  DateTime? lastTrainedOn,
}) {
  if (schedule.mode == ScheduleMode.weekly) {
    return (_dayOf(on).weekday - DateTime.monday) % kWeekLength;
  }

  // Never trained: the ring starts today, so the user is not told to rest
  // before they have begun.
  if (lastTrainedSlot == null || lastTrainedOn == null) return 0;

  final elapsed = _daysBetween(lastTrainedOn, on);
  return (lastTrainedSlot + elapsed) % schedule.length;
}

/// The next training day at or after [from], and how far off it is.
///
/// Returns a verdict with a null routine when the schedule has no training day
/// in it at all, rather than looping forever looking for one.
ScheduleVerdict nextUp(
  SplitSchedule schedule,
  DateTime from, {
  int? lastTrainedSlot,
  DateTime? lastTrainedOn,

  /// Skips today even if it is a training day. Set once today's session has
  /// been done, so the card moves on to tomorrow instead of offering a
  /// workout that is already logged.
  bool skipToday = false,
}) {
  final start = slotOn(
    schedule,
    from,
    lastTrainedSlot: lastTrainedSlot,
    lastTrainedOn: lastTrainedOn,
  );

  if (!schedule.isActive) return (routine: null, slot: start, daysAway: 0);

  for (var ahead = skipToday ? 1 : 0; ahead <= schedule.length; ahead++) {
    final slot = (start + ahead) % schedule.length;
    final here = schedule.at(slot);
    if (here.isEmpty) continue;
    return (routine: here.first, slot: slot, daysAway: ahead);
  }

  return (routine: null, slot: start, daysAway: 0);
}

/// The weekday name for a weekly slot, as an abbreviation.
const List<String> kSlotWeekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// What to call a slot in the UI.
///
/// A weekly slot is a weekday; a cycle slot is a day number, counted from one
/// because "day 0 of your cycle" is not how anyone describes a rotation.
String slotLabel(SplitSchedule schedule, int slot) =>
    schedule.mode == ScheduleMode.weekly
    ? kSlotWeekdays[slot % kWeekLength]
    : 'Day ${slot + 1}';
