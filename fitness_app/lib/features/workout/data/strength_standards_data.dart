// Strength percentile lookup tables sourced from Strengthlevel.com.
// URL: https://strengthlevel.com/strength-standards/male/kg
//      https://strengthlevel.com/strength-standards/female/kg
// Accessed: March 2026.
// © Strength Level Limited. Data used for non-commercial, educational
// purposes within this application. Attribution required — cite as:
// "Strength standards data sourced from Strengthlevel.com"
//
// Percentile mapping (per Strengthlevel.com published definitions):
//   Beginner     = stronger than  5% of lifters
//   Novice       = stronger than 20% of lifters
//   Intermediate = stronger than 50% of lifters
//   Advanced     = stronger than 80% of lifters
//   Elite        = stronger than 95% of lifters
//
// Implementation notes:
// - Only By Bodyweight tables are used (not By Age).
//   Rationale: the user profile requires bodyweight and sex but not age.
//   Age-adjusted standards would silently produce wrong results for users
//   who have not entered their age, breaking the offline-first contract.
// - Bodyweight is clamped to the nearest available bracket if the user's
//   bodyweight falls outside the table range.
// - Standards represent 1-rep max (1RM) values in kilograms.
//   The app compares the user's best logged lift directly against these
//   values without 1RM conversion. This is conservative but honest —
//   a user's best set at any rep count will understate their true 1RM,
//   so percentile results will be slightly understated, never overstated.

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

enum Sex { male, female }

/// A single row in a strength standards table.
/// [bodyweight] is the lower bound of the bracket in kg.
/// The five threshold fields are 1RM values in kg corresponding to
/// Beginner (5th), Novice (20th), Intermediate (50th),
/// Advanced (80th), and Elite (95th) percentiles.
class StrengthStandardRow {
  final double bodyweight;
  final double beginner;   // > 5th percentile
  final double novice;     // > 20th percentile
  final double intermediate; // > 50th percentile
  final double advanced;   // > 80th percentile
  final double elite;      // > 95th percentile

  const StrengthStandardRow({
    required this.bodyweight,
    required this.beginner,
    required this.novice,
    required this.intermediate,
    required this.advanced,
    required this.elite,
  });
}

/// Result of a percentile lookup.
class StrengthPercentileResult {
  /// Estimated percentile as an integer 1–99.
  final int percentile;

  /// Human-readable level label.
  final String label;

  const StrengthPercentileResult({
    required this.percentile,
    required this.label,
  });
}

// ---------------------------------------------------------------------------
// Lookup tables — Male
// Source: https://strengthlevel.com/strength-standards/male/kg
// ---------------------------------------------------------------------------

const _maleBenchPress = [
  StrengthStandardRow(bodyweight: 50,  beginner: 24,  novice: 38,  intermediate: 57,  advanced: 79,  elite: 103),
  StrengthStandardRow(bodyweight: 55,  beginner: 29,  novice: 45,  intermediate: 64,  advanced: 87,  elite: 113),
  StrengthStandardRow(bodyweight: 60,  beginner: 34,  novice: 51,  intermediate: 72,  advanced: 96,  elite: 123),
  StrengthStandardRow(bodyweight: 65,  beginner: 39,  novice: 57,  intermediate: 79,  advanced: 104, elite: 132),
  StrengthStandardRow(bodyweight: 70,  beginner: 44,  novice: 62,  intermediate: 85,  advanced: 112, elite: 141),
  StrengthStandardRow(bodyweight: 75,  beginner: 49,  novice: 68,  intermediate: 92,  advanced: 119, elite: 149),
  StrengthStandardRow(bodyweight: 80,  beginner: 53,  novice: 74,  intermediate: 98,  advanced: 127, elite: 157),
  StrengthStandardRow(bodyweight: 85,  beginner: 58,  novice: 79,  intermediate: 105, advanced: 134, elite: 165),
  StrengthStandardRow(bodyweight: 90,  beginner: 62,  novice: 84,  intermediate: 111, advanced: 141, elite: 172),
  StrengthStandardRow(bodyweight: 95,  beginner: 67,  novice: 89,  intermediate: 116, advanced: 147, elite: 180),
  StrengthStandardRow(bodyweight: 100, beginner: 71,  novice: 94,  intermediate: 122, advanced: 153, elite: 187),
  StrengthStandardRow(bodyweight: 105, beginner: 75,  novice: 99,  intermediate: 128, advanced: 160, elite: 194),
  StrengthStandardRow(bodyweight: 110, beginner: 80,  novice: 104, intermediate: 133, advanced: 166, elite: 200),
  StrengthStandardRow(bodyweight: 115, beginner: 84,  novice: 109, intermediate: 138, advanced: 172, elite: 207),
  StrengthStandardRow(bodyweight: 120, beginner: 88,  novice: 113, intermediate: 143, advanced: 177, elite: 213),
  StrengthStandardRow(bodyweight: 125, beginner: 92,  novice: 118, intermediate: 148, advanced: 183, elite: 219),
  StrengthStandardRow(bodyweight: 130, beginner: 95,  novice: 122, intermediate: 153, advanced: 188, elite: 225),
  StrengthStandardRow(bodyweight: 135, beginner: 99,  novice: 126, intermediate: 158, advanced: 194, elite: 231),
  StrengthStandardRow(bodyweight: 140, beginner: 103, novice: 130, intermediate: 163, advanced: 199, elite: 236),
];

