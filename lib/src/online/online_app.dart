import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../core/services/toast_service.dart';
import 'domain/qr_destination.dart';
import '../app.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'domain/online_models.dart';
import 'domain/online_repository.dart';
import 'presentation/business_home.dart';
import 'presentation/employee_home.dart';
import 'presentation/online_login_page.dart';
import 'presentation/profile_form.dart';
import 'presentation/customer_screens.dart';
import 'presentation/online_session.dart';
import 'presentation/widgets/online_widgets.dart';

class OnlineApp extends StatefulWidget {
  const OnlineApp({
    super.key,
    required this.audience,
    this.repository,
    this.startupError,
    this.enableDeepLinks = false,
  });
  final AppAudience audience;
  final OnlineRepository? repository;
  final String? startupError;
  final bool enableDeepLinks;

  @override
  State<OnlineApp> createState() => _OnlineAppState();
}

class _OnlineAppState extends State<OnlineApp> {
  OnlineSession? _session;
  var _navigator = GlobalKey<NavigatorState>();
  String? _navigationUser;
  StreamSubscription<Uri>? _links;
  QrDestination? _pendingLink;
  bool _openingLink = false;
  String? _activeLink;

  @override
  void initState() {
    super.initState();
    _navigationUser = widget.repository?.userId;
    if (widget.repository != null) {
      _session = OnlineSession(widget.repository!)..addListener(_changed);
    }
    if (widget.enableDeepLinks) {
      final links = AppLinks();
      _links = links.uriLinkStream.listen(_receiveLink, onError: (Object _) {});
      unawaited(
        links
            .getInitialLink()
            .then((uri) {
              if (uri != null) _receiveLink(uri);
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _receiveLink(Uri uri) {
    final destination = QrDestination.parse(uri.toString());
    if (destination?.value == _activeLink) return;
    if (!mounted ||
        destination == null ||
        (destination.kind == 'join') !=
            (widget.audience == AppAudience.business)) {
      return;
    }
    _pendingLink = destination;
    _scheduleLink();
  }

  void _scheduleLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLink());
  }

  Future<void> _openLink() async {
    final target = _pendingLink;
    final session = _session;
    if (!mounted ||
        _openingLink ||
        target == null ||
        session?.workspace == null ||
        !session!.signedIn) {
      return;
    }
    if (widget.audience == AppAudience.business &&
        session.workspace!.profile?.isComplete != true) {
      return;
    }
    _openingLink = true;
    _activeLink = target.value;
    _pendingLink = null;
    final id = session.repository.userId;
    try {
      if (target.kind == 'join') {
        await _navigator.currentState?.push<void>(
          MaterialPageRoute(
            builder: (_) => JoinSalon(
              repository: session.repository,
              initialCode: target.id,
            ),
          ),
        );
      } else {
        final business = await session.repository.findBusiness(
          target.id,
          barber: target.kind == 'barber',
        );
        if (!mounted || session.repository.userId != id) return;
        if (business == null) {
          final context = _navigator.currentContext;
          if (context != null && context.mounted) {
            showMessage(context, 'This salon or barber is unavailable.');
          }
          return;
        }
        await _navigator.currentState?.push<void>(
          MaterialPageRoute(
            builder: (_) => SalonDetails(
              repository: session.repository,
              business: business,
              barberId: target.kind == 'barber' ? target.id : null,
            ),
          ),
        );
      }
    } catch (_) {
      final context = _navigator.currentContext;
      if (context != null && context.mounted) {
        showMessage(
          context,
          'Could not open the QR link. Try scanning again when connected.',
        );
      }
    } finally {
      _openingLink = false;
      _activeLink = null;
      if (_pendingLink != null) _scheduleLink();
    }
  }

  void _changed() {
    if (_navigationUser != widget.repository?.userId) {
      _navigationUser = widget.repository?.userId;
      _navigator = GlobalKey<NavigatorState>();
    }
    if (mounted) setState(() {});
    _scheduleLink();
  }

  void _openOffline(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const BusinessCombApp(hosted: true),
      ),
    );
  }

  @override
  void dispose() {
    _links?.cancel();
    _session?.removeListener(_changed);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Reset all private routes when the signed-in account changes.
    key: ValueKey(widget.repository?.userId),
    navigatorKey: _navigator,
    scaffoldMessengerKey: ToastService.messengerKey,
    title: widget.audience == AppAudience.business
        ? 'TrimMatrix Business'
        : 'TrimMatrix Customer',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    localizationsDelegates: const [FlutterQuillLocalizations.delegate],
    home: Builder(
      builder: (context) {
        final session = _session;
        if (session == null || !session.signedIn) {
          return OnlineLoginPage(
            audience: widget.audience,
            repository: widget.repository,
            startupError: widget.startupError,
            sessionError: session?.error,
          );
        }
        // Quiet entry: spinner only until workspace is ready (no sync copy).
        if (session.loading && session.workspace == null) {
          return const Scaffold(
            backgroundColor: AppColors.homeCanvas,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session.workspace == null) {
          return Scaffold(
            backgroundColor: AppColors.homeCanvas,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.error ?? 'Could not open your account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ActionButton(
                        label: 'Retry',
                        onPressed: session.reload,
                      ),
                      ActionButton(
                        label: 'Sign out',
                        onPressed: session.repository.signOut,
                        icon: Icons.logout,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (widget.audience == AppAudience.customer) {
          return CustomerDirectory(
            repository: session.repository,
            onSignOut: session.repository.signOut,
          );
        }
        if (session.workspace!.profile?.isComplete != true) {
          return ProfileForm(
            repository: session.repository,
            profile: session.workspace!.profile,
            name: session.workspace!.account.name,
            onboarding: true,
            onSaved: session.reload,
          );
        }
        // Owners manage salons; joined staff get their own daily work home.
        if (session.workspace!.businesses.isNotEmpty) {
          return BusinessHome(
            session: session,
            onSignOut: session.repository.signOut,
            onOpenOffline: () => _openOffline(context),
          );
        }
        return EmployeeHome(
          session: session,
          onSignOut: session.repository.signOut,
        );
      },
    ),
  );
}
