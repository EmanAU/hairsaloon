import 'package:google_sign_in/google_sign_in.dart';
import '../domain/online_models.dart';

/// Exchanges only Google identity; Supabase owns the application's session.
abstract final class NativeGoogleAuth {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '589261083311-fedtragk8r0hm5g862i01tdoai4hbqcj.apps.googleusercontent.com',
  );
  static Future<void>? _initialization;

  static Future<void> _initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(serverClientId: serverClientId);

  /// A dismissed account picker leaves the app signed out without an error.
  static Future<String?> idToken() async {
    try {
      await _initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const OnlineFailure(
          'Native Google login is not supported on this platform.',
        );
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const OnlineFailure(
          'Google did not return an ID token. Try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const OnlineFailure(
          'Google login configuration needs checking: Android package, signing '
          'SHA-1 and Web OAuth client ID.',
        );
      }
      throw const OnlineFailure(
        'Google sign-in could not finish. Please retry.',
      );
    }
  }

  static Future<void> signOut() async {
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }
}