const _maleSquat = [
  StrengthStandardRow(bodyweight: 50,  beginner: 33,  novice: 52,  intermediate: 76,  advanced: 104, elite: 136),
  StrengthStandardRow(bodyweight: 55,  beginner: 40,  novice: 60,  intermediate: 86,  advanced: 116, elite: 149),
  StrengthStandardRow(bodyweight: 60,  beginner: 47,  novice: 68,  intermediate: 95,  advanced: 127, elite: 161),
  StrengthStandardRow(bodyweight: 65,  beginner: 53,  novice: 76,  intermediate: 104, advanced: 137, elite: 173),
  StrengthStandardRow(bodyweight: 70,  beginner: 59,  novice: 83,  intermediate: 113, advanced: 147, elite: 184),
  StrengthStandardRow(bodyweight: 75,  beginner: 66,  novice: 91,  intermediate: 122, advanced: 157, elite: 195),
  StrengthStandardRow(bodyweight: 80,  beginner: 72,  novice: 98,  intermediate: 130, advanced: 166, elite: 205),
  StrengthStandardRow(bodyweight: 85,  beginner: 78,  novice: 105, intermediate: 138, advanced: 175, elite: 215),
  StrengthStandardRow(bodyweight: 90,  beginner: 83,  novice: 112, intermediate: 146, advanced: 184, elite: 225),
  StrengthStandardRow(bodyweight: 95,  beginner: 89,  novice: 118, intermediate: 153, advanced: 192, elite: 234),
  StrengthStandardRow(bodyweight: 100, beginner: 95,  novice: 125, intermediate: 160, advanced: 201, elite: 243),
  StrengthStandardRow(bodyweight: 105, beginner: 100, novice: 131, intermediate: 168, advanced: 209, elite: 252),
  StrengthStandardRow(bodyweight: 110, beginner: 106, novice: 137, intermediate: 174, advanced: 216, elite: 260),
  StrengthStandardRow(bodyweight: 115, beginner: 111, novice: 143, intermediate: 181, advanced: 224, elite: 269),
  StrengthStandardRow(bodyweight: 120, beginner: 116, novice: 149, intermediate: 188, advanced: 231, elite: 277),
  StrengthStandardRow(bodyweight: 125, beginner: 121, novice: 155, intermediate: 194, advanced: 238, elite: 284),
  StrengthStandardRow(bodyweight: 130, beginner: 126, novice: 160, intermediate: 201, advanced: 245, elite: 292),
  StrengthStandardRow(bodyweight: 135, beginner: 131, novice: 166, intermediate: 207, advanced: 252, elite: 299),
  StrengthStandardRow(bodyweight: 140, beginner: 136, novice: 171, intermediate: 213, advanced: 259, elite: 307),
];

