import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for the "Refined Dark Glass" look.
class AppColors {
  AppColors._();

  // Backgrounds
  static const bg = Color(0xFF060914);
  static const bgElevated = Color(0xFF0D1326);
  static const surface = Color(0xFF131A30);

  // Brand
  static const primary = Color(0xFF4F7CFF);
  static const primaryLight = Color(0xFF8AA8FF);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFEC4899);

  // Semantic
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);

  // Text
  static const textPrimary = Colors.white;
  static final textSecondary = Colors.white.withValues(alpha: 0.68);
  static final textMuted = Colors.white.withValues(alpha: 0.42);
  static final textFaint = Colors.white.withValues(alpha: 0.24);

  // Glass
  static final glassFill = Colors.white.withValues(alpha: 0.055);
  static final glassFillStrong = Colors.white.withValues(alpha: 0.09);
  static final glassStroke = Colors.white.withValues(alpha: 0.10);
  static final glassStrokeSoft = Colors.white.withValues(alpha: 0.06);

  /// Rotating accent palette for list items (sets, subjects, etc).
  static const accents = [
    Color(0xFF4F7CFF),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF22D3EE),
  ];

  static Color accentAt(int i) => accents[i % accents.length];

  static Color scoreColor(double ratio) {
    if (ratio >= 0.75) return success;
    if (ratio >= 0.5) return warning;
    return danger;
  }
}

/// Premium ("QuizMaster Premium") styling. [active] is kept in sync with the
/// subscription state by [PremiumScope]; brand gradients switch to gold.
class PremiumStyle {
  PremiumStyle._();
  static bool active = false;

  static const gold = Color(0xFFF5B83D);
  static const goldLight = Color(0xFFFDE68A);
  static const onGold = Color(0xFF2A1A02);
}

class AppGradients {
  AppGradients._();

  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B6BFF), Color(0xFF6D5BFF), Color(0xFF9B5CF6)],
  );

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDE68A), Color(0xFFF5B83D), Color(0xFFD97706)],
  );

  static const _progressBrand = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFF4F7CFF), Color(0xFF8B5CF6)],
  );

  static const _progressGold = LinearGradient(
    colors: [Color(0xFFFDE68A), Color(0xFFF5B83D), Color(0xFFEC4899)],
  );

  /// Main call-to-action gradient (gold for Premium members).
  static LinearGradient get primary => PremiumStyle.active ? gold : brand;

  static LinearGradient get progress => PremiumStyle.active ? _progressGold : _progressBrand;

  /// Text/icon color that reads well on [primary].
  static Color get onPrimary => PremiumStyle.active ? PremiumStyle.onGold : Colors.white;

  /// Glow color for [primary].
  static Color get glow => PremiumStyle.active ? PremiumStyle.gold : AppColors.primary;

  static LinearGradient glass({double strength = 1}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.085 * strength),
          Colors.white.withValues(alpha: 0.025 * strength),
        ],
      );

  static LinearGradient accent(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.white, 0.15)!, c, Color.lerp(c, Colors.black, 0.2)!],
      );
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppText {
  AppText._();

  static TextStyle style({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
    double? height,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
        letterSpacing: spacing,
        height: height,
      );

  static TextStyle display({Color? color}) =>
      style(size: 30, weight: FontWeight.w800, spacing: -0.8, height: 1.15, color: color);

  static TextStyle title({Color? color}) =>
      style(size: 20, weight: FontWeight.w800, spacing: -0.4, color: color);

  static TextStyle body({Color? color}) =>
      style(size: 14, weight: FontWeight.w500, color: color ?? AppColors.textSecondary, height: 1.45);

  static TextStyle overline({Color? color}) =>
      style(size: 11, weight: FontWeight.w800, spacing: 1.4, color: color ?? AppColors.primaryLight);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.violet,
        tertiary: AppColors.cyan,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppText.style(size: 17, weight: FontWeight.w700, spacing: -0.2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        elevation: 8,
        contentTextStyle: AppText.style(size: 14, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.glassStroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.glassStroke),
        ),
        titleTextStyle: AppText.title(),
        contentTextStyle: AppText.body(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        hintStyle: AppText.style(color: AppColors.textFaint),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.glassStrokeSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.glassStrokeSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
