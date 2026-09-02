import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/utils/rest_timer.dart';

/// Tests the rest countdown arithmetic.
///
/// The countdown is derived from the instant rest ends rather than decremented
/// in memory, so that a backgrounded app — where Dart timers stop firing —
/// resumes showing the real time left instead of a countdown frozen mid-set.
void main() {
  final now = DateTime(2026, 1, 15, 10, 30);

  test('counts down from the end instant', () {
    expect(restSecondsRemaining(now.add(const Duration(seconds: 90)), now), 90);
    expect(restSecondsRemaining(now.add(const Duration(seconds: 1)), now), 1);
  });

  test('rounds part seconds up so rest never reads zero early', () {
    expect(
      restSecondsRemaining(now.add(const Duration(milliseconds: 1)), now),
      1,
    );
    expect(
      restSecondsRemaining(now.add(const Duration(milliseconds: 1500)), now),
      2,
    );
  });

  test('is zero once the end instant has passed', () {
    expect(restSecondsRemaining(now, now), 0);
    expect(
      restSecondsRemaining(now.subtract(const Duration(seconds: 1)), now),
      0,
    );
  });

  test('never returns a negative value after a long absence', () {
    // The case that mattered: the phone was locked through the whole rest.
    final endsAt = now.add(const Duration(seconds: 90));
    final resumed = now.add(const Duration(minutes: 20));

    expect(restSecondsRemaining(endsAt, resumed), 0);
  });

  test('reports the true remainder after a short absence', () {
    final endsAt = now.add(const Duration(seconds: 180));
    final resumed = now.add(const Duration(seconds: 100));

    expect(restSecondsRemaining(endsAt, resumed), 80);
  });
}
