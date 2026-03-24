import 'dart:ui' as ui;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';

class CustomerAddDialog extends ConsumerStatefulWidget {
  const CustomerAddDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CustomerAddDialog(),
    );
  }

  @override
  ConsumerState<CustomerAddDialog> createState() => _CustomerAddDialogState();
}

class _CustomerAddDialogState extends ConsumerState<CustomerAddDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _activityController;
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _mobileAltController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _activityController = TextEditingController();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _mobileAltController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _activityController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _mobileAltController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    if (name.isEmpty || mobile.isEmpty) {
      AppFeedback.warning(context, 'الاسم والموبايل مطلوبان');
      return;
    }

    final db = ref.read(appDbProvider);
    await db.insertCustomer(
      CustomersCompanion.insert(
        name: name,
        mobile: mobile,
        code: _nullableText(_codeController.text),
        activity: _nullableText(_activityController.text),
        mobileAlt: _nullableText(_mobileAltController.text),
        phone: _nullableText(_phoneController.text),
        email: _nullableText(_emailController.text),
      ),
    );

    AppFeedback.success(context, 'تم حفظ العميل بنجاح');
    if (mounted) Navigator.of(context).pop();
  }

  drift.Value<String?> _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const drift.Value.absent() : drift.Value(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    const fieldHeight = 34.0;
    const fieldRadius = 4.0;
    const columnGap = 16.0;
    const rowGap = 12.0;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
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
                        'إضافة جهة اتصال',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
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
                          child: _LabeledField(
                            label: 'كود العميل:',
                            controller: _codeController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        const Expanded(child: SizedBox()),
                        const SizedBox(width: columnGap),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: rowGap),
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'النشاط:',
                            controller: _activityController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.work_outline,
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: _LabeledField(
                            label: 'الاسم:*',
                            controller: _nameController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: AppIcons.user,
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: _LabeledField(
                            label: 'الموبايل:*',
                            controller: _mobileController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: rowGap),
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'الموبايل البديل:',
                            controller: _mobileAltController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: _LabeledField(
                            label: 'الهاتف:',
                            controller: _phoneController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.call,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: columnGap),
                        Expanded(
                          child: _LabeledField(
                            label: 'البريد الإلكتروني:',
                            controller: _emailController,
                            height: fieldHeight,
                            borderRadius: fieldRadius,
                            icon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
                        label: const Text('مزيد من المعلومات', style: AppTextStyles.buttonTextStyle),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('إغلاق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.height,
    required this.borderRadius,
    required this.icon,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final double height;
  final double borderRadius;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.rtl,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF556B8D)),
        ),
        const SizedBox(height: 6),
        Container(
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
                child: Icon(icon, size: 16, color: AppColors.borderBlue),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textAlign: TextAlign.right,
                  textDirection: ui.TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: label.replaceAll(':', '').replaceAll('*', '').trim(),
                    hintStyle: AppTextStyles.fieldHint.copyWith(fontSize: 11, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  style: AppTextStyles.fieldText.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
