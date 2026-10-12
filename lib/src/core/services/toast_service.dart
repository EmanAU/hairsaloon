import 'package:flutter/material.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class ToastService {
  ToastService._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(String message) =>
      _show(message, AppColors.success, Icons.check_circle_outline_rounded);
  static void error(String message) =>
      _show(message, AppColors.danger, Icons.error_outline_rounded);
  static void info(String message) =>
      _show(message, AppColors.primary, Icons.info_outline_rounded);

  static void _show(String message, Color accent, IconData icon) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    final theme = Theme.of(messenger.context);
    final colors = theme.colorScheme;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surface,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 21,
                color: accent == AppColors.primary ? colors.onSurface : accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Dismiss notification',
              onPressed: messenger.hideCurrentSnackBar,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
