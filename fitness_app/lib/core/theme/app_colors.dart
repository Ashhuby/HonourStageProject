import 'package:flutter/material.dart';

/// Centralised colour palette for the OneRep design system.
///
/// All colours are `const` so they can be used in `const` widget constructors.
/// Never reach for [Colors] directly in UI code — use this class instead.
class OneRepColors {
  OneRepColors._();

  // ---------------------------------------------------------------------------
  // Backgrounds — deep burgundy undertone
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFF120A0A);
  static const Color surface = Color(0xFF1E1010);
  static const Color surfaceElevated = Color(0xFF2A1515);
  static const Color surfaceHighest = Color(0xFF361C1C);

  // ---------------------------------------------------------------------------
  // Accents
  // ---------------------------------------------------------------------------

  /// Pure white — used for primary actions and high-emphasis text.
  static const Color accent = Color(0xFFFFFFFF);

  /// 20% white — used for subtle overlays on the accent colour.
  static const Color accentDim = Color(0x33FFFFFF);

  /// Gold — PRs, achievements, active navigation items.
  static const Color gold = Color(0xFFD4AF37);

  /// 20% gold — used for subtle gold overlays and highlights.
  static const Color goldDim = Color(0x33D4AF37);

  // ---------------------------------------------------------------------------
  // Badge tiers
  // ---------------------------------------------------------------------------
  //
  // [gold] above is the tier colour for BadgeTier.gold as well as the app's
  // general achievement accent, so the ladder is built around it rather than
  // beside it. Bronze and silver are the conventional metals; platinum takes an
  // icy blue-white rather than a true platinum grey, which on this background
  // would be indistinguishable from [textPrimary] — it is the rarest tier and
  // has to read as such.

  static const Color bronze = Color(0xFFCD7F32);
  static const Color silver = Color(0xFFC8CDD4);
  static const Color platinum = Color(0xFF9FE8F5);

  // ---------------------------------------------------------------------------
  // Ranks
  // ---------------------------------------------------------------------------
  //
  // A separate ladder from the badge tiers above, and separated by hue rather
  // than by shade on purpose: the two appear together in the badges header, so
  // a rank has to be told apart from a tier at a glance and not only by
  // reading the label — and at the sixteen pixels the nav bar gives the crest,
  // the colour is all there is.
  //
  // Hue rather than a literal rock palette for that reason. Six greys and
  // browns would be the honest colours and would be indistinguishable, so the
  // ladder climbs instead: warm sand, cool wet pebble, blue-grey stone, the
  // violet cast of shadowed rock, lichen on a cliff face, and finally the
  // white-blue of a snow-capped peak.

  static const Color sand = Color(0xFFE0C48F);
  static const Color pebble = Color(0xFF97A6AB);
  static const Color stone = Color(0xFF6E93B8);
  static const Color boulder = Color(0xFF8B7BC4);
  static const Color cliff = Color(0xFF5FBF9B);
  static const Color mountain = Color(0xFFDCE9FF);

  /// Coral — rest timer warning state.
  static const Color coral = Color(0xFFFF6B6B);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF9E7070);
  static const Color textDisabled = Color(0xFF5A3A3A);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF66BB6A);
  static const Color error = Color(0xFFFF5252);

  // ---------------------------------------------------------------------------
  // Body part colours — exercise library chips
  // ---------------------------------------------------------------------------

  static const Color chest = Color(0xFFEF9A9A);
  static const Color back = Color(0xFF90CAF9);
  static const Color legs = Color(0xFFA5D6A7);
  static const Color shoulders = Color(0xFFFFCC80);
  static const Color biceps = Color(0xFFCE93D8);
  static const Color core = Color(0xFFF48FB1);

  // ---------------------------------------------------------------------------
  // Activity category colours — the axis above muscle groups
  // ---------------------------------------------------------------------------
  //
  // Strength takes the app accent rather than a pastel: it is the default mode
  // and its rows are already tinted by muscle group. The other two adopt the
  // two body-part pastels the muscle vocabulary no longer uses — the cyan was
  // never claimed by a MuscleGroup once Arms took the purple, and the peach
  // was freed by retiring Full Body. No new hex values.

  static const Color strength = accent;
  static const Color cardio = Color(0xFFFFAB91);
  static const Color mobility = Color(0xFF80DEEA);
}
