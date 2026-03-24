import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../pos_models.dart';
import 'pos_select.dart';

class DeliveryDialog extends StatefulWidget {
  const DeliveryDialog({super.key, required this.initial});

  final DeliveryInput initial;

  @override
  State<DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<DeliveryDialog> {
  late DeliveryStatus _status;
  late TextEditingController _detailsController;
  late TextEditingController _addressController;
  late TextEditingController _feeController;
  late TextEditingController _assigneeController;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _detailsController = TextEditingController(text: widget.initial.details);
    _addressController = TextEditingController(text: widget.initial.address);
    _feeController = TextEditingController(
      text: widget.initial.fee == 0 ? '0' : widget.initial.fee.toStringAsFixed(2),
    );
    _assigneeController = TextEditingController(text: widget.initial.assignee);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _addressController.dispose();
    _feeController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  double _parseFee(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0.0;
    return double.tryParse(sanitized) ?? 0.0;
  }

  void _submit() {
    final fee = _parseFee(_feeController.text);
    Navigator.of(context).pop(
      DeliveryInput(
        status: _status,
        fee: fee < 0 ? 0.0 : fee,
        address: _addressController.text.trim(),
        details: _detailsController.text.trim(),
        assignee: _assigneeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fieldHeight = 34.0;
    const fieldRadius = 4.0;
    const formGap = 12.0;
    const columnGap = 16.0;
    const bigFieldHeight = 90.0;

    final options = DeliveryStatus.values
        .map((status) => PosSelectOption<DeliveryStatus>(value: status, label: status.label))
        .toList();

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
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
                        'التوصيل',
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
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'تفاصيل التوصيل:*'),
                              const SizedBox(height: 6),
                              _TextArea(
                                controller: _detailsController,
                                height: bigFieldHeight,
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
                              const _Label(text: 'عنوان التوصيل:'),
                              const SizedBox(height: 6),
                              _TextArea(
                                controller: _addressController,
                                height: bigFieldHeight,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'حالة التوصيل:'),
                              const SizedBox(height: 6),
                              PosSelect<DeliveryStatus>(
                                options: options,
                                value: _status,
                                hintText: 'يرجى الاختيار',
                                height: fieldHeight,
                                borderRadius: fieldRadius,
                                leadingIcon: AppIcons.info,
                                leadingIconColor: AppColors.borderBlue,
                                leadingIconBoxed: true,
                                leadingIconBoxSize: 26,
                                leadingIconSize: 14,
                                enableSearch: false,
                                dropdownItemExtent: fieldHeight,
                                maxDropdownHeight: fieldHeight * options.length,
                                onChanged: (val) {
                                  if (val != null) setState(() => _status = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'تكلفة التوصيل:*'),
                              const SizedBox(height: 6),
                              _InfoTextField(
                                controller: _feeController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                height: fieldHeight,
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
                        const Expanded(child: SizedBox()),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const _Label(text: 'سلمت لـ:'),
                              const SizedBox(height: 6),
                              _TextInput(
                                controller: _assigneeController,
                                height: fieldHeight,
                                borderRadius: fieldRadius,
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

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.controller,
    required this.height,
    required this.borderRadius,
  });

  final TextEditingController controller;
  final double height;
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
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.height,
    required this.borderRadius,
  });

  final TextEditingController controller;
  final double height;
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
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
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

