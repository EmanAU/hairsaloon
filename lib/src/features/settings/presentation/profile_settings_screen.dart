import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isEditing = false;
  String? _logo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<BusinessProfileNotifier>().profile;
    if (profile == null || _nameCtrl.text.isNotEmpty) return;
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
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (_isEditing) _logo = profile?.logoBase64;
              _isEditing = !_isEditing;
            }),
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: Text('No business profile found.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      BusinessLogoPicker(
                        value: _logo,
                        enabled: _isEditing,
                        onChanged: (value) => setState(() => _logo = value),
                      ),
                      const SizedBox(height: 16),
                      _field(_nameCtrl, 'Business Name'),
                      const SizedBox(height: 8),
                      _field(_phoneCtrl, 'Phone Number'),
                      const SizedBox(height: 8),
                      _field(_typeCtrl, 'Business Type'),
                      const SizedBox(height: 8),
                      _field(_cityCtrl, 'City'),
                      const SizedBox(height: 8),
                      _field(_areaCtrl, 'Area'),
                      const SizedBox(height: 8),
                      _field(_addressCtrl, 'Address', maxLines: 3),
                    ],
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _save,
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required' : null,
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
    await context.read<BusinessProfileNotifier>().save(updated);
    if (!mounted) return;
    setState(() => _isEditing = false);
  }
}
