import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';

class CashVoucherPreviewData {
  const CashVoucherPreviewData({
    required this.title,
    required this.voucherNo,
    required this.date,
    required this.status,
    required this.partyLabel,
    required this.partyValue,
    required this.paymentMethod,
    required this.accountName,
    required this.amountLabel,
    required this.description,
    this.note,
  });

  final String title;
  final String voucherNo;
  final String date;
  final String status;
  final String partyLabel;
  final String partyValue;
  final String paymentMethod;
  final String accountName;
  final String amountLabel;
  final String description;
  final String? note;
}

class CashVoucherPreviewDialog extends StatelessWidget {
  const CashVoucherPreviewDialog({super.key, required this.data});

  final CashVoucherPreviewData data;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.neutralGrey),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: 'إغلاق',
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'معاينة ${data.title}',
                              style: AppTextStyles.topbarTitle,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'عرض تنسيقي تقريبي لشكل السند قبل الطباعة',
                              style: AppTextStyles.fieldHint,
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.topbarIconDeepBlue,
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'رقم السند: ${data.voucherNo}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'التاريخ: ${data.date}',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PreviewInfoRow(label: 'الحالة', value: data.status),
                  _PreviewInfoRow(
                    label: data.partyLabel,
                    value: data.partyValue,
                  ),
                  _PreviewInfoRow(
                    label: 'طريقة الدفع',
                    value: data.paymentMethod,
                  ),
                  _PreviewInfoRow(label: 'الحساب', value: data.accountName),
                  _PreviewInfoRow(label: 'المبلغ', value: data.amountLabel),
                  _PreviewInfoRow(label: 'البيان', value: data.description),
                  if ((data.note ?? '').trim().isNotEmpty)
                    _PreviewInfoRow(
                      label: 'الملاحظة',
                      value: data.note!.trim(),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('إغلاق المعاينة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  const _PreviewInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: AppTextStyles.summaryLabel,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.fieldText,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
