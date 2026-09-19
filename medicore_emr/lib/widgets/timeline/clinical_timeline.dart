import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/clinical_record.dart';

class ClinicalTimeline extends StatelessWidget {
  final List<ClinicalRecord> records;

  const ClinicalTimeline({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < records.length; i++)
          _buildTimelineItem(records[i], isFirst: i == 0, isLast: i == records.length - 1),
      ],
    );
  }

  Widget _buildTimelineItem(ClinicalRecord record, {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? AppColors.primaryBlue : AppColors.textHint,
                    border: Border.all(
                      color: isFirst ? AppColors.primaryBlue : AppColors.textHint,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _typeColor(record.recordType).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            record.recordType,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _typeColor(record.recordType),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          _formatDateTime(record.recordDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      record.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (record.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        record.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (record.tags != null && record.tags!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: record.tags!
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.borderLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                    // Link for image studies
                    if (record.recordType == 'ESTUDIO DE IMAGEN') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Ver Resultados Preliminares',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'CONSULTA GENERAL':
        return AppColors.primaryBlue;
      case 'ESTUDIO DE IMAGEN':
        return AppColors.textSecondary;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _formatDateTime(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year} - ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
  }
}
