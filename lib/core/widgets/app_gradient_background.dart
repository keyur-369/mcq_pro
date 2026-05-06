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
        color: AppColors.background,
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8FAFC), // Slate 50
            Color(0xFFF1F5F9), // Slate 100
            Color(0xFFE2E8F0), // Slate 200 (Subtle depth)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Top Right Glow (Primary)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          
          // Center Left Glow (Secondary/Pink)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.05),
                    AppColors.secondary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Center Glow (Cyan/Accent)
          Positioned(
            bottom: -150,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.06),
                    AppColors.accent.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          child,
        ],
      ),
    );
  }
}
