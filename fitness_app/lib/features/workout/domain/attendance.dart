/// The twelve-week attendance grid, and what it adds up to.
///
/// The grid's geometry used to be worked out inside the widget that drew it —
/// which meant the week alignment, the window boundary and the day lookup had
/// no test between them and the screen. It is arithmetic over dates, which is
/// the part that goes wrong, so it lives here as pure functions instead.
library;

/// How many weeks the grid covers. Twelve rows of seven.
const int kAttendanceWeeks = 12;

/// One cell.
typedef AttendanceDay = ({
  DateTime date,
  int sessions,

  /// Marked so the grid can show where "now" is in it.
  bool isToday,

  /// Days later this week. They have not been missed — they have not happened
  /// — and drawing them as empty cells makes the current week look like a
  /// week of failures every Monday.
  bool isFuture,
});

/// What the grid says, read as numbers.
typedef AttendanceSummary = ({
  /// Sessions inside the window. Not the lifetime total — the point of the
  /// summary is to describe the twelve weeks on screen.
  int sessions,

  /// Distinct days with at least one session.
  int daysTrained,

  /// Weeks with at least one session, out of [kAttendanceWeeks].
  int weeksTrained,

  /// The most sessions in any one week of the window.
  int bestWeek,

  /// Sessions per week across the whole window, current partial week
  /// included. Dividing by the elapsed fraction of a week would make the
  /// figure jump every Monday and mean nothing on a Tuesday.
  double sessionsPerWeek,
});

/// Calendar-day arithmetic.
///
/// `add(Duration(days: 1))` adds twenty-four hours, which is not a day twice a
/// year: from midnight on the morning the clocks go back it lands at 23:00 the
/// same evening, and the grid silently repeats a day. Constructing the date
/// instead lets [DateTime] normalise the overflow properly.
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// The grid, as [kAttendanceWeeks] rows of seven days running Monday to
/// Sunday and ending with the Sunday of the week containing [now].
///
/// [attendance] is keyed by day; keys are normalised here rather than trusted,
/// because a key carrying a time of day would simply never match and the day
/// would read as unattended.
List<List<AttendanceDay>> attendanceGrid(
  Map<DateTime, int> attendance, {
  DateTime? now,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final counts = <DateTime, int>{};
  for (final entry in attendance.entries) {
    final day = _dayOf(entry.key);
    counts[day] = (counts[day] ?? 0) + entry.value;
  }

  final thisMonday = _addDays(today, -(today.weekday - DateTime.monday));
  final start = _addDays(thisMonday, -(kAttendanceWeeks - 1) * 7);

  return [
    for (var week = 0; week < kAttendanceWeeks; week++)
      [
        for (var offset = 0; offset < 7; offset++)
          () {
            final date = _addDays(start, week * 7 + offset);
            return (
              date: date,
              sessions: counts[date] ?? 0,
              isToday: date == today,
              isFuture: date.isAfter(today),
            );
          }(),
      ],
  ];
}

/// Reads a grid as numbers.
AttendanceSummary summariseAttendance(List<List<AttendanceDay>> grid) {
  var sessions = 0;
  var daysTrained = 0;
  var weeksTrained = 0;
  var bestWeek = 0;

  for (final week in grid) {
    var inWeek = 0;
    for (final day in week) {
      if (day.sessions <= 0) continue;
      sessions += day.sessions;
      daysTrained++;
      inWeek += day.sessions;
    }
    if (inWeek > 0) weeksTrained++;
    if (inWeek > bestWeek) bestWeek = inWeek;
  }

  return (
    sessions: sessions,
    daysTrained: daysTrained,
    weeksTrained: weeksTrained,
    bestWeek: bestWeek,
    sessionsPerWeek: grid.isEmpty ? 0 : sessions / grid.length,
  );
}
