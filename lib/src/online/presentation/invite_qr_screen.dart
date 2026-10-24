import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_repository.dart';
import '../domain/qr_destination.dart';
import 'qr_screen.dart';
import 'widgets/online_widgets.dart';

class InviteQrScreen extends StatefulWidget {
  const InviteQrScreen({
    super.key,
    required this.repository,
    required this.businessId,
  });

  final OnlineRepository repository;
  final String businessId;

  @override
  State<InviteQrScreen> createState() => _InviteQrScreenState();
}

class _InviteQrScreenState extends State<InviteQrScreen> {
  late Future<String> _invite = widget.repository.businessInvite(
    widget.businessId,
  );

  void _reload() => setState(() {
    _invite = widget.repository.businessInvite(widget.businessId);
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OnlinePage(
      title: 'Joining & QR',
      children: [
        Text(
          'Share the joining code or QR so staff can request to join. Customers can scan the salon QR.',
          style: text.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        RemoteContent(
          future: _invite,
          onRetry: _reload,
          builder: (code) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Salon joining code', style: text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      code,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy joining code',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        showMessage(context, 'Code copied');
                      }
                    },
                    icon: const Icon(Icons.copy, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PublicQr(
                destination: QrDestination('join', code),
                label: 'Employee invitation',
              ),
              const SizedBox(height: AppSpacing.xl),
              PublicQr(
                destination: QrDestination('salon', widget.businessId),
                label: 'Customer salon',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
