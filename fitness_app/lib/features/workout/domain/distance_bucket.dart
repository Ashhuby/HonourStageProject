/// Standard distances a `distanceTime` record is filed under.
///
/// A record only means something against a distance you would repeat, and a
/// raw distance never repeats exactly: 5000 m on Monday and 5200 m on Friday
/// is the same run twice, not two records. Keyed on the raw value, the second
/// run finds no existing record and is inserted unconditionally — so *every*
/// logged run was a personal best, the record table grew without bound, and
/// the `pr_10` badge fired after ten runs having beaten nothing.
///
/// Bucketing makes the existing v7 unique key
/// `{exerciseId, metricType, distanceMetres}` mean what it was always shaped
/// to mean. "Best 5 km" is a record; "best 5200 m" never was. It also bounds
/// the table at one row per bucket per exercise, forever.
library;

/// The distances a record can be filed under, ascending.
///
/// The union of the athletics, erg and pool distances rather than one list per
/// activity: an exercise can be re-filed by the user, and a per-activity list
/// would let a record's bucket shift underneath it when that happened.
///
/// Adjacent buckets are at most 2x apart, and that widest gap sits only at the
/// sprint end (100-200-400), where distances are run on a marked track and so
/// are logged exactly. Above 400 m nothing is wider than 1.67x, which bounds
/// the unfairness described on [distanceBucketFor] where it matters.
const List<double> kDistanceBuckets = [
  100,
  200,
  400,
  500,
  800,
  1000,
  1500,
  1609.34, // mile
  2000,
  3000,
  5000,
  8000,
  10000,
  15000,
  21097.5, // half marathon
  30000,
  42195, // marathon
];

/// The largest standard distance that [metres] covers, or null if it is
/// shorter than the smallest.
///
/// Rounds **down**, never to nearest: a record has to be earned, and 4.9 km is
/// not a 5 km. The cost is that a longer, slower effort inside one band does
/// not displace a shorter, faster one — a 5200 m run is timed as a 5 km even
/// though its true 5 km split was quicker. That bias is deliberate: it can
/// miss a genuine record, but it cannot invent one, and the alternative —
/// scaling the time down to the bucket — would make the record describe a set
/// that never happened.
double? distanceBucketFor(double metres) {
  double? bucket;
  for (final candidate in kDistanceBuckets) {
    // A hair of tolerance so a distance typed as exactly 5000 lands on 5000
    // rather than falling foul of floating-point comparison.
    if (metres + 1e-9 >= candidate) {
      bucket = candidate;
    } else {
      break;
    }
  }
  return bucket;
}

/// Names a bucket the way it is spoken — `5K`, `1 MILE`, `HALF`, `MARATHON`.
///
/// A record list reading "5K · 24:10" is worth more than "5000.0m in 24:10",
/// and the named distances are the whole reason those values are in the list.
String formatDistanceBucket(double metres) {
  if (metres == 42195) return 'MARATHON';
  if (metres == 21097.5) return 'HALF';
  if (metres == 1609.34) return '1 MILE';
  if (metres >= 1000 && metres % 1000 == 0) {
    return '${(metres / 1000).toStringAsFixed(0)}K';
  }
  return '${metres.toStringAsFixed(0)}M';
}
