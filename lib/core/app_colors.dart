import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5CB8);
  static const Color primaryDark = Color(0xFF0F2460);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color secondaryLight = Color(0xFF67E8F9);
  static const Color secondaryDark = Color(0xFF0891B2);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceAlt = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1E293B);
  static const Color onSurfaceMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF1F5F9);

  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceAltDark = Color(0xFF1E293B);
  static const Color onSurfaceDark = Color(0xFFF1F5F9);
  static const Color onSurfaceMutedDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color shimmerBaseDark = Color(0xFF1E293B);
  static const Color shimmerHighlightDark = Color(0xFF334155);

  static const Color primaryBlue = primary;
  static const Color accentCyan = secondary;
  static const Color darkNavy = onSurface;
  static const Color backgroundGray = surface;
  static const Color white = surfaceAlt;

  /// Theme-aware helpers — use these in place of direct constants
  /// to automatically adapt when dark mode is toggled.
  static Color surfaceOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? surfaceDark : surface;
  static Color surfaceAltOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? surfaceAltDark : surfaceAlt;
  static Color onSurfaceOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? onSurfaceDark : onSurface;
  static Color onSurfaceMutedOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? onSurfaceMutedDark : onSurfaceMuted;
  static Color borderOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? borderDark : border;
  static Color shimmerBaseOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? shimmerBaseDark : shimmerBase;
  static Color shimmerHighlightOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? shimmerHighlightDark : shimmerHighlight;
}
