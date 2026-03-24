import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/payment_methods_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../pos_models.dart';
import 'payment_method_select.dart';
import 'pos_select.dart';

class MultiPaymentDialog extends StatefulWidget {
  const MultiPaymentDialog({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final PosState state;
  final MultiPaymentCallbacks callbacks;

  @override
  State<MultiPaymentDialog> createState() => _MultiPaymentDialogState();
}

class _MultiPaymentDialogState extends State<MultiPaymentDialog> {
  late TextEditingController _amountController;
  final _noteController = TextEditingController();
  final _staffNoteController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _cardTxnController = TextEditingController();
  String _methodCode = PaymentMethods.defaultCode;
  String? _account = 'لا أحد';
  late PosState _viewState;

  static const _accounts = ['لا أحد', 'حساب افتراضي'];

  @override
  void initState() {
    super.initState();
    _viewState = widget.state;
    _amountController = TextEditingController(
      text: _viewState.remaining.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant MultiPaymentDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _viewState = widget.state;
      _amountController.text = _viewState.remaining.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _staffNoteController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _cardTxnController.dispose();
    super.dispose();
  }

  void _addPaymentLine() {
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      AppFeedback.error(context, 'أضف مبلغ صحيح');
      return;
    }

    final line = PaymentLine(
      amount: amount,
      methodCode: _methodCode,
      account: _account,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      cardNumber: _methodCode.toUpperCase() == 'CARD'
          ? _trimOrNull(_cardNumberController.text)
          : null,
      cardHolderName: _methodCode.toUpperCase() == 'CARD'
          ? _trimOrNull(_cardHolderController.text)
          : null,
      cardTransactionId: _methodCode.toUpperCase() == 'CARD'
          ? _trimOrNull(_cardTxnController.text)
          : null,
    );

    widget.callbacks.onAddLine(line);

    _viewState = _recalculate(
      _viewState.copyWith(payments: [..._viewState.payments, line]),
    );

    _amountController.text = _viewState.remaining.toStringAsFixed(2);
    _noteController.clear();
    _cardNumberController.clear();
    _cardHolderController.clear();
    _cardTxnController.clear();
    setState(() {
      _methodCode = PaymentMethods.defaultCode;
      _account = 'لا أحد';
    });
  }

  void _removePaymentLine(int index) {
    widget.callbacks.onRemoveLine(index);
    if (index < 0 || index >= _viewState.payments.length) return;
    final updated = [..._viewState.payments]..removeAt(index);
    setState(() {
      _viewState = _recalculate(_viewState.copyWith(payments: updated));
      _amountController.text = _viewState.remaining.toStringAsFixed(2);
    });
  }

  double? _parseAmount(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  PosState _recalculate(PosState base) {
    final paid = base.payments.fold(0.0, (sum, line) => sum + line.amount);
    final remaining = base.totalAfterDiscount - paid;
    return base.copyWith(
      paid: _round2(paid),
      remaining: _round2(remaining > 0 ? remaining : 0.0),
    );
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  @override
  Widget build(BuildContext context) {
    final viewState = _viewState;
    final currency = NumberFormat('#,##0.00');
    final itemsCount = viewState.items.fold<double>(
      0.0,
      (sum, item) => sum + item.qty,
    );
    final balance = (viewState.paid - viewState.totalAfterDiscountWithDelivery);
    final balanceValue = balance > 0 ? balance : 0.0;
    final accountOptions = _accounts
        .map((item) => PosSelectOption<String>(value: item, label: item))
        .toList();
    const fieldHeight = 34.0;
    const fieldRadius = 4.0;
    const formGap = 12.0;
    const columnGap = 16.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(
        top: isCompact ? 10 : 40,
        left: isCompact ? 10 : 20,
        right: isCompact ? 10 : 20,
        bottom: 10,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? screenWidth * 0.95 : 960,
            maxHeight: isCompact
                ? MediaQuery.of(context).size.height * 0.9
                : 720,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    const Expanded(
                      child: Text(
                        'دفع',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  child: Flex(
                    direction: isCompact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: ui.TextDirection.rtl,
                    children: [
                      if (isCompact) ...[
                        _SummaryPanel(
                          itemsCount: itemsCount.toStringAsFixed(2),
                          total: currency.format(
                            viewState.totalAfterDiscountWithDelivery,
                          ),
                          paid: currency.format(viewState.paid),
                          remaining: currency.format(viewState.remaining),
                          balance: currency.format(balanceValue),
                          width: double.infinity,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        flex: isCompact ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'الرصيد المسبق: 0.00 ريال',
                              style: TextStyle(
                                color: Color(0xFF556B8D),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                              textDirection: ui.TextDirection.rtl,
                            ),
                            const SizedBox(height: formGap),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F1F1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    textDirection: ui.TextDirection.rtl,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const _Label(text: 'المبلغ*'),
                                            const SizedBox(height: 6),
                                            _CustomTextField(
                                              controller: _amountController,
                                              icon: AppIcons.cash,
                                              keyboardType:
                                                  TextInputType.number,
                                              height: fieldHeight,
                                              iconBoxSize: fieldHeight,
                                              iconSize: 16,
                                              borderRadius: fieldRadius,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: formGap),
                                  Row(
                                    textDirection: ui.TextDirection.rtl,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const _Label(text: 'طريقة الدفع*'),
                                            const SizedBox(height: 6),
                                            PaymentMethodSelect(
                                              value: _methodCode,
                                              onChanged: (val) {
                                                setState(() {
                                                  _methodCode =
                                                      val ??
                                                      PaymentMethods
                                                          .defaultCode;
                                                  if (_methodCode
                                                          .toUpperCase() !=
                                                      'CARD') {
                                                    _cardNumberController
                                                        .clear();
                                                    _cardHolderController
                                                        .clear();
                                                    _cardTxnController.clear();
                                                  }
                                                });
                                              },
                                              hintText: 'طريقة الدفع',
                                              height: fieldHeight,
                                              borderRadius: fieldRadius,
                                              enableSearch: true,
                                              maxDropdownHeight: 220,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: columnGap),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const _Label(text: 'حساب*'),
                                            const SizedBox(height: 6),
                                            PosSelect<String>(
                                              options: accountOptions,
                                              value: _account,
                                              hintText: 'حساب',
                                              height: fieldHeight,
                                              borderRadius: fieldRadius,
                                              leadingIcon: AppIcons.cash,
                                              leadingIconColor:
                                                  AppColors.borderBlue,
                                              leadingIconBoxed: true,
                                              leadingIconBoxSize: 26,
                                              leadingIconSize: 14,
                                              enableSearch: false,
                                              onChanged: (val) => setState(
                                                () => _account = val,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: formGap),
                                  if (_methodCode.toUpperCase() == 'CARD') ...[
                                    Row(
                                      textDirection: ui.TextDirection.rtl,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const _Label(text: 'رقم البطاقة'),
                                              const SizedBox(height: 6),
                                              _CustomTextField(
                                                controller:
                                                    _cardNumberController,
                                                icon: AppIcons.card,
                                                height: fieldHeight,
                                                iconBoxSize: fieldHeight,
                                                iconSize: 16,
                                                borderRadius: fieldRadius,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: columnGap),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const _Label(
                                                text: 'اسم صاحب البطاقة',
                                              ),
                                              const SizedBox(height: 6),
                                              _CustomTextField(
                                                controller:
                                                    _cardHolderController,
                                                icon: AppIcons.card,
                                                height: fieldHeight,
                                                iconBoxSize: fieldHeight,
                                                iconSize: 16,
                                                borderRadius: fieldRadius,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: formGap),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const _Label(
                                          text: 'رقم معاملة البطاقة',
                                        ),
                                        const SizedBox(height: 6),
                                        _CustomTextField(
                                          controller: _cardTxnController,
                                          icon: AppIcons.card,
                                          height: fieldHeight,
                                          iconBoxSize: fieldHeight,
                                          iconSize: 16,
                                          borderRadius: fieldRadius,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: formGap),
                                  ],
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const _Label(text: 'ملاحظة الدفع'),
                                      const SizedBox(height: 6),
                                      _CustomTextField(
                                        controller: _noteController,
                                        maxLines: 3,
                                        minHeight: 78,
                                        hint: 'ملاحظة الدفع',
                                        borderRadius: fieldRadius,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: formGap),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: _addPaymentLine,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0B2E4A,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'أضف صف دفع',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              textDirection: ui.TextDirection.rtl,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const _Label(text: 'ملاحظة الموظفين:'),
                                      const SizedBox(height: 6),
                                      _CustomTextField(
                                        controller: _staffNoteController,
                                        maxLines: 2,
                                        minHeight: 62,
                                        hint: 'ملاحظة الموظفين',
                                        borderRadius: fieldRadius,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const _Label(text: 'ملاحظة البيع:'),
                                      const SizedBox(height: 6),
                                      _CustomTextField(
                                        maxLines: 2,
                                        minHeight: 62,
                                        hint: 'ملاحظة البيع',
                                        borderRadius: fieldRadius,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _PaymentLinesTable(
                              lines: viewState.payments,
                              onRemove: _removePaymentLine,
                              currency: currency,
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 20),
                        _SummaryPanel(
                          itemsCount: itemsCount.toStringAsFixed(2),
                          total: currency.format(
                            viewState.totalAfterDiscountWithDelivery,
                          ),
                          paid: currency.format(viewState.paid),
                          remaining: currency.format(viewState.remaining),
                          balance: currency.format(balanceValue),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    ElevatedButton(
                      onPressed: () => widget.callbacks.onFinish(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2E4A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'إنهاء المبيعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.rtl,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF556B8D),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.itemsCount,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.balance,
    this.width = 220,
  });

  final String itemsCount;
  final String total;
  final String paid;
  final String remaining;
  final String balance;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCell(label: 'مجموع العناصر:', value: itemsCount),
          _SummaryCell(label: 'الإجمالي:', value: '$total ريال'),
          _SummaryCell(label: 'المدفوع:', value: '$paid ريال'),
          _SummaryCell(label: 'الباقي:', value: '$remaining ريال'),
          _SummaryCell(label: 'الرصيد:', value: '$balance ريال', isLast: true),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        if (!isLast) ...[
          const SizedBox(height: 12),
          const Divider(color: Colors.white38, height: 1),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CustomTextField extends StatelessWidget {
  const _CustomTextField({
    this.controller,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
    this.height,
    this.minHeight,
    this.contentPadding,
    this.iconBoxSize = 36,
    this.iconSize = 18,
    this.borderRadius = 4,
  });
  final TextEditingController? controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;
  final double? height;
  final double? minHeight;
  final EdgeInsets? contentPadding;
  final double iconBoxSize;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            if (icon != null)
              Container(
                width: iconBoxSize,
                height: height ?? iconBoxSize,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFDDDDDD))),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: const Color(0xFF556B8D),
                ),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                maxLines: maxLines,
                textAlign: TextAlign.right,
                textDirection: ui.TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  contentPadding: effectivePadding,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentLinesTable extends ConsumerWidget {
  const _PaymentLinesTable({
    required this.lines,
    required this.onRemove,
    required this.currency,
  });
  final List<PaymentLine> lines;
  final void Function(int) onRemove;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final labelMap = ref.watch(currentPaymentMethodLabelMapProvider);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.all(10),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'طريقة الدفع',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'المبلغ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          ...lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      labelMap[PaymentMethods.normalizeCode(line.methodCode)] ??
                          PaymentMethods.labelForCode(line.methodCode),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('${currency.format(line.amount)} ريال'),
                  ),
                  IconButton(
                    onPressed: () => onRemove(idx),
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
