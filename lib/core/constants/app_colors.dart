import 'package:flutter/material.dart';

class AppColors {
  // Brand (Light theme: white + light blue)
  static const Color background = Color(0xFFF7FAFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F6FF);

  static const Color primary = Color(0xFF2F7CF6);
  static const Color primarySoft = Color(0xFFE6F0FF);
  static const Color secondary = Color(0xFF1B4FD6);
  static const Color border = Color(0x1A0B1220);
  
  // Grading colors for level badges
  static const Color boardGreen = Color(0xFF4CAF50);
  static const Color neetYellow = Color(0xFFFFEB3B);
  static const Color jeeRed = Color(0xFFF44336);

  static const Color textPrimary = Color(0xFF0B1220);
  static const Color textSecondary = Color(0xFF5B6475);

  static const Color error = Color(0xFFB42318);

  // Back-compat aliases (existing screens still use these)
  static const Color purple = primary;
  static const Color orange = Color(0xFF6AB4FF);
}