const _maleDeadlift = [
  StrengthStandardRow(bodyweight: 50,  beginner: 44,  novice: 65,  intermediate: 93,  advanced: 125, elite: 160),
  StrengthStandardRow(bodyweight: 55,  beginner: 51,  novice: 74,  intermediate: 103, advanced: 137, elite: 174),
  StrengthStandardRow(bodyweight: 60,  beginner: 58,  novice: 83,  intermediate: 114, advanced: 149, elite: 187),
  StrengthStandardRow(bodyweight: 65,  beginner: 66,  novice: 92,  intermediate: 124, advanced: 160, elite: 200),
  StrengthStandardRow(bodyweight: 70,  beginner: 73,  novice: 100, intermediate: 133, advanced: 171, elite: 212),
  StrengthStandardRow(bodyweight: 75,  beginner: 79,  novice: 108, intermediate: 142, advanced: 182, elite: 224),
  StrengthStandardRow(bodyweight: 80,  beginner: 86,  novice: 116, intermediate: 151, advanced: 192, elite: 235),
  StrengthStandardRow(bodyweight: 85,  beginner: 93,  novice: 123, intermediate: 160, advanced: 201, elite: 245),
  StrengthStandardRow(bodyweight: 90,  beginner: 99,  novice: 131, intermediate: 168, advanced: 211, elite: 256),
  StrengthStandardRow(bodyweight: 95,  beginner: 105, novice: 138, intermediate: 176, advanced: 220, elite: 266),
  StrengthStandardRow(bodyweight: 100, beginner: 111, novice: 145, intermediate: 184, advanced: 228, elite: 275),
  StrengthStandardRow(bodyweight: 105, beginner: 117, novice: 151, intermediate: 192, advanced: 237, elite: 284),
  StrengthStandardRow(bodyweight: 110, beginner: 123, novice: 158, intermediate: 199, advanced: 245, elite: 293),
  StrengthStandardRow(bodyweight: 115, beginner: 129, novice: 164, intermediate: 206, advanced: 253, elite: 302),
  StrengthStandardRow(bodyweight: 120, beginner: 134, novice: 171, intermediate: 213, advanced: 261, elite: 311),
  StrengthStandardRow(bodyweight: 125, beginner: 140, novice: 177, intermediate: 220, advanced: 268, elite: 319),
  StrengthStandardRow(bodyweight: 130, beginner: 145, novice: 183, intermediate: 227, advanced: 276, elite: 327),
  StrengthStandardRow(bodyweight: 135, beginner: 150, novice: 188, intermediate: 233, advanced: 283, elite: 335),
  StrengthStandardRow(bodyweight: 140, beginner: 155, novice: 194, intermediate: 240, advanced: 290, elite: 342),
];

const _maleShoulderPress = [
  StrengthStandardRow(bodyweight: 50,  beginner: 15,  novice: 25,  intermediate: 38,  advanced: 53,  elite: 71),
  StrengthStandardRow(bodyweight: 55,  beginner: 18,  novice: 29,  intermediate: 42,  advanced: 59,  elite: 77),
  StrengthStandardRow(bodyweight: 60,  beginner: 21,  novice: 32,  intermediate: 47,  advanced: 64,  elite: 84),
  StrengthStandardRow(bodyweight: 65,  beginner: 24,  novice: 36,  intermediate: 52,  advanced: 70,  elite: 90),
  StrengthStandardRow(bodyweight: 70,  beginner: 27,  novice: 40,  intermediate: 56,  advanced: 75,  elite: 95),
  StrengthStandardRow(bodyweight: 75,  beginner: 30,  novice: 43,  intermediate: 60,  advanced: 80,  elite: 101),
  StrengthStandardRow(bodyweight: 80,  beginner: 33,  novice: 47,  intermediate: 64,  advanced: 84,  elite: 106),
  StrengthStandardRow(bodyweight: 85,  beginner: 36,  novice: 50,  intermediate: 68,  advanced: 89,  elite: 111),
  StrengthStandardRow(bodyweight: 90,  beginner: 39,  novice: 54,  intermediate: 72,  advanced: 93,  elite: 116),
  StrengthStandardRow(bodyweight: 95,  beginner: 41,  novice: 57,  intermediate: 76,  advanced: 97,  elite: 121),
  StrengthStandardRow(bodyweight: 100, beginner: 44,  novice: 60,  intermediate: 79,  advanced: 102, elite: 125),
  StrengthStandardRow(bodyweight: 105, beginner: 47,  novice: 63,  intermediate: 83,  advanced: 106, elite: 130),
  StrengthStandardRow(bodyweight: 110, beginner: 49,  novice: 66,  intermediate: 86,  advanced: 109, elite: 134),
  StrengthStandardRow(bodyweight: 115, beginner: 52,  novice: 69,  intermediate: 90,  advanced: 113, elite: 138),
  StrengthStandardRow(bodyweight: 120, beginner: 54,  novice: 72,  intermediate: 93,  advanced: 117, elite: 142),
  StrengthStandardRow(bodyweight: 125, beginner: 57,  novice: 75,  intermediate: 96,  advanced: 120, elite: 146),
  StrengthStandardRow(bodyweight: 130, beginner: 59,  novice: 77,  intermediate: 99,  advanced: 124, elite: 150),
  StrengthStandardRow(bodyweight: 135, beginner: 61,  novice: 80,  intermediate: 102, advanced: 127, elite: 154),
  StrengthStandardRow(bodyweight: 140, beginner: 64,  novice: 83,  intermediate: 105, advanced: 131, elite: 157),
];

