import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class PosHeader extends StatelessWidget {
  const PosHeader({
    super.key,
    required this.onSeed,
    required this.onClear,
    required this.onLogout,
  });

  final VoidCallback? onSeed;
  final VoidCallback? onClear;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutralGrey.withOpacity(0.7)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'نقطة البيع',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          const _ClockText(),
          const Spacer(),
          _HeaderButton(
            label: 'إضافة منتجات',
            color: AppColors.primaryBlue,
            onPressed: onSeed,
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            label: 'مسح',
            color: AppColors.dangerRed,
            onPressed: onClear,
          ),
          const SizedBox(width: 8),
          _HeaderOutlineButton(
            label: 'خروج',
            color: AppColors.dangerRed,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonTextStyle.copyWith(color: onPrimary),
        ),
      ),
    );
  }
}

class _HeaderOutlineButton extends StatelessWidget {
  const _HeaderOutlineButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonTextStyle.copyWith(color: color),
        ),
      ),
    );
  }
}

class _ClockText extends StatefulWidget {
  const _ClockText();

  @override
  State<_ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<_ClockText> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('a hh:mm:ss dd-MM-yyyy').format(_now);
    return Text(
      formatted,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
