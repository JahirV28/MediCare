import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const AvatarCircle({
    super.key,
    required this.initials,
    this.size = 36,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryBlue.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.primaryBlue,
        ),
      ),
    );
  }
}
