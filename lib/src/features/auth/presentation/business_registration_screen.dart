import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:provider/provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F6F6);
  static const surfaceHigh = Color(0xFFECECEC);
  static const lime = Color(0xFFD4FF33);
  static const limeDeep = Color(0xFFB8E000);
  static const textPrimary = Color(0xFF0D0D0D);
  static const textSecondary = Color(0xFF6E6E6E);
  static const textHint = Color(0xFF9A9A9A);
  static const divider = Color(0xFFE1E1E1);
  static const error = Color(0xFFFF5C5C);
}
// ──────────────────────────────────────────────────────────────────────────────

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState extends State<BusinessRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String _businessName = '';
  String _phoneNumber = '';
  late final TextEditingController _phoneController;
  bool _isPhoneLocked = false;
  String _address = '';
  String? _businessType;
  String? _city;
  String _area = '';

  final List<String> _businessTypes = const ['Hair Salon'];
  final List<String> _cities = const ['Islamabad'];

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '+92 ');
    _phoneNumber = _phoneController.text.trim();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userPhone = context.read<AuthStore>().currentUser?.phone.trim();
    if (userPhone == null || userPhone.isEmpty) return;
    if (_isPhoneLocked) return;
    _isPhoneLocked = true;
    _phoneController.text = userPhone;
    _phoneNumber = userPhone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Shared decoration ────────────────────────────────────────────────────
  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    final radius = BorderRadius.all(Radius.circular(14.r));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _C.textHint,
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: false,
      filled: true,
      fillColor: _C.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _C.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _C.lime, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _C.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _C.error, width: 1.5),
      ),
      errorStyle: TextStyle(color: _C.error, fontSize: 11.5.sp),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      text,
      style: TextStyle(
        color: _C.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _buildField(Widget child) => Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: child,
  );

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: _C.lime,
          onPrimary: _C.textPrimary,
          surface: _C.surface,
          onSurface: _C.textPrimary,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _C.surface,
        ),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: WillPopScope(
          onWillPop: _onWillPop,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 40.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──────────────────────────────────────────
                        SizedBox(height: 12.h),
                        _buildHeader(),
                        SizedBox(height: 36.h),

                        // ── Business Name ────────────────────────────────────
                        _buildLabel('BUSINESS NAME'),
                        _buildField(
                          TextFormField(
                            style: TextStyle(
                              color: _C.textPrimary,
                              fontSize: 14.sp,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'e.g. Glamour Studio',
                              prefix: Icon(
                                Icons.storefront_rounded,
                                color: _C.textSecondary,
                                size: 20.r,
                              ),
                            ),
                            onChanged: (v) => _businessName = v.trim(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter business name.'
                                : null,
                          ),
                        ),

                        // ── Phone ────────────────────────────────────────────
                        _buildLabel('PHONE NUMBER'),
                        _buildField(
                          TextFormField(
                            controller: _phoneController,
                            enabled: !_isPhoneLocked,
                            style: TextStyle(
                              color: _C.textPrimary,
                              fontSize: 14.sp,
                            ),
                            decoration: _fieldDecoration(
                              hint: '+92 3xx xxx xxxx',
                              prefix: Icon(
                                Icons.phone_rounded,
                                color: _C.textSecondary,
                                size: 20.r,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => _phoneNumber = v.trim(),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty || val == '+92') {
                                return 'Please enter phone number.';
                              }
                              if (!val.startsWith('+92')) {
                                return 'Phone number must start with +92.';
                              }
                              return null;
                            },
                          ),
                        ),

                        // ── Business Type ─────────────────────────────────────
                        _buildLabel('BUSINESS TYPE'),
                        _buildField(
                          _buildDropdown<String>(
                            value: _businessType,
                            hint: 'Select Business Type',
                            items: _businessTypes,
                            icon: Icons.category_rounded,
                            onChanged: (v) => setState(() => _businessType = v),
                          ),
                        ),

                        // ── City ──────────────────────────────────────────────
                        _buildLabel('CITY'),
                        _buildField(
                          _buildDropdown<String>(
                            value: _city,
                            hint: 'Select City',
                            items: _cities,
                            icon: Icons.location_city_rounded,
                            onChanged: (v) => setState(() => _city = v),
                          ),
                        ),

                        // ── Area ──────────────────────────────────────────────
                        _buildLabel('AREA'),
                        _buildField(
                          TextFormField(
                            style: TextStyle(
                              color: _C.textPrimary,
                              fontSize: 14.sp,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'e.g. F-7, Blue Area',
                              prefix: Icon(
                                Icons.map_rounded,
                                color: _C.textSecondary,
                                size: 20.r,
                              ),
                            ),
                            onChanged: (v) => _area = v.trim(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter area.'
                                : null,
                          ),
                        ),

                        // ── Address (optional) ────────────────────────────────
                        _buildLabel('ADDRESS  •  OPTIONAL'),
                        _buildField(
                          TextFormField(
                            style: TextStyle(
                              color: _C.textPrimary,
                              fontSize: 14.sp,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Street / building details',
                              prefix: Icon(
                                Icons.pin_drop_rounded,
                                color: _C.textSecondary,
                                size: 20.r,
                              ),
                            ),
                            onChanged: (v) => _address = v.trim(),
                          ),
                        ),

                        SizedBox(height: 28.h),

                        // ── Register Button ───────────────────────────────────
                        _buildRegisterButton(),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Lime accent tag
        Text(
          'Business\nRegistration',
          style: TextStyle(
            color: _C.textPrimary,
            fontSize: 32.sp,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10.h),
        Text(
          'Set up your profile to start managing appointments & services.',
          style: TextStyle(
            color: _C.textSecondary,
            fontSize: 13.5.sp,
            height: 1.55,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20.h),
        Container(height: 1.h, color: _C.divider),
      ],
    );
  }

  // ─── Dropdown ─────────────────────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<String> items,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      dropdownColor: _C.surfaceHigh,
      iconEnabledColor: _C.textSecondary,
      icon: Icon(CupertinoIcons.chevron_down, size: 16.r),
      style: TextStyle(
        fontFamily: 'Roboto',
        color: _C.textPrimary,
        fontSize: 14.sp,
      ),
      decoration: _fieldDecoration(
        hint: '',
        prefix: Icon(icon, color: _C.textSecondary, size: 20.r),
      ),
      hint: Text(
        hint,
        style: TextStyle(color: _C.textHint, fontSize: 14.sp),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e as T,
              child: Text(
                e,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _C.textPrimary),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  // ─── Register button ──────────────────────────────────────────────────────
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: Colors.black,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? _C.limeDeep.withValues(alpha: 0.5)
                    : null,
              ),
            ),
        onPressed: _handleRegister,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Register Business',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 8.w),
          ],
        ),
      ),
    );
  }

  // ─── Logic (unchanged) ────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    final businessName = _businessName;
    final phoneNumber = _phoneNumber;
    if (businessName.isEmpty || phoneNumber.isEmpty) return;

    if (_businessType == null || _city == null || _area.trim().isEmpty) return;

    final profile = BusinessProfile(
      businessName: _businessName,
      phoneNumber: _phoneNumber,
      businessType: _businessType ?? '',
      city: _city ?? '',
      area: _area,
      address: _address.isEmpty ? '$_area, ${_city ?? ''}' : _address,
    );
    final auth = context.read<AuthStore>();
    await context.read<BusinessProfileNotifier>().save(profile);
    await auth.loadCurrentUser();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.homeShell, (r) => false);
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: const Text(
          'Exit App',
          style: TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to exit the app?',
          style: TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _C.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: _C.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
    return false;
  }
}
