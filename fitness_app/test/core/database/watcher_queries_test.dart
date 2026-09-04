import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the change-watcher queries against sharing a query string.
///
/// Several providers watch for "any write to these tables" by running a
/// trivial query purely for its `readsFrom` set. Drift caches query streams on
/// the SQL text and its variables, so two watchers with the same query string
/// are handed **one** stream — carrying whichever `readsFrom` registered
/// first. The other's tables are then never announced.
///
/// Four of them used `SELECT 1 AS v`. They collapsed into a single stream that
/// woke only for the winner's tables, and the schedule editor — whose writes
/// go to `workout_routines`, which was not on that list — refreshed roughly
/// every thirty seconds, whenever the background sync happened to touch a
/// table that was.
///
/// Nothing about that is visible in review, at runtime, or in any test that
/// exercises one provider at a time. It only appears when two of them are
/// alive together, which is why it is checked here, over the source.
void main() {
  test('every table watcher has a query string of its own', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run this from fitness_app/');

    // customSelect('<sql>', ... readsFrom: — the SQL is the cache key, so it
    // is what has to be unique.
    final call = RegExp(
      r'''customSelect\(\s*(?://[^\n]*\n\s*)*(?:"([^"]*)"|'([^']*)')\s*,\s*(?://[^\n]*\n\s*)*readsFrom''',
      multiLine: true,
    );

    final seen = <String, List<String>>{};

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;

      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final sql = match.group(1) ?? match.group(2)!;
        seen.putIfAbsent(sql, () => []).add(entity.path);
      }
    }

    expect(
      seen,
      isNotEmpty,
      reason:
          'found no watcher queries at all — the pattern this guards has '
          'moved, and the guard has to move with it',
    );

    final shared = {
      for (final entry in seen.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };

    expect(
      shared,
      isEmpty,
      reason:
          'these watcher queries share a query string, so drift will hand '
          'them one stream and one readsFrom — give each its own literal:\n'
          '${shared.entries.map((e) => '  "${e.key}" in ${e.value}').join('\n')}',
    );
  });
}
