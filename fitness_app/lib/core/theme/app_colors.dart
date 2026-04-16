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
  static const Color triceps = Color(0xFF80DEEA);
  static const Color core = Color(0xFFF48FB1);
  static const Color wholeBody = Color(0xFFFFAB91);
}
