import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/services/toast_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../domain/online_models.dart';

/// Content width for online shells: phone full-bleed, tablet landscape readable.
abstract final class OnlineShell {
  static const double formMaxWidth = 960;
  static const double pageMaxWidth = 1040;
  static const double twoColMinWidth = 560;

  static BoxConstraints contentConstraints(double availableWidth) {
    final tablet = AppBreakpoints.isTabletWidth(availableWidth);
    return BoxConstraints(
      maxWidth: tablet ? pageMaxWidth : formMaxWidth.clamp(0, availableWidth),
    );
  }

  static Widget centered({
    required Widget child,
    double maxWidth = formMaxWidth,
  }) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class OnlinePage extends StatelessWidget {
  const OnlinePage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        title: Text(title, style: text.titleLarge),
        actions: actions,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = AppBreakpoints.isTabletWidth(constraints.maxWidth)
              ? OnlineShell.pageMaxWidth
              : 640.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style,
    this.showIcon = true,
  });
  final String label;
  final Future<void> Function() onPressed;
  final IconData? icon;
  final ButtonStyle? style;
  final bool showIcon;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
    } catch (_) {
      if (mounted) {
        ToastService.error(
          'Could not complete this action. Check your connection and try again.',
          context,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(_busy ? 'Please wait…' : widget.label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: widget.showIcon || _busy
          ? FilledButton.icon(
              style: widget.style,
              onPressed: _busy ? null : _run,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(widget.icon ?? Icons.arrow_forward),
              label: label,
            )
          : FilledButton(
              style: widget.style,
              onPressed: _busy ? null : _run,
              child: label,
            ),
    );
  }
}

/// Routes feedback through [ToastService] (branded floating snackbars).
void showMessage(BuildContext context, String text, {bool error = false}) {
  if (error) {
    ToastService.error(text, context);
  } else {
    ToastService.info(text, context);
  }
}

class CopyCode extends StatelessWidget {
  const CopyCode({super.key, required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(code),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) showMessage(context, 'Code copied');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy code'),
          ),
        ],
      ),
    ),
  );
}

class RemoteContent<T> extends StatelessWidget {
  const RemoteContent({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        final detail = snapshot.error is OnlineFailure
            ? (snapshot.error! as OnlineFailure).message
            : 'Could not load data. Check your connection.';
        return Column(
          children: [
            Text(detail, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        );
      }
      return builder(snapshot.data as T);
    },
  );
}
