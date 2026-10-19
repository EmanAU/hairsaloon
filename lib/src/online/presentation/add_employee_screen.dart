import 'package:flutter/material.dart';
import '../../core/services/toast_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({
    super.key,
    required this.repository,
    required this.businessId,
  });

  final OnlineRepository repository;
  final String businessId;

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _code = TextEditingController();
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _code.text.trim();
    if (!_uuid.hasMatch(value)) {
      throw const OnlineFailure('Paste a valid profile code');
    }
    await widget.repository.inviteEmployee(widget.businessId, value);
    if (!mounted) return;
    ToastService.success('Employee added to your salon', context);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OnlinePage(
      title: 'Add employee',
      children: [
        Text(
          'Paste their TrimMatrix profile code to invite them to this salon.',
          style: text.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _code,
          decoration: InputDecoration(
            labelText: 'Employee profile code',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ActionButton(
            label: 'Add employee',
            icon: Icons.person_add_outlined,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
