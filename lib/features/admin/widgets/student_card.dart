import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/models/app_user.dart';

class StudentCard extends StatelessWidget {
  final AppUser student;
  final ValueChanged<bool>? onToggleStatus;
  final VoidCallback? onViewDetails;
  final VoidCallback? onResetPassword;

  const StudentCard({
    super.key,
    required this.student,
    this.onToggleStatus,
    this.onViewDetails,
    this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (student.name != null && student.name!.trim().isNotEmpty)
        ? student.name!.trim()
        : 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';
    final rollNo = student.rollNo ?? '-';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onViewDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: student.isActive
                    ? AppColors.primarySoft
                    : AppColors.cardLight,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: student.isActive
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Student Info: Name, Roll Number, Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Roll Number Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Roll #$rollNo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (student.mustChangePassword) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Temp Pass',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Active / Disabled Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: student.isActive
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: student.isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      student.isActive ? 'Active' : 'Disabled',
                      style: TextStyle(
                        color: student.isActive
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),

          // Actions Row: Reset Pass, Details, Disable / Enable
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onResetPassword != null)
                TextButton.icon(
                  onPressed: onResetPassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 15),
                  label: const Text('Reset Pass'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (onViewDetails != null)
                TextButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 15),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              TextButton.icon(
                onPressed: () => onToggleStatus?.call(!student.isActive),
                icon: Icon(
                  student.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                ),
                label: Text(student.isActive ? 'Disable' : 'Enable'),
                style: TextButton.styleFrom(
                  foregroundColor: student.isActive
                      ? AppColors.error
                      : AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