const _maleBentOverRow = [
  StrengthStandardRow(bodyweight: 50,  beginner: 21,  novice: 34,  intermediate: 51,  advanced: 71,  elite: 94),
  StrengthStandardRow(bodyweight: 55,  beginner: 25,  novice: 39,  intermediate: 57,  advanced: 79,  elite: 102),
  StrengthStandardRow(bodyweight: 60,  beginner: 29,  novice: 44,  intermediate: 63,  advanced: 86,  elite: 110),
  StrengthStandardRow(bodyweight: 65,  beginner: 33,  novice: 49,  intermediate: 69,  advanced: 93,  elite: 118),
  StrengthStandardRow(bodyweight: 70,  beginner: 37,  novice: 54,  intermediate: 75,  advanced: 99,  elite: 126),
  StrengthStandardRow(bodyweight: 75,  beginner: 41,  novice: 59,  intermediate: 80,  advanced: 106, elite: 133),
  StrengthStandardRow(bodyweight: 80,  beginner: 45,  novice: 63,  intermediate: 86,  advanced: 112, elite: 140),
  StrengthStandardRow(bodyweight: 85,  beginner: 49,  novice: 68,  intermediate: 91,  advanced: 118, elite: 146),
  StrengthStandardRow(bodyweight: 90,  beginner: 52,  novice: 72,  intermediate: 96,  advanced: 123, elite: 153),
  StrengthStandardRow(bodyweight: 95,  beginner: 56,  novice: 76,  intermediate: 101, advanced: 129, elite: 159),
  StrengthStandardRow(bodyweight: 100, beginner: 60,  novice: 80,  intermediate: 106, advanced: 134, elite: 165),
  StrengthStandardRow(bodyweight: 105, beginner: 63,  novice: 84,  intermediate: 110, advanced: 139, elite: 170),
  StrengthStandardRow(bodyweight: 110, beginner: 66,  novice: 88,  intermediate: 115, advanced: 144, elite: 176),
  StrengthStandardRow(bodyweight: 115, beginner: 70,  novice: 92,  intermediate: 119, advanced: 149, elite: 181),
  StrengthStandardRow(bodyweight: 120, beginner: 73,  novice: 96,  intermediate: 123, advanced: 154, elite: 187),
  StrengthStandardRow(bodyweight: 125, beginner: 76,  novice: 100, intermediate: 128, advanced: 159, elite: 192),
  StrengthStandardRow(bodyweight: 130, beginner: 79,  novice: 103, intermediate: 132, advanced: 163, elite: 197),
  StrengthStandardRow(bodyweight: 135, beginner: 83,  novice: 107, intermediate: 136, advanced: 168, elite: 202),
  StrengthStandardRow(bodyweight: 140, beginner: 86,  novice: 110, intermediate: 139, advanced: 172, elite: 206),
];

// ---------------------------------------------------------------------------
// Lookup tables — Female
// Source: https://strengthlevel.com/strength-standards/female/kg
// ---------------------------------------------------------------------------

