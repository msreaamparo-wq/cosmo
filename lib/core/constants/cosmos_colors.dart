import 'package:flutter/material.dart';

/// COSMOS palette (from the design spec). Use these everywhere; no ad-hoc colors.
abstract final class CosmosColors {
  // Primary
  static const deepSpaceNavy = Color(0xFF101633);
  static const midnightPurple = Color(0xFF21194D);
  static const cosmicViolet = Color(0xFF8065E8);
  static const nebulaPurple = Color(0xFFA78BFA);

  // Accents
  static const starYellow = Color(0xFFFFD76A);
  static const nebulaPink = Color(0xFFF49BCB);
  static const skyBlue = Color(0xFF74C9F5);
  static const mint = Color(0xFF87E5C2);
  static const coral = Color(0xFFFF9B85);

  // Neutrals
  static const cloudWhite = Color(0xFFFFF9F0);
  static const softLavender = Color(0xFFDDD6FF);
  static const mutedGray = Color(0xFF9298B5);

  /// Planet colors offered in "Create Your Own Planet".
  static const planetChoices = <Color>[
    cosmicViolet,
    nebulaPink,
    skyBlue,
    mint,
    coral,
    starYellow,
  ];
}

extension ColorOpacityX on Color {
  /// Version-agnostic opacity helper (avoids withOpacity/withValues API churn).
  Color a(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  Color lighten([double amount = .15]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color darken([double amount = .15]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  // ignore: deprecated_member_use
  String toHex() =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color fromHex(String hex,
      {Color fallback = CosmosColors.cosmicViolet}) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16);
    if (v == null || h.length != 6) return fallback;
    return Color(0xFF000000 | v);
  }
}
