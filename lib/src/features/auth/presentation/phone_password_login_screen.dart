import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class PhonePasswordLoginScreen extends StatefulWidget {
  const PhonePasswordLoginScreen({super.key});

  @override
  State<PhonePasswordLoginScreen> createState() =>
      _PhonePasswordLoginScreenState();
}

class _PhonePasswordLoginScreenState extends State<PhonePasswordLoginScreen> {
  static const double _tabletBreakpoint = 600;
  static const double _maxContentWidth = 420;
  static const Color _divider = Color(0xFFE1E1E1);
  static const Color _hint = Color(0xFF9A9A9A);
  static const Color _limeDeep = Color(0xFFB8E000);

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController(text: '+92 ');
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    final auth = context.read<AuthStore>();
    await auth.login(
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    if (auth.currentUser != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        context.read<BusinessProfileNotifier>().profile == null
            ? AppRoutes.businessRegistration
            : AppRoutes.homeShell,
        (route) => false,
      );
    }
  }

  InputDecoration _fieldDecoration({required String hint, Widget? prefix}) {
    const radius = BorderRadius.all(Radius.circular(9));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _hint,
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefix,
      filled: false,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _divider, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: TextStyle(color: AppColors.danger, fontSize: 11.5.sp),
    );
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final error = auth.error;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= _tabletBreakpoint;
            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? _maxContentWidth : double.infinity,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Welcome back',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Login with your phone and password.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        if (error != null && error.isNotEmpty) ...[
                          _ErrorBanner(message: error, onClose: auth.clearError),
                          SizedBox(height: 16.h),
                        ],
                        _label('Phone number'),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                          ),
                          decoration: _fieldDecoration(
                            hint: '+92 3xx xxx xxxx',
                            prefix: Icon(
                              Icons.phone_rounded,
                              color: AppColors.textSecondary,
                              size: 20.r,
                            ),
                          ),
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty || val == '+92') return 'Required';
                            if (!val.startsWith('+92')) {
                              return 'Must start with +92';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),
                        _label('Password'),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: !_showPassword,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                          ),
                          decoration: _fieldDecoration(
                            hint: 'Enter your password',
                            prefix: Icon(
                              Icons.lock_rounded,
                              color: AppColors.textSecondary,
                              size: 20.r,
                            ),
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: AppColors.textSecondary,
                                size: 20.r,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return 'Required';
                            if (val.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                        SizedBox(height: 24.h),
                        SizedBox(
                          height: 52.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              shadowColor: const Color(0x00000000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ).copyWith(
                              overlayColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.pressed)
                                        ? _limeDeep.withValues(alpha: 0.5)
                                        : null,
                              ),
                            ),
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? SizedBox(
                                    width: 22.r,
                                    height: 22.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New here? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.sp,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.register),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