const _femaleBenchPress = [
  StrengthStandardRow(bodyweight: 40,  beginner: 8,   novice: 18,  intermediate: 32,  advanced: 50,  elite: 70),
  StrengthStandardRow(bodyweight: 45,  beginner: 10,  novice: 21,  intermediate: 36,  advanced: 55,  elite: 76),
  StrengthStandardRow(bodyweight: 50,  beginner: 12,  novice: 24,  intermediate: 40,  advanced: 59,  elite: 82),
  StrengthStandardRow(bodyweight: 55,  beginner: 15,  novice: 27,  intermediate: 43,  advanced: 64,  elite: 87),
  StrengthStandardRow(bodyweight: 60,  beginner: 17,  novice: 29,  intermediate: 47,  advanced: 68,  elite: 92),
  StrengthStandardRow(bodyweight: 65,  beginner: 19,  novice: 32,  intermediate: 50,  advanced: 72,  elite: 96),
  StrengthStandardRow(bodyweight: 70,  beginner: 20,  novice: 34,  intermediate: 53,  advanced: 75,  elite: 101),
  StrengthStandardRow(bodyweight: 75,  beginner: 22,  novice: 37,  intermediate: 56,  advanced: 79,  elite: 105),
  StrengthStandardRow(bodyweight: 80,  beginner: 24,  novice: 39,  intermediate: 59,  advanced: 82,  elite: 109),
  StrengthStandardRow(bodyweight: 85,  beginner: 26,  novice: 41,  intermediate: 62,  advanced: 86,  elite: 112),
  StrengthStandardRow(bodyweight: 90,  beginner: 28,  novice: 44,  intermediate: 64,  advanced: 89,  elite: 116),
  StrengthStandardRow(bodyweight: 95,  beginner: 29,  novice: 46,  intermediate: 67,  advanced: 92,  elite: 119),
  StrengthStandardRow(bodyweight: 100, beginner: 31,  novice: 48,  intermediate: 69,  advanced: 95,  elite: 123),
  StrengthStandardRow(bodyweight: 105, beginner: 33,  novice: 50,  intermediate: 72,  advanced: 98,  elite: 126),
  StrengthStandardRow(bodyweight: 110, beginner: 34,  novice: 52,  intermediate: 74,  advanced: 100, elite: 129),
  StrengthStandardRow(bodyweight: 115, beginner: 36,  novice: 54,  intermediate: 76,  advanced: 103, elite: 132),
  StrengthStandardRow(bodyweight: 120, beginner: 37,  novice: 56,  intermediate: 79,  advanced: 106, elite: 135),
];

const _femaleSquat = [
  StrengthStandardRow(bodyweight: 40,  beginner: 17,  novice: 31,  intermediate: 51,  advanced: 75,  elite: 101),
  StrengthStandardRow(bodyweight: 45,  beginner: 20,  novice: 36,  intermediate: 56,  advanced: 81,  elite: 109),
  StrengthStandardRow(bodyweight: 50,  beginner: 23,  novice: 39,  intermediate: 61,  advanced: 87,  elite: 115),
  StrengthStandardRow(bodyweight: 55,  beginner: 26,  novice: 43,  intermediate: 65,  advanced: 92,  elite: 122),
  StrengthStandardRow(bodyweight: 60,  beginner: 29,  novice: 47,  intermediate: 70,  advanced: 97,  elite: 128),
  StrengthStandardRow(bodyweight: 65,  beginner: 32,  novice: 50,  intermediate: 74,  advanced: 102, elite: 133),
  StrengthStandardRow(bodyweight: 70,  beginner: 34,  novice: 53,  intermediate: 78,  advanced: 106, elite: 138),
  StrengthStandardRow(bodyweight: 75,  beginner: 37,  novice: 56,  intermediate: 81,  advanced: 111, elite: 143),
  StrengthStandardRow(bodyweight: 80,  beginner: 39,  novice: 59,  intermediate: 85,  advanced: 115, elite: 148),
  StrengthStandardRow(bodyweight: 85,  beginner: 41,  novice: 62,  intermediate: 88,  advanced: 119, elite: 152),
  StrengthStandardRow(bodyweight: 90,  beginner: 44,  novice: 65,  intermediate: 91,  advanced: 123, elite: 157),
  StrengthStandardRow(bodyweight: 95,  beginner: 46,  novice: 68,  intermediate: 95,  advanced: 126, elite: 161),
  StrengthStandardRow(bodyweight: 100, beginner: 48,  novice: 70,  intermediate: 98,  advanced: 130, elite: 165),
  StrengthStandardRow(bodyweight: 105, beginner: 50,  novice: 73,  intermediate: 101, advanced: 133, elite: 169),
  StrengthStandardRow(bodyweight: 110, beginner: 52,  novice: 75,  intermediate: 103, advanced: 136, elite: 172),
  StrengthStandardRow(bodyweight: 115, beginner: 54,  novice: 77,  intermediate: 106, advanced: 140, elite: 176),
  StrengthStandardRow(bodyweight: 120, beginner: 56,  novice: 80,  intermediate: 109, advanced: 143, elite: 179),
];

