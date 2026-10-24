import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_colors.dart';
import '../domain/online_repository.dart';
import '../domain/qr_destination.dart';
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

enum _QrKind { employee, customer }

class _InviteQrScreenState extends State<InviteQrScreen> {
  _QrKind? _selected;
  Future<String>? _invite;

  void _select(_QrKind kind) {
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    setState(() {
      _selected = kind;
      if (kind == _QrKind.employee) {
        _invite ??= widget.repository.businessInvite(widget.businessId);
      }
    });
  }

  void _showChoices() {
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    setState(() => _selected = null);
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selected != null) _showChoices();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(CupertinoIcons.back),
            onPressed: () {
              if (_selected != null) {
                _showChoices();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: Text(
            'Joining & QR',
            style: text.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  if (_selected == null) ...[
                    Text(
                      'Choose a QR code',
                      style: text.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One for your team. One for your customers.',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _choice(
                      kind: _QrKind.employee,
                      title: 'Employee invitation',
                      subtitle: 'Joining code & QR for your team',
                      icon: CupertinoIcons.person_2,
                      tint: const Color(0xFFF2F8DA),
                    ),
                    const SizedBox(height: 14),
                    _choice(
                      kind: _QrKind.customer,
                      title: 'Customer salon QR',
                      subtitle: 'Your salon, services & reviews',
                      icon: CupertinoIcons.qrcode,
                      tint: const Color(0xFFF0F4FC),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _showChoices,
                        icon: const Icon(
                          CupertinoIcons.square_grid_2x2,
                          size: 16,
                        ),
                        label: const Text('Change QR type'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.homeOlive,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selected == _QrKind.employee)
                      RemoteContent(
                        future: _invite!,
                        onRetry: () => setState(() {
                          _invite = widget.repository.businessInvite(
                            widget.businessId,
                          );
                        }),
                        builder: (code) => _details(employee: true, id: code),
                      )
                    else
                      _details(employee: false, id: widget.businessId),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required _QrKind kind,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _select(kind),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 24, color: AppColors.homeOlive),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.homeInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.homeOlive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details({required bool employee, required String id}) {
    final destination = QrDestination(employee ? 'join' : 'salon', id);
    final title = employee ? 'Employee invitation' : 'Customer salon QR';
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: text.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          employee
              ? 'Ask staff to scan this QR in Join a salon, or enter the joining code below.'
              : 'Customers scan this QR to open your salon, browse services and write a review.',
          style: text.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: employee ? const Color(0xFFF7FAED) : const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(
                employee
                    ? CupertinoIcons.person_2
                    : CupertinoIcons.building_2_fill,
                size: 23,
                color: AppColors.homeOlive,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Semantics(
                  label: title,
                  image: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) => QrImageView(
                      data: destination.value,
                      size: constraints.maxWidth.clamp(0, 220),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                employee ? 'For your team' : 'For your customers',
                style: text.bodySmall?.copyWith(
                  color: AppColors.homeOlive,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (employee) ...[
          const SizedBox(height: 24),
          Text(
            'Salon joining code',
            style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    id,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy joining code',
                  onPressed: () => _copy(id, 'Joining code copied'),
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Joining requests appear in Join Requests for your approval.',
            style: text.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _copy(destination.value, 'QR link copied'),
          icon: const Icon(CupertinoIcons.link, size: 18),
          label: Text(employee ? 'Copy invitation link' : 'Copy salon link'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.homeInk,
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
