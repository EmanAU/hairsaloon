import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hairsaloon/src/online/data/native_google_auth.dart';
import 'package:hairsaloon/src/online/data/supabase_online_repository.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';

class FakeGooglePlatform extends GoogleSignInPlatform {
  String? token = 'google-id-token';
  GoogleSignInExceptionCode? failure;
  InitParameters? initialization;
  bool signedOut = false;

  @override
  Future<void> init(InitParameters params) async => initialization = params;
  @override
  bool supportsAuthenticate() => true;
  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (failure != null) throw GoogleSignInException(code: failure!);
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: 'test@example.com',
        id: 'google-user',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: token),
    );
  }

  @override
  Future<void> signOut(SignOutParams params) async => signedOut = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final google = FakeGooglePlatform();
  late SupabaseClient client;
  late SupabaseOnlineRepository repository;
  final requests = <http.Request>[];

  setUpAll(() => GoogleSignInPlatform.instance = google);
  setUp(() {
    google.failure = null;
    google.token = 'google-id-token';
    google.signedOut = false;
    requests.clear();
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'access_token': 'session-token',
            'refresh_token': 'refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'supabase-user',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-18T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseOnlineRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'business photos reject oversized files before network access',
    () async {
      await expectLater(
        repository.uploadBusinessPhoto(
          'business',
          Uint8List(2 * 1024 * 1024 + 1),
          'png',
        ),
        throwsA(isA<OnlineFailure>()),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'profile photos above 2 MB are rejected before network upload',
    () async {
      await expectLater(
        repository.uploadProfilePhoto(Uint8List(2 * 1024 * 1024 + 1), 'jpg'),
        throwsA(
          isA<OnlineFailure>().having(
            (e) => e.message,
            'message',
            contains('2 MB'),
          ),
        ),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'native ID token creates Supabase session; logout clears both',
    () async {
      await repository.signInWithGoogle();
      expect(
        google.initialization?.serverClientId,
        NativeGoogleAuth.serverClientId,
      );
      expect(requests.single.url.queryParameters['grant_type'], 'id_token');
      expect(jsonDecode(requests.single.body)['id_token'], 'google-id-token');
      expect(jsonDecode(requests.single.body)['provider'], 'google');
      expect(repository.userId, 'supabase-user');
      await repository.signOut();
      expect(google.signedOut, isTrue);
      expect(repository.userId, isNull);
    },
  );

  test('canceling picker makes no Supabase request', () async {
    google.failure = GoogleSignInExceptionCode.canceled;
    await repository.signInWithGoogle();
    expect(requests, isEmpty);
    expect(repository.userId, isNull);
  });

  test('missing token cannot create a session', () async {
    google.token = null;
    await expectLater(
      repository.signInWithGoogle(),
      throwsA(isA<OnlineFailure>()),
    );
    expect(requests, isEmpty);
  });

  test('native configuration failure has actionable message', () async {
    google.failure = GoogleSignInExceptionCode.clientConfigurationError;
    await expectLater(
      repository.signInWithGoogle(),
      throwsA(
        isA<OnlineFailure>().having(
          (e) => e.message,
          'message',
          contains('SHA-1'),
        ),
      ),
    );
    expect(requests, isEmpty);
  });
}
