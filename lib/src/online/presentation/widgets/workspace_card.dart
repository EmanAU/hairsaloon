import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.leading,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final interactive = enabled && onTap != null;
    return Opacity(
      opacity: interactive ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.homeBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: interactive ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading ??
                        Icon(icon, size: 30, color: AppColors.homeInk),
                    const Spacer(),
                    Icon(
                      interactive
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_outline,
                      size: 20,
                      color: AppColors.iconMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceCards extends StatelessWidget {
  const WorkspaceCards({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final width = size.maxWidth >= 600
          ? (size.maxWidth - AppSpacing.md) / 2
          : size.maxWidth;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}
