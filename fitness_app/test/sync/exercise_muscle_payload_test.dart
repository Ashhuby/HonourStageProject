import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/sync/exercise_muscle_payload.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests the wire format for a custom exercise's muscles.
///
/// The Supabase calls in `SyncService` are not testable here (no network, and
/// the client is not injectable), so the mapping to and from the remote row is
/// pulled out as pure functions and tested directly. That mapping is where the
/// compatibility rules live: a client predating the taxonomy writes neither
/// muscle column, and must still round-trip.
void main() {
  group('muscleColumnsFor', () {
    test('encodes the primary by name and the secondaries as a list', () {
      final columns = muscleColumnsFor(
        primary: Muscle.lats,
        secondary: [Muscle.biceps, Muscle.forearms],
      );
      expect(columns['primary_muscle'], 'lats');
      expect(columns['secondary_muscles'], 'biceps,forearms');
    });

    test('no secondaries encodes as an empty string, not null', () {
      // The column is NOT NULL with a '' default remotely.
      final columns = muscleColumnsFor(primary: Muscle.calves, secondary: []);
      expect(columns['secondary_muscles'], '');
    });

    test('a missing primary encodes as null rather than a placeholder', () {
      final columns = muscleColumnsFor(primary: null, secondary: []);
      expect(columns['primary_muscle'], isNull);
    });
  });

  group('musclesFromRemoteRow', () {
    test('round-trips what muscleColumnsFor wrote', () {
      final columns = muscleColumnsFor(
        primary: Muscle.quads,
        secondary: [Muscle.glutes, Muscle.hamstrings],
      );
      final decoded = musclesFromRemoteRow({...columns, 'body_part': 'Legs'});
      expect(decoded.primary, Muscle.quads);
      expect(decoded.secondary, [Muscle.hamstrings, Muscle.glutes]);
    });

    test('a row from a client predating the taxonomy uses body_part', () {
      final decoded = musclesFromRemoteRow({'body_part': 'Biceps'});
      expect(decoded.primary, Muscle.biceps);
      expect(decoded.secondary, isEmpty);
    });

    test('an empty secondary string yields no muscles, not one blank', () {
      final decoded = musclesFromRemoteRow({
        'primary_muscle': 'chest',
        'secondary_muscles': '',
        'body_part': 'Chest',
      });
      expect(decoded.secondary, isEmpty);
    });

    test('an unrecognised muscle name is skipped, not thrown on', () {
      // Forward compatibility: a newer client may know muscles this one does
      // not. Dropping them beats refusing the whole download.
      final decoded = musclesFromRemoteRow({
        'primary_muscle': 'chest',
        'secondary_muscles': 'triceps,serratus,frontDelts',
        'body_part': 'Chest',
      });
      expect(decoded.secondary, [Muscle.frontDelts, Muscle.triceps]);
    });

    test('an unrecognised primary falls back to the body_part', () {
      final decoded = musclesFromRemoteRow({
        'primary_muscle': 'serratus',
        'body_part': 'Core',
      });
      expect(decoded.primary, Muscle.abs);
    });

    test('a secondary repeating the primary is dropped', () {
      final decoded = musclesFromRemoteRow({
        'primary_muscle': 'chest',
        'secondary_muscles': 'chest,triceps',
        'body_part': 'Chest',
      });
      expect(decoded.secondary, [Muscle.triceps]);
    });

    test('a duplicated secondary is stored once', () {
      final decoded = musclesFromRemoteRow({
        'primary_muscle': 'lats',
        'secondary_muscles': 'biceps,biceps',
        'body_part': 'Back',
      });
      expect(decoded.secondary, [Muscle.biceps]);
    });
  });

  group('bodyPartFromRemoteRow', () {
    test('reads the column when present', () {
      expect(bodyPartFromRemoteRow({'body_part': 'Legs'}), 'Legs');
    });

    test('a null body_part falls back rather than throwing', () {
      // This used to be an unconditional cast, so one bad row took down the
      // whole download instead of one exercise.
      expect(bodyPartFromRemoteRow({'body_part': null}), 'Unassigned');
      expect(bodyPartFromRemoteRow({}), 'Unassigned');
    });

    test('a row naming no muscle is left unassigned, not guessed at', () {
      // The primary is nullable now. It used to fall back to a fake muscle
      // called Full Body, which was a claim about anatomy the app could not
      // support and which nothing would ever revisit.
      final decoded = musclesFromRemoteRow({});
      expect(decoded.primary, isNull);
      expect(decoded.secondary, isEmpty);
    });
  });
}
