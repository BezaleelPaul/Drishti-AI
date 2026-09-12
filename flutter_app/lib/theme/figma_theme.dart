import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens lifted from "Enhance Drishti-AI Prototype (1)"
/// (React + Tailwind): cyan primary, slate surfaces, Nunito type.
abstract final class FigmaColors {
  static const primary = Color(0xFF0891B2); // cyan-600
  static const primaryDark = Color(0xFF0E7490); // cyan-700
  static const primarySoft = Color(0xFFECFEFF); // cyan-50
  static const primaryBorder = Color(0xFFA5F3FC); // cyan-200
  static const surface = Color(0xFFF8FAFC); // slate-50
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0); // slate-200
  static const text = Color(0xFF0F172A); // slate-900
  static const muted = Color(0xFF64748B); // slate-500
  static const faint = Color(0xFF94A3B8); // slate-400
  static const success = Color(0xFF16A34A); // green-600
  static const warning = Color(0xFFD97706); // amber-600
  static const danger = Color(0xFFDC2626); // red-600
  static const purple = Color(0xFF7E22CE); // purple-700
  static const info = Color(0xFF1D4ED8); // blue-700
}

/// Figma `StatusBadgeType` mapped to pill colors + label keys.
enum FigmaStatus {
  awaitingAi(
    'badge_awaiting_ai',
    Color(0xFFFFFBEB),
    Color(0xFFB45309),
    Color(0xFFFDE68C),
  ),
  aiComplete(
    'badge_ai_complete',
    Color(0xFFEFF6FF),
    Color(0xFF1D4ED8),
    Color(0xFFBFDBFE),
  ),
  awaitingSpecialist(
    'badge_awaiting_specialist',
    Color(0xFFFAF5FF),
    Color(0xFF7E22CE),
    Color(0xFFE9D5FF),
  ),
  verified(
    'badge_verified',
    Color(0xFFF0FDF4),
    Color(0xFF15803D),
    Color(0xFFBBF7D0),
  ),
  referral(
    'badge_referral',
    Color(0xFFFEF2F2),
    Color(0xFFB91C1C),
    Color(0xFFFECACA),
  ),
  offline(
    'badge_offline',
    Color(0xFFF8FAFC),
    Color(0xFF475569),
    Color(0xFFE2E8F0),
  );

  final String labelKey;
  final Color bg;
  final Color fg;
  final Color border;

  const FigmaStatus(this.labelKey, this.bg, this.fg, this.border);
}

/// Global app theme: Figma primary/buttons/cards/inputs, Nunito type.
/// Existing screens keep their layout — bars, buttons and cards pick up
/// the Figma identity from here.
ThemeData buildFigmaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FigmaColors.primary,
      primary: FigmaColors.primary,
      secondary: FigmaColors.primaryDark,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: FigmaColors.surface,
  );

  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: FigmaColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FigmaColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: FigmaColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FigmaColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.primary, width: 2),
      ),
    ),
  );
}
