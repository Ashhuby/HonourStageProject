/// The muscle half of a custom exercise's remote row.
///
/// Kept as pure functions rather than inline in [SyncService] because the
/// Supabase calls themselves are not testable here, but the mapping to and
/// from the wire is where the bugs live — and this part needs no network.
///
/// The representation is two additive, nullable columns on the remote
/// `exercises` table:
///
/// ```sql
/// alter table public.exercises
///   add column if not exists primary_muscle    text,
///   add column if not exists secondary_muscles text not null default '';
/// ```
///
/// Additive, so a client that predates the taxonomy keeps working: it writes
/// neither column and reads neither, and `body_part` — which it does write —
/// is still enough to reconstruct a primary muscle. Do not add a CHECK
/// constraint on `primary_muscle` until every client has upgraded; an older
/// one writes NULL and would be rejected.
library;

import '../../features/workout/domain/muscle.dart';

/// Encodes an exercise's muscles for the remote row.
Map<String, dynamic> muscleColumnsFor({
  required Muscle? primary,
  required List<Muscle> secondary,
}) {
  return {
    'primary_muscle': primary?.name,
    'secondary_muscles': secondary.map((m) => m.name).join(','),
  };
}

/// Reads an exercise's muscles back from a remote row.
///
/// Falls back to [muscleForBodyPartOrNull] when `primary_muscle` is absent —
/// the row was written by a client that predates the taxonomy.
///
/// The primary is nullable: a row naming no muscle we recognise is left
/// unassigned rather than being given a fabricated one.
///
/// Unrecognised names are skipped rather than thrown on, which is what lets a
/// newer client add a muscle to the vocabulary without breaking an older one.
({Muscle? primary, List<Muscle> secondary}) musclesFromRemoteRow(
  Map<String, dynamic> row,
) {
  final primary =
      Muscle.byNameOrNull(row['primary_muscle'] as String?) ??
      muscleForBodyPartOrNull(bodyPartFromRemoteRow(row));

  final raw = (row['secondary_muscles'] as String?) ?? '';
  final secondary = <Muscle>[];
  for (final name in raw.split(',')) {
    if (name.isEmpty) continue;
    final muscle = Muscle.byNameOrNull(name);
    if (muscle == null || muscle == primary) continue;
    if (!secondary.contains(muscle)) secondary.add(muscle);
  }
  secondary.sort((a, b) => a.index.compareTo(b.index));

  return (primary: primary, secondary: secondary);
}

/// Reads `body_part` defensively.
///
/// The column is NOT NULL remotely, but the download used to cast it
/// unconditionally, so a row that somehow carried NULL crashed the whole sync
/// rather than one exercise. Falling back keeps the rest of the download
/// running.
String bodyPartFromRemoteRow(Map<String, dynamic> row) =>
    (row['body_part'] as String?) ?? kUnassignedBodyPart;
