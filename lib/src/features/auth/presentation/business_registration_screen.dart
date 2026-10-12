import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+92 ');
  final _city = TextEditingController(text: 'Islamabad');
  final _area = TextEditingController();
  final _address = TextEditingController();
  String _businessType = 'Hair Salon';
  String? _logo;
  bool _initialized = false;
  bool _phoneLocked = false;
  bool _saving = false;
  bool _exitDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = context.read<BusinessProfileNotifier>().profile;
    if (profile != null) {
      _name.text = profile.businessName;
      _city.text = profile.city;
      _area.text = profile.area;
      _address.text = profile.address;
      _logo = profile.logoBase64;
    }
    final phone = context.read<AuthStore>().currentUser?.phone;
    _phoneLocked = phone != null && phone.isNotEmpty;
    _phone.text = _phoneLocked ? phone! : profile?.phoneNumber ?? '+92 ';
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _city, _area, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String hint, {IconData? icon}) {
    const radius = BorderRadius.all(Radius.circular(9));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: icon == null
          ? null
          : Icon(icon, size: 17, color: AppColors.textSecondary),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0xFFE1E1E1)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool required = true,
    TextInputType? keyboard,
    bool readOnly = false,
    int lines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          enabled: !_saving,
          maxLines: lines,
          keyboardType: keyboard,
          textInputAction: lines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: _decoration(
            hint,
            icon: readOnly ? Icons.lock_outline_rounded : null,
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (required && text.isEmpty) return 'Required';
            if (controller == _phone &&
                !RegExp(
                  r'^\+92\d{10}$',
                ).hasMatch(text.replaceAll(RegExp(r'[\s()-]'), ''))) {
              return 'Enter a valid +92 phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop() && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set up your business',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A few details to make this space yours.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  BusinessLogoPicker(
                    value: _logo,
                    recoverLostImage: true,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _logo = value),
                  ),
                  const SizedBox(height: 20),
                  _field('Business name', _name, 'e.g. Glamour Studio'),
                  const SizedBox(height: 14),
                  _field(
                    'Phone number',
                    _phone,
                    '+92 3xx xxx xxxx',
                    keyboard: TextInputType.phone,
                    readOnly: _phoneLocked,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Business type'),
                            DropdownButtonFormField<String>(
                              initialValue: _businessType,
                              isExpanded: true,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                              ),
                              decoration: _decoration('Select type'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Hair Salon',
                                  child: Text('Hair Salon'),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(
                                      () =>
                                          _businessType = value ?? 'Hair Salon',
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field('City', _city, 'Your city')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field('Area', _area, 'e.g. G-11 Markaz'),
                  const SizedBox(height: 14),
                  _field(
                    'Address (optional)',
                    _address,
                    'Street or building details',
                    required: false,
                    lines: 2,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Save & continue',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final notifier = context.read<BusinessProfileNotifier>();
    setState(() => _saving = true);
    try {
      await notifier.save(
        BusinessProfile(
          businessName: _name.text.trim(),
          phoneNumber: _phone.text.replaceAll(RegExp(r'[\s()-]'), ''),
          businessType: _businessType,
          city: _city.text.trim(),
          area: _area.text.trim(),
          address: _address.text.trim().isEmpty
              ? '${_area.text.trim()}, ${_city.text.trim()}'
              : _address.text.trim(),
          logoBase64: _logo,
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.homeShell, (route) => false);
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not save your business. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Your business setup has not been saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (exit == true && mounted) await SystemNavigator.pop();
  }
}
