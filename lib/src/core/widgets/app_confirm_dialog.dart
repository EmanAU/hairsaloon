import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';

/// Compact confirmation dialog (300-400 wide) in the shared sheet style.
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
  IconData? icon,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AppSheetBody(
      title: title,
      subtitle: message,
      icon:
          icon ??
          (isDestructive
              ? Icons.delete_outline_rounded
              : Icons.help_outline_rounded),
      destructive: isDestructive,
      cancelLabel: cancelLabel,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      confirmLabel: confirmLabel,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}
