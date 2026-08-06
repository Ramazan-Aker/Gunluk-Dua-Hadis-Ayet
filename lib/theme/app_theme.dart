import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stitch "Serene Faith" tasarım sisteminin Flutter karşılığı.
abstract final class AppTheme {
  static const navy = Color(0xFF002542);
  static const navyContainer = Color(0xFF183B5B);
  static const emerald = Color(0xFF31685A);
  static const mint = Color(0xFFB2EBDA);
  static const gold = Color(0xFFD5A94E);
  static const ivory = Color(0xFFF7F5EF);
  static const surface = Color(0xFFFAF9FC);
  static const surfaceLow = Color(0xFFF4F3F6);
  static const outline = Color(0xFFC3C7CE);
  static const text = Color(0xFF1A1C1E);
  static const textMuted = Color(0xFF43474E);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ivory,
      colorScheme: const ColorScheme.light(
        primary: navy,
        onPrimary: Colors.white,
        primaryContainer: navyContainer,
        onPrimaryContainer: Color(0xFFD0E4FF),
        secondary: emerald,
        onSecondary: Colors.white,
        secondaryContainer: mint,
        onSecondaryContainer: emerald,
        tertiary: Color(0xFF4B3500),
        onTertiary: Colors.white,
        surface: surface,
        onSurface: text,
        outline: Color(0xFF73777E),
        outlineVariant: outline,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: navy,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: .96),
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          color: navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: navy),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: navy.withValues(alpha: .12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline.withValues(alpha: .35)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: navyContainer,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static List<BoxShadow> get ambientShadow => [
        BoxShadow(
          color: navyContainer.withValues(alpha: .07),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}
