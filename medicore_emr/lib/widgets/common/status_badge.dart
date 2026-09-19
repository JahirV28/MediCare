import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  factory StatusBadge.waiting() {
    return const StatusBadge(
      text: 'En Espera',
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.warning,
    );
  }

  factory StatusBadge.confirmed() {
    return const StatusBadge(
      text: 'Confirmado',
      backgroundColor: AppColors.successLight,
      textColor: AppColors.success,
    );
  }

  factory StatusBadge.today() {
    return const StatusBadge(
      text: 'Hoy',
      backgroundColor: AppColors.primaryBlue,
      textColor: AppColors.white,
    );
  }

  factory StatusBadge.total() {
    return const StatusBadge(
      text: 'Total',
      backgroundColor: AppColors.primaryBlue,
      textColor: AppColors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.borderLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}
