import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../pos_models.dart';
import 'pos_select.dart';

class DiscountDialog extends StatefulWidget {
  const DiscountDialog({super.key, required this.initial});

  final DiscountInput initial;

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late DiscountType _type;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _amountController = TextEditingController(
      text: widget.initial.value == 0 ? '0.00' : widget.initial.value.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  void _submit() {
    final amount = _parseAmount(_amountController.text) ?? 0.0;
    final safe = amount < 0 ? 0.0 : amount;
    Navigator.of(context).pop(DiscountInput(type: _type, value: safe));
  }

  @override
  Widget build(BuildContext context) {
    const fieldHeight = 34.0;
    const fieldRadius = 4.0;
    const formGap = 12.0;
    const columnGap = 16.0;

    final options = DiscountType.values
        .map((type) => PosSelectOption<DiscountType>(value: type, label: type.label))
        .toList();
    final dropdownItemExtent = fieldHeight;
    final maxDropdownHeight = dropdownItemExtent * options.length;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    const Expanded(
                      child: Text(
                        'الخصم',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'تعديل الخصم:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF556B8D)),
                      textAlign: TextAlign.right,
                      textDirection: ui.TextDirection.rtl,
                    ),
                    const SizedBox(height: formGap),
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'مبلغ الخصم:*'),
                              const SizedBox(height: 6),
                              _InfoTextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                height: fieldHeight,
                                borderRadius: fieldRadius,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'نوع الخصم:*'),
                              const SizedBox(height: 6),
                              PosSelect<DiscountType>(
                                options: options,
                                value: _type,
                                hintText: 'يرجى الاختيار',
                                height: fieldHeight,
                                borderRadius: fieldRadius,
                                leadingIcon: AppIcons.info,
                                leadingIconColor: AppColors.borderBlue,
                                leadingIconBoxed: true,
                                leadingIconBoxSize: 26,
                                leadingIconSize: 14,
                                enableSearch: false,
                                dropdownItemExtent: dropdownItemExtent,
                                maxDropdownHeight: maxDropdownHeight,
                                onChanged: (val) {
                                  if (val != null) setState(() => _type = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2E4A),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        'تحديث',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF556B8D)),
    );
  }
}

class _InfoTextField extends StatelessWidget {
  const _InfoTextField({
    this.controller,
    this.keyboardType,
    this.height,
    this.borderRadius = 4,
  });

  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            width: height,
            height: height,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFDDDDDD))),
            ),
            child: const Icon(AppIcons.info, size: 16, color: AppColors.borderBlue),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              textDirection: ui.TextDirection.rtl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