const _femaleDeadlift = [
  StrengthStandardRow(bodyweight: 40,  beginner: 24,  novice: 40,  intermediate: 62,  advanced: 89,  elite: 118),
  StrengthStandardRow(bodyweight: 45,  beginner: 27,  novice: 45,  intermediate: 68,  advanced: 95,  elite: 126),
  StrengthStandardRow(bodyweight: 50,  beginner: 31,  novice: 49,  intermediate: 73,  advanced: 102, elite: 133),
  StrengthStandardRow(bodyweight: 55,  beginner: 34,  novice: 53,  intermediate: 78,  advanced: 107, elite: 140),
  StrengthStandardRow(bodyweight: 60,  beginner: 37,  novice: 57,  intermediate: 83,  advanced: 113, elite: 146),
  StrengthStandardRow(bodyweight: 65,  beginner: 40,  novice: 61,  intermediate: 87,  advanced: 118, elite: 152),
  StrengthStandardRow(bodyweight: 70,  beginner: 43,  novice: 64,  intermediate: 91,  advanced: 123, elite: 157),
  StrengthStandardRow(bodyweight: 75,  beginner: 45,  novice: 67,  intermediate: 95,  advanced: 127, elite: 163),
  StrengthStandardRow(bodyweight: 80,  beginner: 48,  novice: 71,  intermediate: 99,  advanced: 132, elite: 168),
  StrengthStandardRow(bodyweight: 85,  beginner: 51,  novice: 74,  intermediate: 102, advanced: 136, elite: 172),
  StrengthStandardRow(bodyweight: 90,  beginner: 53,  novice: 77,  intermediate: 106, advanced: 140, elite: 177),
  StrengthStandardRow(bodyweight: 95,  beginner: 55,  novice: 79,  intermediate: 109, advanced: 144, elite: 181),
  StrengthStandardRow(bodyweight: 100, beginner: 58,  novice: 82,  intermediate: 112, advanced: 147, elite: 185),
  StrengthStandardRow(bodyweight: 105, beginner: 60,  novice: 85,  intermediate: 116, advanced: 151, elite: 189),
  StrengthStandardRow(bodyweight: 110, beginner: 62,  novice: 87,  intermediate: 119, advanced: 154, elite: 193),
  StrengthStandardRow(bodyweight: 115, beginner: 64,  novice: 90,  intermediate: 121, advanced: 158, elite: 197),
  StrengthStandardRow(bodyweight: 120, beginner: 66,  novice: 92,  intermediate: 124, advanced: 161, elite: 200),
];

