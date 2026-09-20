import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF0B5D3B);
  static const primaryDark = Color(0xFF063B29);
  static const primaryLight = Color(0xFF2E8B62);
  static const accent = Color(0xFFF4B942);
  static const accentLight = Color(0xFFFFD978);
  static const cricketRed = Color(0xFFE5484D);
  static const liveRed = Color(0xFFFF3B30);
  static const background = Color(0xFFF5F8F6);
  static const surface = Colors.white;
  static const cardBorder = Color(0xFFE2E9E5);
  static const textPrimary = Color(0xFF14231D);
  static const textSecondary = Color(0xFF687870);
  static const success = Color(0xFF238B5B);
  static const gradientStart = Color(0xFF063B29);
  static const gradientEnd = Color(0xFF0B7650);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = GoogleFonts.interTextTheme();
    return base.apply(
      bodyColor: brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
      displayColor: brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
    );
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0B1511) : AppColors.background;
    final surface = dark ? const Color(0xFF122019) : AppColors.surface;
    final border = dark ? const Color(0xFF25372F) : AppColors.cardBorder;
    final text = dark ? const Color(0xFFF2F7F4) : AppColors.textPrimary;
    final secondary = dark ? const Color(0xFFA8B7AF) : AppColors.textSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      textTheme: _textTheme(brightness),
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.primaryDark,
        surface: surface,
        onSurface: text,
        error: AppColors.cricketRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.primaryDark : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: secondary),
        hintStyle: TextStyle(color: secondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryLight, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(110, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primaryLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: dark ? 0.32 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : secondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.primary : secondary, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF1B2A23) : const Color(0xFFEDF3EF),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  static LinearGradient get headerGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.gradientStart, AppColors.gradientEnd],
      );
}
