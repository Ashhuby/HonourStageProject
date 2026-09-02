/// Rest countdown arithmetic.
///
/// The countdown is derived from the instant rest ends rather than counted
/// down in memory, so a locked screen, a paused isolate or a backgrounded app
/// cannot make it drift — on return it is simply recomputed.
library;

/// Whole seconds left until [endsAt], measured from [now].
///
/// Rounds up so a rest with any time left reads at least `1`, and never
/// returns a negative value — `0` means rest is over.
int restSecondsRemaining(DateTime endsAt, DateTime now) {
  final millis = endsAt.difference(now).inMilliseconds;
  if (millis <= 0) return 0;
  return (millis / Duration.millisecondsPerSecond).ceil();
}
