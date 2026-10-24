import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

/// Signed-out landing for business / customer flavors.
class OnlineLoginPage extends StatelessWidget {
  const OnlineLoginPage({
    super.key,
    required this.audience,
    this.repository,
    this.startupError,
    this.sessionError,
  });

  final AppAudience audience;
  final OnlineRepository? repository;
  final String? startupError;
  final String? sessionError;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface,
              Color(0xFFFFFBEA),
              Color(0xFFF7F2C8),
              AppColors.primary,
            ],
            stops: [0.0, 0.45, 0.78, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/trimmatrix_logo.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'TrimMatrix',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (repository != null)
                      _GoogleSignInButton(
                        onPressed: repository!.signInWithGoogle,
                      )
                    else
                      Text(
                        startupError ?? 'Online setup is not connected yet.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (sessionError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        sessionError!,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } on OnlineFailure catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not sign in with Google. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _run,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              SvgPicture.asset(
                'assets/google_g.svg',
                width: 22,
                height: 22,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _busy ? 'Please wait…' : 'Continue with Google',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
