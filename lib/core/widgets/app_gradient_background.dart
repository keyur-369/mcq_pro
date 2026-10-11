import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';

class AppGradientBackground extends StatelessWidget {
  final Widget child;
  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, AppColors.primarySoft],
        ),
      ),
      child: child,
    );
  }
}
