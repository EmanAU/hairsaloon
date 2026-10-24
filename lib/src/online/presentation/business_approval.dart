import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class BusinessApproval extends StatefulWidget {
  const BusinessApproval({
    super.key,
    required this.business,
    required this.repository,
    required this.onRefresh,
    required this.onEdit,
  });
  final SalonBusiness business;
  final OnlineRepository repository;
  final VoidCallback onRefresh;
  final Future<void> Function() onEdit;
  @override
  State<BusinessApproval> createState() => _BusinessApprovalState();
}

class _BusinessApprovalState extends State<BusinessApproval> {
  late final Future<String> _code = widget.repository.businessInvite(
    widget.business.id,
  );
  late final Timer _check;
  @override
  void initState() {
    super.initState();
    // Keep checking until the owner leaves this screen or approval lands.
    _check = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) widget.onRefresh();
    });
  }

  @override
  void dispose() {
    _check.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 40),
      const Icon(
        Icons.hourglass_top_rounded,
        size: 56,
        color: AppColors.textSecondary,
      ),
      const SizedBox(height: 24),
      const Text(
        'Waiting for approval',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        widget.business.name,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your business will open after admin approval.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, height: 1.5),
      ),
      const SizedBox(height: 28),
      FutureBuilder<String>(
        future: _code,
        builder: (context, snapshot) => snapshot.data == null
            ? Text(
                snapshot.hasError
                    ? 'Business code could not load. Check approval to retry.'
                    : 'Loading business code…',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            : ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Business code',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                subtitle: SelectableText(
                  snapshot.data!,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  tooltip: 'Copy business code',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: snapshot.data!),
                    );
                    if (context.mounted) {
                      showMessage(context, 'Business code copied');
                    }
                  },
                ),
              ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Check approval'),
        ),
      ),
      const SizedBox(height: 8),
      ActionButton(
        label: 'Edit business details',
        icon: Icons.edit_outlined,
        onPressed: widget.onEdit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.homeInk,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ],
  );
}
