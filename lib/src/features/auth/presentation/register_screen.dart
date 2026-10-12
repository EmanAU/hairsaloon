import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class _C {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F6F6);
  static const lime = Color(0xFFD4FF33);
  static const limeDeep = Color(0xFFB8E000);
  static const textPrimary = Color(0xFF0D0D0D);
  static const textSecondary = Color(0xFF6E6E6E);
  static const textHint = Color(0xFF9A9A9A);
  static const divider = Color(0xFFE1E1E1);
  static const error = Color(0xFFFF5C5C);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+92 ');
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    final auth = context.read<AuthStore>();
    await auth.startRegistration(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    if (auth.currentUser != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.businessRegistration,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final error = auth.error;

    InputDecoration fieldDecoration({required String hint, Widget? prefix}) {
      final radius = BorderRadius.all(Radius.circular(14.r));
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _C.textHint,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: prefix,
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

    Widget label(String text) => Padding(
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
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 40.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12.h),
                  Center(
                    child: Text(
                      'User\nRegistration',
                      style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: Text(
                      'Create an account on this device to continue.',
                      style: TextStyle(
                        color: _C.textSecondary,
                        fontSize: 13.5.sp,
                        height: 1.55,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Container(height: 1.h, color: _C.divider),
                  SizedBox(height: 36.h),
                  if (error != null && error.isNotEmpty) ...[
                    _ErrorBanner(message: error, onClose: auth.clearError),
                    SizedBox(height: 16.h),
                  ],
                  label('NAME'),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: _C.textPrimary, fontSize: 14.sp),
                      decoration: fieldDecoration(
                        hint: 'e.g. Ali Khan',
                        prefix: Icon(
                          Icons.person_rounded,
                          color: _C.textSecondary,
                          size: 20.r,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  label('PHONE NUMBER'),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: _C.textPrimary, fontSize: 14.sp),
                      decoration: fieldDecoration(
                        hint: '+92 3xx xxx xxxx',
                        prefix: Icon(
                          Icons.phone_rounded,
                          color: _C.textSecondary,
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
                  ),
                  label('PASSWORD'),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      style: TextStyle(color: _C.textPrimary, fontSize: 14.sp),
                      decoration:
                          fieldDecoration(
                            hint: 'Create a password',
                            prefix: Icon(
                              Icons.lock_rounded,
                              color: _C.textSecondary,
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
                                color: _C.textSecondary,
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
                  ),
                  label('CONFIRM PASSWORD'),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: TextFormField(
                      controller: _confirmCtrl,
                      obscureText: !_showConfirmPassword,
                      style: TextStyle(color: _C.textPrimary, fontSize: 14.sp),
                      decoration:
                          fieldDecoration(
                            hint: 'Re-enter password',
                            prefix: Icon(
                              Icons.lock_outline_rounded,
                              color: _C.textSecondary,
                              size: 20.r,
                            ),
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _showConfirmPassword =
                                    !_showConfirmPassword,
                              ),
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _C.textSecondary,
                                size: 20.r,
                              ),
                            ),
                          ),
                      validator: (v) {
                        final val = (v ?? '').trim();
                        if (val.isEmpty) return 'Required';
                        if (val != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
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
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
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
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
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
