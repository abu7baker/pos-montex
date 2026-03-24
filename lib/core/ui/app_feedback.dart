import 'dart:async';

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppFeedback {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void success(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.check_circle, background: AppColors.successGreen);
  }

  static void error(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.error_outline, background: AppColors.dangerRed);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.warning_amber_rounded, background: AppColors.topbarIconOrange);
  }

  static void info(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.info_outline, background: AppColors.topbarIconBlue);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
  }) {
    _timer?.cancel();
    _entry?.remove();

    final overlay = Overlay.of(context);

    final direction = Directionality.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        final media = MediaQuery.of(context);
        return Positioned(
          top: media.padding.top + 12,
          right: 16,
          child: Directionality(
            textDirection: direction,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: media.size.width * 0.5),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: AppColors.white, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2500), _removeCurrent);
  }

  static void _removeCurrent() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
