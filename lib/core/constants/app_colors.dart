import 'package:flutter/material.dart';

class AppColors {
  // Brand - Premium Light Theme
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);    // White
  static const Color card = Color(0xFFFFFFFF);       // White
  static const Color cardLight = Color(0xFFF1F5F9);  // Slate 100

  // Accent Colors - Vibrant Indigo/Violet
  static const Color primary = Color(0xFF6366F1);    // Indigo 500
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF4F46E5);  // Indigo 600
  static const Color primarySoft = Color(0xFFEEF2FF); // Indigo 50

  static const Color secondary = Color(0xFFEC4899);  // Pink 500
  static const Color accent = Color(0xFF06B6D4);     // Cyan 500

  // Functional Colors
  static const Color border = Color(0xFFE2E8F0);     // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate 100

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400

  static const Color error = Color(0xFFEF4444);      // Red 500
  static const Color success = Color(0xFF10B981);    // Emerald 500
  static const Color warning = Color(0xFFF59E0B);    // Amber 500

  // Gradients
  static const List<Color> primaryGradient = [primary, Color(0xFF8B5CF6)]; // Indigo to Violet
  static const List<Color> surfaceGradient = [Color(0xFFF8FAFC), Color(0xFFFFFFFF)];

  // Legacy/Back-compat
  static const Color boardGreen = success;
  static const Color neetYellow = warning;
  static const Color jeeRed = error;
  static const Color purple = primary;
  static const Color orange = secondary;
}
