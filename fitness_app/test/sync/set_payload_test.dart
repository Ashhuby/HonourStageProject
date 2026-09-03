import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/sync/set_payload.dart';

/// Tests the wire format for what a set and a record actually measured.
///
/// None of these fields crossed the wire before. A logged run uploaded its
/// weight (0) and reps (0) and dropped its distance and duration, so a
/// reinstall brought back every run and every plank as an empty set. The
/// Supabase calls are untestable here, so the mapping is pulled out as pure
/// functions — which is where the compatibility rules live anyway.
void main() {
  group('workout sets', () {
    test('a cardio set carries its distance and duration', () {
      final columns = setMetricColumns(
        durationSeconds: 1500,
        distanceMetres: 5000,
      );
      expect(columns['duration_seconds'], 1500);
      expect(columns['distance_metres'], 5000);
    });

    test('a lift carries nulls rather than zeroes', () {
      // Null is "not measured"; 0 would be "measured as nothing", and the
      // set logger uses 0 as its sentinel for weight and reps already.
      final columns = setMetricColumns();
      expect(columns['duration_seconds'], isNull);
      expect(columns['distance_metres'], isNull);
    });

    test('round-trips', () {
      final decoded = setMetricsFromRemoteRow(
        setMetricColumns(durationSeconds: 90, distanceMetres: 400),
      );
      expect(decoded.durationSeconds, 90);
      expect(decoded.distanceMetres, 400.0);
    });

    test('a row from a client predating the columns decodes to nulls', () {
      final decoded = setMetricsFromRemoteRow({'weight': 80.0, 'reps': 5});
      expect(decoded.durationSeconds, isNull);
      expect(decoded.distanceMetres, isNull);
    });

    test('an integer distance from the wire becomes a double', () {
      // Postgres hands back whichever numeric type it feels like; the old
      // code's `as num` cast was right, `as double` would have thrown.
      final decoded = setMetricsFromRemoteRow({'distance_metres': 5000});
      expect(decoded.distanceMetres, 5000.0);
    });
  });

  group('personal bests', () {
    test('the metric type travels with the record', () {
      // Without it every downloaded record landed on ('weightReps', 0.0) and
      // a user's whole set of distance records collapsed onto one row.
      final columns = personalBestMetricColumns(
        metricType: 'distanceTime',
        durationSeconds: 1450,
        distanceMetres: 5000,
      );
      expect(columns['metric_type'], 'distanceTime');
      expect(columns['duration_seconds'], 1450);
      expect(columns['distance_metres'], 5000);
    });

    test('round-trips', () {
      final decoded = personalBestMetricsFromRemoteRow(
        personalBestMetricColumns(
          metricType: 'timeOnly',
          durationSeconds: 240,
          distanceMetres: 0,
        ),
      );
      expect(decoded.metricType, 'timeOnly');
      expect(decoded.durationSeconds, 240);
      expect(decoded.distanceMetres, 0.0);
    });

    test('a row from an older client decodes to the key it meant', () {
      // An old client only ever wrote weight-and-reps records, so absent
      // columns mean exactly ('weightReps', 0.0) — which is the local key
      // that row already occupies.
      final decoded = personalBestMetricsFromRemoteRow({
        'reps': 5,
        'weight': 100.0,
      });
      expect(decoded.metricType, 'weightReps');
      expect(decoded.distanceMetres, 0.0);
      expect(decoded.durationSeconds, isNull);
    });

    test('an explicit null metric type still decodes', () {
      expect(
        personalBestMetricsFromRemoteRow({'metric_type': null}).metricType,
        'weightReps',
      );
    });
  });

  group('defensive column reads', () {
    test('a missing weight or reps does not throw', () {
      // These were unguarded casts, so one malformed row took down the whole
      // download rather than costing a single set.
      expect(weightFromRemoteRow({}), 0.0);
      expect(repsFromRemoteRow({}), 0);
      expect(weightFromRemoteRow({'weight': null}), 0.0);
      expect(repsFromRemoteRow({'reps': null}), 0);
    });

    test('an integer weight from the wire becomes a double', () {
      expect(weightFromRemoteRow({'weight': 80}), 80.0);
    });
  });
}
