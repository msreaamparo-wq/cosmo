import 'package:flutter/material.dart';

import '../constants/cosmos_colors.dart';

/// Fonts must be bundled (assets/fonts) and declared in pubspec.yaml:
/// families "Fredoka" (headings) and "Nunito" (body). Bundled => works offline.
abstract final class CosmosTheme {
  static const headingFont = 'Fredoka';
  static const bodyFont = 'Nunito';

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    final body = base.textTheme.apply(
      fontFamily: bodyFont,
      bodyColor: CosmosColors.cloudWhite,
      displayColor: CosmosColors.cloudWhite,
    );

    TextStyle? head(TextStyle? s, {FontWeight w = FontWeight.w600}) =>
        s?.copyWith(fontFamily: headingFont, fontWeight: w);

    final textTheme = body.copyWith(
      displayLarge: head(body.displayLarge),
      displayMedium: head(body.displayMedium),
      displaySmall: head(body.displaySmall),
      headlineLarge: head(body.headlineLarge),
      headlineMedium: head(body.headlineMedium),
      headlineSmall: head(body.headlineSmall),
      titleLarge: head(body.titleLarge),
      titleMedium: head(body.titleMedium, w: FontWeight.w500),
      // Keep body text comfortably large for children.
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 16),
      labelLarge:
          body.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    );

    const scheme = ColorScheme.dark(
      primary: CosmosColors.cosmicViolet,
      onPrimary: CosmosColors.cloudWhite,
      secondary: CosmosColors.starYellow,
      onSecondary: CosmosColors.deepSpaceNavy,
      tertiary: CosmosColors.nebulaPink,
      surface: CosmosColors.midnightPurple,
      onSurface: CosmosColors.cloudWhite,
      error: CosmosColors.coral,
      onError: CosmosColors.deepSpaceNavy,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: CosmosColors.deepSpaceNavy,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56), // large touch target
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: CosmosColors.midnightPurple,
        indicatorColor: CosmosColors.cosmicViolet.withValues(alpha: .45),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CosmosColors.midnightPurple,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }
}
