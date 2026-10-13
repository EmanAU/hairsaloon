import 'package:flutter/material.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

bool _isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

/// Opens [builder] as a bottom sheet on phones and a centered dialog on
/// tablets. Use [AppSheetBody] inside for consistent layout.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  if (_isTablet(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) => _CenteredSheet(child: builder(dialogContext)),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(top: false, child: builder(sheetContext)),
    ),
  );
}

class _CenteredSheet extends StatelessWidget {
  const _CenteredSheet({required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: const Color(0x00000000),
        insetPadding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 300),
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Title, optional icon badge, content and full-width action buttons.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.child,
    this.confirmLabel,
    this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.onCancel,
    this.destructive = false,
    this.showCancel = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? child;
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final bool destructive;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    final accent =
        iconColor ?? (destructive ? AppColors.danger : AppColors.textPrimary);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 16), child!],
          if (confirmLabel != null || showCancel) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (showCancel)
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          onCancel ?? () => Navigator.of(context).maybePop(),
                      style: appSecondaryButtonStyle(),
                      child: Text(cancelLabel),
                    ),
                  ),
                if (showCancel && confirmLabel != null)
                  const SizedBox(width: 10),
                if (confirmLabel != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: appPrimaryButtonStyle(destructive: destructive),
                      child: Text(confirmLabel!),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle appPrimaryButtonStyle({bool destructive = false}) {
  return FilledButton.styleFrom(
    backgroundColor: destructive ? AppColors.danger : AppColors.textPrimary,
    foregroundColor: AppColors.surface,
    disabledBackgroundColor: const Color(0xFFDADADA),
    disabledForegroundColor: AppColors.textSecondary,
    minimumSize: const Size.fromHeight(44),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

ButtonStyle appSecondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: Color(0xFFDDDDDD)),
    minimumSize: const Size.fromHeight(44),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Compact input decoration for sheet forms.
InputDecoration appSheetInputDecoration(
  String label, {
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: AppColors.background,
    labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
    floatingLabelStyle: const TextStyle(
      fontSize: 12.5,
      color: AppColors.textPrimary,
    ),
    hintStyle: const TextStyle(fontSize: 12.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(const Color(0x00000000)),
    enabledBorder: border(const Color(0x00000000)),
    focusedBorder: border(AppColors.textPrimary, 1.2),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.2),
  );
}

/// Selectable row used for option lists inside sheets (currency, source...).
class AppSheetOption extends StatelessWidget {
  const AppSheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.textPrimary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single text field sheet. Returns the trimmed value, or null on cancel.
/// [validator] returns an error message to keep the sheet open.
Future<String?> showAppTextInputSheet({
  required BuildContext context,
  required String title,
  required String label,
  String? subtitle,
  IconData? icon,
  String initialValue = '',
  String? hint,
  String? prefixText,
  String? suffixText,
  String confirmLabel = 'Save',
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int? maxLength,
  String? Function(String value)? validator,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _TextInputSheet(
      title: title,
      label: label,
      subtitle: subtitle,
      icon: icon,
      initialValue: initialValue,
      hint: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      validator: validator,
    ),
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.initialValue,
    required this.hint,
    required this.prefixText,
    required this.suffixText,
    required this.confirmLabel,
    required this.keyboardType,
    required this.textCapitalization,
    required this.maxLength,
    required this.validator,
  });

  final String title;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final String initialValue;
  final String? hint;
  final String? prefixText;
  final String? suffixText;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? Function(String value)? validator;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      confirmLabel: widget.confirmLabel,
      onConfirm: _submit,
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        decoration: appSheetInputDecoration(
          widget.label,
          hint: widget.hint,
          prefixText: widget.prefixText,
        ).copyWith(
          suffixText: widget.suffixText,
          counterText: '',
          errorText: _error,
        ),
      ),
    );
  }
}

/// Small centered dialog (confirmations). Width 300-400.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) =>
        _CenteredSheet(maxWidth: 400, child: builder(dialogContext)),
  );
}
