import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumb({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
            ),
          ],
          InkWell(
            onTap: items[i].onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                items[i].label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == items.length - 1 ? FontWeight.w600 : FontWeight.w400,
                  color: i == items.length - 1
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem({required this.label, this.onTap});
}