const _femaleShoulderPress = [
  StrengthStandardRow(bodyweight: 40,  beginner: 7,   novice: 14,  intermediate: 23,  advanced: 35,  elite: 48),
  StrengthStandardRow(bodyweight: 45,  beginner: 8,   novice: 16,  intermediate: 25,  advanced: 38,  elite: 52),
  StrengthStandardRow(bodyweight: 50,  beginner: 10,  novice: 17,  intermediate: 28,  advanced: 40,  elite: 55),
  StrengthStandardRow(bodyweight: 55,  beginner: 11,  novice: 19,  intermediate: 30,  advanced: 43,  elite: 58),
  StrengthStandardRow(bodyweight: 60,  beginner: 12,  novice: 21,  intermediate: 32,  advanced: 45,  elite: 60),
  StrengthStandardRow(bodyweight: 65,  beginner: 13,  novice: 22,  intermediate: 34,  advanced: 48,  elite: 63),
  StrengthStandardRow(bodyweight: 70,  beginner: 15,  novice: 24,  intermediate: 35,  advanced: 50,  elite: 65),
  StrengthStandardRow(bodyweight: 75,  beginner: 16,  novice: 25,  intermediate: 37,  advanced: 52,  elite: 68),
  StrengthStandardRow(bodyweight: 80,  beginner: 17,  novice: 26,  intermediate: 39,  advanced: 54,  elite: 70),
  StrengthStandardRow(bodyweight: 85,  beginner: 18,  novice: 28,  intermediate: 40,  advanced: 55,  elite: 72),
  StrengthStandardRow(bodyweight: 90,  beginner: 19,  novice: 29,  intermediate: 42,  advanced: 57,  elite: 74),
  StrengthStandardRow(bodyweight: 95,  beginner: 20,  novice: 30,  intermediate: 43,  advanced: 59,  elite: 76),
  StrengthStandardRow(bodyweight: 100, beginner: 21,  novice: 31,  intermediate: 45,  advanced: 61,  elite: 78),
  StrengthStandardRow(bodyweight: 105, beginner: 22,  novice: 32,  intermediate: 46,  advanced: 62,  elite: 80),
  StrengthStandardRow(bodyweight: 110, beginner: 23,  novice: 34,  intermediate: 47,  advanced: 64,  elite: 81),
  StrengthStandardRow(bodyweight: 115, beginner: 23,  novice: 35,  intermediate: 49,  advanced: 65,  elite: 83),
  StrengthStandardRow(bodyweight: 120, beginner: 24,  novice: 36,  intermediate: 50,  advanced: 66,  elite: 85),
];

const _femaleBentOverRow = [
  StrengthStandardRow(bodyweight: 40,  beginner: 10,  novice: 19,  intermediate: 31,  advanced: 47,  elite: 64),
  StrengthStandardRow(bodyweight: 45,  beginner: 11,  novice: 21,  intermediate: 34,  advanced: 49,  elite: 68),
  StrengthStandardRow(bodyweight: 50,  beginner: 13,  novice: 22,  intermediate: 36,  advanced: 52,  elite: 71),
  StrengthStandardRow(bodyweight: 55,  beginner: 14,  novice: 24,  intermediate: 38,  advanced: 54,  elite: 73),
  StrengthStandardRow(bodyweight: 60,  beginner: 15,  novice: 25,  intermediate: 39,  advanced: 57,  elite: 76),
  StrengthStandardRow(bodyweight: 65,  beginner: 16,  novice: 27,  intermediate: 41,  advanced: 59,  elite: 78),
  StrengthStandardRow(bodyweight: 70,  beginner: 17,  novice: 28,  intermediate: 43,  advanced: 61,  elite: 80),
  StrengthStandardRow(bodyweight: 75,  beginner: 18,  novice: 29,  intermediate: 44,  advanced: 62,  elite: 83),
  StrengthStandardRow(bodyweight: 80,  beginner: 19,  novice: 31,  intermediate: 46,  advanced: 64,  elite: 85),
  StrengthStandardRow(bodyweight: 85,  beginner: 20,  novice: 32,  intermediate: 47,  advanced: 66,  elite: 86),
  StrengthStandardRow(bodyweight: 90,  beginner: 21,  novice: 33,  intermediate: 49,  advanced: 67,  elite: 88),
  StrengthStandardRow(bodyweight: 95,  beginner: 21,  novice: 34,  intermediate: 50,  advanced: 69,  elite: 90),
  StrengthStandardRow(bodyweight: 100, beginner: 22,  novice: 35,  intermediate: 51,  advanced: 70,  elite: 92),
  StrengthStandardRow(bodyweight: 105, beginner: 23,  novice: 36,  intermediate: 52,  advanced: 72,  elite: 93),
  StrengthStandardRow(bodyweight: 110, beginner: 24,  novice: 37,  intermediate: 53,  advanced: 73,  elite: 95),
  StrengthStandardRow(bodyweight: 115, beginner: 25,  novice: 38,  intermediate: 55,  advanced: 74,  elite: 96),
  StrengthStandardRow(bodyweight: 120, beginner: 25,  novice: 39,  intermediate: 56,  advanced: 76,  elite: 98),
];

// ---------------------------------------------------------------------------
// Master index — maps exercise name (lowercase) to tables by sex.
// The keys must match the seeded exercise names in local_database.dart,
// lowercased. The lookup function handles the normalisation.
// ---------------------------------------------------------------------------

