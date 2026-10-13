import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const Color _divider = Color(0xFFE1E1E1);
  static const Color _hint = Color(0xFF9A9A9A);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isEditing = false;
  bool _hydrated = false;
  String? _logo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<BusinessProfileNotifier>().profile;
    if (profile == null || _hydrated) return;
    _hydrated = true;
    _applyProfile(profile);
  }

  void _applyProfile(BusinessProfile profile) {
    _logo = profile.logoBase64;
    _nameCtrl.text = profile.businessName;
    _phoneCtrl.text = profile.phoneNumber;
    _typeCtrl.text = profile.businessType;
    _cityCtrl.text = profile.city;
    _areaCtrl.text = profile.area;
    _addressCtrl.text = profile.address;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _typeCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<BusinessProfileNotifier>().profile;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: profile == null
                ? null
                : () => setState(() {
                      if (_isEditing) {
                        _applyProfile(profile);
                      }
                      _isEditing = !_isEditing;
                    }),
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: profile == null
          ? const Center(
              child: Text(
                'No business profile found.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                BusinessLogoPicker(
                  value: _logo,
                  enabled: _isEditing,
                  onChanged: (value) => setState(() => _logo = value),
                ),
                const SizedBox(height: 22),
                if (_isEditing)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _editField(_nameCtrl, 'Business name'),
                        const SizedBox(height: 12),
                        _editField(
                          _phoneCtrl,
                          'Phone number',
                          keyboard: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _editField(_typeCtrl, 'Business type'),
                        const SizedBox(height: 12),
                        _editField(_cityCtrl, 'City'),
                        const SizedBox(height: 12),
                        _editField(_areaCtrl, 'Area'),
                        const SizedBox(height: 12),
                        _editField(_addressCtrl, 'Address', maxLines: 3),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            onPressed: _save,
                            child: const Text(
                              'Save Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      _viewRow('Business name', _nameCtrl.text),
                      _viewRow('Phone number', _phoneCtrl.text),
                      _viewRow('Business type', _typeCtrl.text),
                      _viewRow('City', _cityCtrl.text),
                      _viewRow('Area', _areaCtrl.text),
                      _viewRow('Address', _addressCtrl.text, isLast: true),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _viewRow(String label, String value, {bool isLast = false}) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    const radius = BorderRadius.all(Radius.circular(9));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.danger, width: 1.5),
            ),
            errorStyle: TextStyle(fontSize: 11),
            hintStyle: TextStyle(color: _hint, fontSize: 13),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;
    final updated = BusinessProfile(
      businessName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      businessType: _typeCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      logoBase64: _logo,
    );
    try {
      await context.read<BusinessProfileNotifier>().save(updated);
      if (!mounted) return;
      setState(() => _isEditing = false);
      ToastService.success('Profile saved');
    } catch (_) {
      if (!mounted) return;
      ToastService.error('Could not save profile. Please try again.');
    }
  }
}