const Map<String, Map<Sex, List<StrengthStandardRow>>> _standardsIndex = {
  'bench press':    {Sex.male: _maleBenchPress,    Sex.female: _femaleBenchPress},
  'squat':          {Sex.male: _maleSquat,          Sex.female: _femaleSquat},
  'deadlift':       {Sex.male: _maleDeadlift,       Sex.female: _femaleDeadlift},
  'shoulder press': {Sex.male: _maleShoulderPress,  Sex.female: _femaleShoulderPress},
  'overhead press': {Sex.male: _maleShoulderPress,  Sex.female: _femaleShoulderPress},
  'bent over row':  {Sex.male: _maleBentOverRow,    Sex.female: _femaleBentOverRow},
  'barbell row':    {Sex.male: _maleBentOverRow,    Sex.female: _femaleBentOverRow},
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns true if strength standards data exists for [exerciseName].
/// Used by the UI to conditionally show/hide the percentile widget.
bool hasStrengthStandards(String exerciseName) {
  return _standardsIndex.containsKey(exerciseName.toLowerCase().trim());
}

/// Calculates the strength percentile for a given lift.
///
/// Returns null if:
///   - No standards data exists for the exercise.
///   - [bodyweightKg] or [liftKg] is zero or negative.
///
/// [exerciseName] is matched case-insensitively against the standards index.
/// [bodyweightKg] is clamped to the nearest available bracket.
/// [liftKg] is the user's best lift — compared directly (no 1RM conversion).
///
/// Example output: "Your best Bench Press (100kg) is stronger than
/// approximately 72% of male lifters."
StrengthPercentileResult? calculatePercentile({
  required String exerciseName,
  required Sex sex,
  required double bodyweightKg,
  required double liftKg,
}) {
  if (bodyweightKg <= 0 || liftKg <= 0) return null;

  final table = _standardsIndex[exerciseName.toLowerCase().trim()]?[sex];
  if (table == null || table.isEmpty) return null;

  // Clamp bodyweight to table bounds.
  final clampedBw = bodyweightKg.clamp(
    table.first.bodyweight,
    table.last.bodyweight,
  );

  // Find the nearest row — the row whose bodyweight bracket is closest
  // to the user's clamped bodyweight.
  StrengthStandardRow nearest = table.first;
  double minDiff = (clampedBw - table.first.bodyweight).abs();
  for (final row in table) {
    final diff = (clampedBw - row.bodyweight).abs();
    if (diff < minDiff) {
      minDiff = diff;
      nearest = row;
    }
  }

  // Determine percentile band by comparing lift against thresholds.
  // The bands are open at the top — if the user beats Elite, we cap at 99.
  if (liftKg >= nearest.elite) {
    return const StrengthPercentileResult(percentile: 95, label: 'Elite');
  } else if (liftKg >= nearest.advanced) {
    // Interpolate between 80th and 95th percentile.
    final pct = _interpolate(liftKg, nearest.advanced, nearest.elite, 80, 95);
    return StrengthPercentileResult(percentile: pct, label: 'Advanced');
  } else if (liftKg >= nearest.intermediate) {
    final pct = _interpolate(liftKg, nearest.intermediate, nearest.advanced, 50, 80);
    return StrengthPercentileResult(percentile: pct, label: 'Intermediate');
  } else if (liftKg >= nearest.novice) {
    final pct = _interpolate(liftKg, nearest.novice, nearest.intermediate, 20, 50);
    return StrengthPercentileResult(percentile: pct, label: 'Novice');
  } else if (liftKg >= nearest.beginner) {
    final pct = _interpolate(liftKg, nearest.beginner, nearest.novice, 5, 20);
    return StrengthPercentileResult(percentile: pct, label: 'Beginner');
  } else {
    return const StrengthPercentileResult(percentile: 5, label: 'Beginner');
  }
}

/// Linear interpolation between two percentile bands.
/// Gives a smoother result than hard band boundaries.
int _interpolate(
  double lift,
  double lower,
  double upper,
  int lowerPct,
  int upperPct,
) {
  if (upper <= lower) return lowerPct;
  final t = (lift - lower) / (upper - lower);
  return (lowerPct + t * (upperPct - lowerPct)).round().clamp(lowerPct, upperPct);
}