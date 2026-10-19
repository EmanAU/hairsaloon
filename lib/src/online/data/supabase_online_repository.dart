import 'package:supabase_flutter/supabase_flutter.dart';
import 'native_google_auth.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/pk_phone.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

class SupabaseOnlineRepository implements OnlineRepository {
  SupabaseOnlineRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> businessSnapshot(String businessId) => _client
      .from('business_snapshots')
      .select()
      .eq('business_id', businessId)
      .maybeSingle();
  @override
  Future<Map<String, dynamic>> syncBusiness(
    String businessId,
    int revision,
    String operation,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _client.rpc(
          'sync_business',
          params: {
            'business': businessId,
            'expected_revision': revision,
            'operation': operation,
            'data': data,
          },
        )
        as Map,
  );

  @override
  Future<SalonBusiness?> findBusiness(String id, {bool barber = false}) async {
    final businessId = barber
        ? await _client.rpc('resolve_barber', params: {'employee': id})
              as String?
        : id;
    if (businessId == null) return null;
    final row = await _client
        .from('businesses')
        .select()
        .eq('id', businessId)
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : SalonBusiness.fromJson(row);
  }

  @override
  Future<List<Map<String, dynamic>>> reviews(
    String businessId, {
    String? employeeId,
  }) async {
    final query = _client
        .from('reviews')
        .select()
        .eq('business_id', businessId);
    final rows =
        await (employeeId == null
                ? query.isFilter('employee_id', null)
                : query.eq('employee_id', employeeId))
            .order('created_at', ascending: false)
            .limit(100);
    if (rows.every((row) => row['author_id'] != userId)) {
      final ownQuery = _client
          .from('reviews')
          .select()
          .eq('business_id', businessId)
          .eq('author_id', _requiredUserId);
      final own =
          await (employeeId == null
                  ? ownQuery.isFilter('employee_id', null)
                  : ownQuery.eq('employee_id', employeeId))
              .maybeSingle();
      if (own != null) rows.insert(0, own);
    }
    return rows;
  }

  @override
  Future<void> saveReview(
    String businessId,
    int rating,
    String body, {
    String? employeeId,
    String? id,
  }) async {
    final data = {'rating': rating, 'body': body.trim()};
    try {
      if (id == null) {
        await _client.from('reviews').insert({
          ...data,
          'business_id': businessId,
          'employee_id': employeeId,
        });
      } else {
        await _client
            .from('reviews')
            .update(data)
            .eq('id', id)
            .eq('author_id', _requiredUserId);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const OnlineFailure(
          'You already reviewed this salon or barber. Refresh to edit your review.',
        );
      }
      if (e.code == '42501') {
        throw const OnlineFailure(
          'You cannot review your own salon or an inactive salon.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> media(String serviceId) async {
    final rows = await _client
        .from('service_media')
        .select()
        .eq('service_id', serviceId)
        .order('position')
        .order('id');
    return Future.wait(
      rows.map(
        (row) async => {
          ...row,
          'url': await _client.storage
              .from('service-media')
              .createSignedUrl(row['storage_path'] as String, 3600),
        },
      ),
    );
  }

  String _mime(String extension) => switch (extension.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    _ => throw const OnlineFailure('Choose JPG, PNG, WebP, MP4 or MOV.'),
  };

  @override
  Future<void> uploadMedia(
    String businessId,
    String serviceId,
    String kind,
    Uint8List bytes,
    String extension, {
    String? pairId,
  }) async {
    if (bytes.length > 50 * 1024 * 1024) {
      throw const OnlineFailure('Media must be under 50 MB.');
    }
    final mime = _mime(extension);
    if ((kind == 'video') != mime.startsWith('video/')) {
      throw const OnlineFailure('Choose the correct media type.');
    }
    final path = '$businessId/$serviceId/${const Uuid().v4()}.$extension';
    final bucket = _client.storage.from('service-media');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    try {
      await _client.from('service_media').insert({
        'service_id': serviceId,
        'kind': kind,
        'storage_path': path,
        'pair_id': pairId,
      });
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> deleteMedia(String id, String path) async {
    await _client.from('service_media').delete().eq('id', id);
    await _client.storage.from('service-media').remove([path]);
  }

  /// Storage RLS / auth headers can lag one beat after a fresh insert or login.
  Future<String> _uploadBinaryWithRetry({
    required String bucketId,
    required String Function() pathBuilder,
    required Uint8List bytes,
    required String mime,
  }) async {
    final bucket = _client.storage.from(bucketId);
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final path = pathBuilder();
      try {
        await bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime),
        );
        return path;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }
    throw lastError!;
  }

  Future<Map<String, dynamic>> _waitForProfileRow() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final row = await _client
          .from('profiles')
          .select('photo_path')
          .eq('user_id', _requiredUserId)
          .maybeSingle();
      if (row != null) return row;
      await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
    }
    throw const PhotoUploadFailure(
      'Details were saved, but the photo could not be uploaded. Try again.',
    );
  }

  Future<void> _waitForOwnedBusiness(String businessId) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final row = await _client
          .from('businesses')
          .select('id')
          .eq('id', businessId)
          .eq('owner_id', _requiredUserId)
          .maybeSingle();
      if (row != null) return;
      await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
    }
    throw const PhotoUploadFailure(
      'Business was saved, but the photo could not be uploaded. Try again.',
    );
  }

  @override
  Future<void> uploadProfilePhoto(Uint8List bytes, String extension) async {
    final mime = _mime(extension);
    if (!mime.startsWith('image/') ||
        bytes.isEmpty ||
        bytes.length > 2 * 1024 * 1024) {
      throw const OnlineFailure('Choose a JPG, PNG or WebP photo up to 2 MB.');
    }
    try {
      // Ensure the profile row from saveProfile is visible before we attach a photo.
      final old = await _waitForProfileRow();
      final bucket = _client.storage.from('profile-photos');
      final path = await _uploadBinaryWithRetry(
        bucketId: 'profile-photos',
        pathBuilder: () => '$_requiredUserId/${const Uuid().v4()}.$extension',
        bytes: bytes,
        mime: mime,
      );
      try {
        final updated = await _client
            .from('profiles')
            .update({'photo_path': path})
            .eq('user_id', _requiredUserId)
            .select('photo_path')
            .maybeSingle();
        if (updated == null) {
          throw const PhotoUploadFailure(
            'Details were saved, but the photo could not be uploaded. Try again.',
          );
        }
      } catch (error) {
        try {
          await bucket.remove([path]);
        } catch (_) {}
        rethrow;
      }
      final previous = old['photo_path'] as String?;
      if (previous != null && previous != path) {
        try {
          await bucket.remove([previous]);
        } catch (_) {}
      }
    } on OnlineFailure {
      rethrow;
    } catch (error) {
      _throwWriteFailure(
        error,
        fallback:
            'Details were saved, but the photo could not be uploaded. Try again.',
        asPhoto: true,
      );
    }
  }

  @override
  Future<String?> profilePhoto({String? barberId}) async {
    if (barberId != null) {
      final path =
          await _client.rpc('barber_photo', params: {'employee': barberId})
              as String?;
      return path == null
          ? null
          : _client.storage.from('profile-photos').createSignedUrl(path, 3600);
    }
    final row = await _client
        .from('profiles')
        .select('photo_path')
        .eq('user_id', _requiredUserId)
        .maybeSingle();
    final path = row?['photo_path'] as String?;
    return path == null
        ? null
        : _client.storage.from('profile-photos').createSignedUrl(path, 3600);
  }

  @override
  Future<List<SalonStaff>> staff(String businessId) async {
    final rows =
        await _client.rpc('business_staff', params: {'business': businessId})
            as List;
    return rows
        .map(
          (row) => SalonStaff.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> inviteEmployee(String businessId, String profileCode) async {
    try {
      await _client.rpc(
        'invite_employee',
        params: {'business': businessId, 'profile_code': profileCode.trim()},
      );
    } on PostgrestException catch (error) {
      final text = error.message.toLowerCase();
      if (text.contains('profile not found')) {
        throw const OnlineFailure('No profile found for that code.');
      }
      if (text.contains('approval') || text.contains('owner')) {
        throw OnlineFailure(
          error.message.trim().isEmpty
              ? 'Could not add this employee.'
              : error.message,
        );
      }
      throw OnlineFailure(
        error.message.trim().isEmpty
            ? 'Could not add this employee. Try again.'
            : error.message,
      );
    } on ClientException {
      throw const OnlineFailure(
        'Could not add employee. Check your connection and try again.',
      );
    }
  }

  @override
  Future<String> inviteEmployeeByIdentity({
    required String businessId,
    required String cnic,
    required String phone,
    required String email,
    String name = '',
  }) async {
    try {
      final id = await _client.rpc(
        'invite_employee_by_identity',
        params: {
          'business': businessId,
          'employee_cnic': cnic.replaceAll('-', '').trim(),
          'employee_phone': PkPhone.normalize(phone),
          'employee_email': email.trim().toLowerCase(),
          'employee_name': name.trim(),
        },
      );
      return id as String;
    } catch (error) {
      _throwJoinFailure(error);
    }
  }

  @override
  Future<List<PendingEmployeeInvite>> pendingInvitesForMe() async {
    try {
      final rows = await _client.rpc('pending_invites_for_me') as List;
      return rows
          .map(
            (row) => PendingEmployeeInvite.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not load salon invites.');
    }
  }

  @override
  Future<void> respondToEmployeeInvite(String inviteId, bool accept) async {
    try {
      await _client.rpc(
        'respond_to_employee_invite',
        params: {'invite': inviteId, 'accept': accept},
      );
    } catch (error) {
      _throwJoinFailure(error);
    }
  }

  @override
  Future<void> setEmployeeManager({
    required String employeeId,
    required bool isManager,
    String? pin,
  }) async {
    try {
      await _client.rpc(
        'set_employee_manager',
        params: {
          'employee': employeeId,
          'make_manager': isManager,
          'pin': pin,
        },
      );
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not update manager access.');
    }
  }

  @override
  Future<bool> verifyManagerPin(String businessId, String pin) async {
    try {
      final ok = await _client.rpc(
        'verify_manager_pin',
        params: {'business': businessId, 'pin': pin},
      );
      return ok == true;
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not verify manager PIN.');
    }
  }

  @override
  Future<List<ManagerBusiness>> myManagerBusinesses() async {
    try {
      final rows = await _client.rpc('my_manager_businesses') as List;
      return rows
          .map(
            (row) =>
                ManagerBusiness.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not load manager access.');
    }
  }

  @override
  Future<void> ensureBusinessServices(String businessId) async {
    try {
      await _client.rpc(
        'ensure_business_defaults',
        params: {'business': businessId},
      );
    } catch (error) {
      // Older DBs may only expose ensure_business_services.
      try {
        await _client.rpc(
          'ensure_business_services',
          params: {'business': businessId},
        );
      } catch (_) {
        _throwWriteFailure(error, fallback: 'Could not load default services.');
      }
    }
  }

  @override
  Future<BusinessSettings> getBusinessSettings(String businessId) async {
    try {
      final rows =
          await _client.rpc(
                'get_business_settings',
                params: {'business': businessId},
              )
              as List;
      if (rows.isEmpty) {
        return const BusinessSettings(
          taxRate: 17,
          currencyCode: 'PKR',
          expenseTypes: [],
          paymentAccounts: [],
        );
      }
      return BusinessSettings.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not load business settings.');
    }
  }

  @override
  Future<void> updateBusinessSettings({
    required String businessId,
    double? taxRate,
    String? currencyCode,
    List<String>? expenseTypes,
    List<String>? paymentAccounts,
  }) async {
    try {
      await _client.rpc(
        'update_business_settings',
        params: {
          'business': businessId,
          'new_tax_rate': taxRate,
          'new_currency_code': currencyCode,
          'new_expense_types': expenseTypes,
          'new_payment_accounts': paymentAccounts,
        },
      );
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not save business settings.');
    }
  }

  @override
  Future<List<SalonStaff>> team(String businessId) async {
    try {
      final rows =
          await _client.rpc('business_team', params: {'business': businessId})
              as List;
      return rows
          .map(
            (row) => SalonStaff.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on PostgrestException catch (error) {
      final text = error.message.toLowerCase();
      if (text.contains('owner') || error.code == '42501') {
        throw const OnlineFailure('Only the salon owner can view the team.');
      }
      throw OnlineFailure(
        error.message.trim().isEmpty
            ? 'Could not load employees. Try again.'
            : error.message,
      );
    } on ClientException {
      throw const OnlineFailure(
        'Could not load employees. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> reviewJoin(String employeeId, bool accept) async {
    try {
      await _client.rpc(
        'review_join',
        params: {'employee': employeeId, 'accept': accept},
      );
    } on PostgrestException catch (error) {
      throw OnlineFailure(
        error.message.trim().isEmpty
            ? 'Could not update this request. Try again.'
            : error.message,
      );
    }
  }

  @override
  Future<List<WorkContract>> contracts({String? employeeId}) async {
    var query = _client
        .from('employee_contracts')
        .select('*,business_employees(business_id,businesses(name))');
    query = employeeId == null
        ? query.eq('profile_id', _requiredUserId)
        : query.eq('employee_id', employeeId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map(WorkContract.fromJson).toList();
  }

  @override
  Future<EmployeeDashboardData> employeeDashboard() async {
    final contracts = await this.contracts();
    final joinRequests = await this.joinRequests();
    final account = (await loadWorkspace()).account;
    final name = account.name.trim().toLowerCase();
    final jobs = <EmployeeWorkJob>[];

    for (final contract in contracts.where((c) => c.isLive)) {
      if (contract.businessId.isEmpty) continue;
      final snapshot = await businessSnapshot(contract.businessId);
      final payload = snapshot?['payload'];
      if (payload is! Map) continue;
      final bills = Map<String, dynamic>.from(
        (payload['bills'] as Map?) ?? const {},
      );
      for (final raw in bills.values) {
        if (raw is! Map) continue;
        final bill = Map<String, dynamic>.from(raw);
        final employeeName = (bill['employeeName'] ?? '').toString().trim();
        if (employeeName.toLowerCase() != name) continue;
        final lines = (bill['lines'] as List?) ?? const [];
        final services = lines
            .whereType<Map>()
            .map((line) => (line['serviceName'] ?? line['name'] ?? '').toString())
            .where((label) => label.isNotEmpty)
            .toList();
        jobs.add(
          EmployeeWorkJob(
            id: (bill['id'] ?? '').toString(),
            createdAt:
                DateTime.tryParse((bill['createdAt'] ?? '').toString()) ??
                DateTime.now(),
            customerName: (bill['customerName'] ?? 'Customer').toString(),
            total: (bill['grandTotal'] as num?)?.toDouble() ?? 0,
            services: services,
            businessName: contract.businessName,
            commissionPercent: contract.commission,
          ),
        );
      }
    }

    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byDay = <DateTime, List<EmployeeWorkJob>>{};
    for (final job in jobs) {
      final day = DateTime(
        job.createdAt.year,
        job.createdAt.month,
        job.createdAt.day,
      );
      byDay.putIfAbsent(day, () => []).add(job);
    }
    final days =
        byDay.entries
            .map((entry) => EmployeeDayWork(date: entry.key, jobs: entry.value))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return EmployeeDashboardData(
      contracts: contracts,
      joinRequests: joinRequests,
      days: days,
    );
  }

  @override
  Future<void> proposeContract({
    required String employeeId,
    required String kind,
    required DateTime starts,
    DateTime? ends,
    required double salary,
    required double commission,
    required String terms,
  }) async {
    await _client.rpc(
      'propose_contract',
      params: {
        'employee': employeeId,
        'contract_kind': kind,
        'starts': starts.toUtc().toIso8601String(),
        'ends': ends?.toUtc().toIso8601String(),
        'basic_salary': salary,
        'commission': commission,
        'description': terms.trim(),
      },
    );
  }

  @override
  Future<void> respondToContract(String id, bool accept) async {
    throw const OnlineFailure(
      'Contracts are set by the salon owner. Contact them for changes.',
    );
  }

  @override
  Future<void> releaseContract(String id, String reason) async {
    await _client.rpc(
      'release_contract',
      params: {'contract': id, 'reason': reason.trim()},
    );
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get authChanges => _client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();

  @override
  Future<void> signInWithGoogle() async {
    final idToken = await NativeGoogleAuth.idToken();
    if (idToken == null) return;
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await NativeGoogleAuth.signOut();
    } finally {
      await _client.auth.signOut();
    }
  }

  String get _requiredUserId => userId ?? (throw StateError('Sign in first.'));

  @override
  Future<OnlineWorkspace> loadWorkspace() async {
    final id = _requiredUserId;
    try {
      return await _fetchWorkspace().timeout(const Duration(seconds: 15));
    } on ClientException {
      return _cachedWorkspace(id);
    } on TimeoutException {
      return _cachedWorkspace(id);
    }
  }

  Future<OnlineWorkspace> _cachedWorkspace(String id) async {
    if (userId != id) throw const OnlineFailure('Sign in again.');
    final value = (await SharedPreferences.getInstance()).getString(
      'online_workspace_$id',
    );
    if (value == null) {
      throw const OnlineFailure(
        'Connect once to set up this account on this device.',
      );
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    return _workspaceFromJson(json, cached: true);
  }

  OnlineWorkspace _workspaceFromJson(
    Map<String, dynamic> data, {
    bool cached = false,
  }) => OnlineWorkspace(
    isCached: cached,
    account: OnlineAccount(
      id: data['id'] as String,
      name: (data['account'] as Map)['display_name'] as String,
    ),
    profile: data['profile'] == null
        ? null
        : PersonalProfile.fromJson(
            Map<String, dynamic>.from(data['profile'] as Map),
          ),
    businesses: (data['businesses'] as List)
        .map(
          (row) =>
              SalonBusiness.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(),
  );

  Future<OnlineWorkspace> _fetchWorkspace() async {
    final id = _requiredUserId;
    var account = await _client
        .from('users')
        .select('id,display_name')
        .eq('id', id)
        .maybeSingle();
    if (account == null) {
      final name =
          (_client.auth.currentUser?.userMetadata?['full_name'] as String?)
              ?.trim();
      try {
        await _client.from('users').insert({
          'id': id,
          'display_name': name == null || name.isEmpty
              ? 'User'
              : name.substring(0, name.length.clamp(0, 120)),
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
      account = await _client
          .from('users')
          .select('id,display_name')
          .eq('id', id)
          .single();
    }
    final profile = await _client
        .from('profiles')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    final businesses = await _client
        .from('businesses')
        .select()
        .eq('owner_id', id)
        .order('created_at');
    final data = {
      'id': id,
      'account': account,
      'profile': profile,
      'businesses': businesses,
    };
    if (userId == id) {
      await (await SharedPreferences.getInstance()).setString(
        'online_workspace_$id',
        jsonEncode(data),
      );
    }
    return _workspaceFromJson(data);
  }

  @override
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String cnic,
    required DateTime dateOfBirth,
    required DateTime workStartedOn,
    Uint8List? photoBytes,
    String? photoExtension,
  }) async {
    final id = _requiredUserId;
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw const OnlineFailure('Enter your name (up to 120 characters).');
    }
    final phoneError = PkPhone.localValidationError(PkPhone.localNumber(phone));
    if (phoneError != null) throw OnlineFailure(phoneError);
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day + 1);
    if (dateOfBirth.isAfter(today) ||
        workStartedOn.isBefore(dateOfBirth) ||
        !workStartedOn.isBefore(endOfToday)) {
      throw const OnlineFailure(
        'Check your date of birth and work start date.',
      );
    }
    if (photoBytes != null &&
        (photoExtension == null || photoExtension.trim().isEmpty)) {
      throw const OnlineFailure('Choose a JPG, PNG or WebP photo up to 2 MB.');
    }
    final values = <String, dynamic>{
      'phone': PkPhone.normalize(phone),
      'cnic': cnic.replaceAll('-', '').trim(),
      'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
      'work_started_on': workStartedOn.toIso8601String().substring(0, 10),
    };
    String? uploadedPath;
    String? previousPath;
    try {
      final existing = await _client
          .from('profiles')
          .select('user_id, photo_path')
          .eq('user_id', id)
          .maybeSingle();
      previousPath = existing?['photo_path'] as String?;
      // Upload first, then write photo_path in the same insert/update so the
      // first save never leaves details without a photo.
      if (photoBytes != null) {
        final mime = _mime(photoExtension!);
        if (!mime.startsWith('image/') ||
            photoBytes.isEmpty ||
            photoBytes.length > 2 * 1024 * 1024) {
          throw const OnlineFailure(
            'Choose a JPG, PNG or WebP photo up to 2 MB.',
          );
        }
        uploadedPath = await _uploadBinaryWithRetry(
          bucketId: 'profile-photos',
          pathBuilder: () => '$id/${const Uuid().v4()}.$photoExtension',
          bytes: photoBytes,
          mime: mime,
        );
        values['photo_path'] = uploadedPath;
      }
      if (existing == null) {
        await _client.from('profiles').insert({'user_id': id, ...values});
      } else {
        final updated = await _client
            .from('profiles')
            .update(values)
            .eq('user_id', id)
            .select('user_id')
            .maybeSingle();
        if (updated == null) {
          throw const OnlineFailure('Could not save your profile.');
        }
      }
      try {
        await _client
            .from('users')
            .update({'display_name': name.trim()})
            .eq('id', id);
      } catch (_) {
        // Profile row is already saved; display name is best-effort.
      }
      if (uploadedPath != null &&
          previousPath != null &&
          previousPath != uploadedPath) {
        try {
          await _client.storage.from('profile-photos').remove([previousPath]);
        } catch (_) {}
      }
    } on OnlineFailure {
      if (uploadedPath != null) {
        try {
          await _client.storage.from('profile-photos').remove([uploadedPath]);
        } catch (_) {}
      }
      rethrow;
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await _client.storage.from('profile-photos').remove([uploadedPath]);
        } catch (_) {}
      }
      _throwWriteFailure(
        error,
        fallback: photoBytes != null
            ? 'Could not upload the photo. Check your connection and try again.'
            : 'Could not save your profile.',
        asPhoto: photoBytes != null,
      );
    }
  }

  @override
  Future<String> saveBusiness({
    String? id,
    required String name,
    required String phone,
    required String type,
    required String city,
    required String area,
    required String address,
  }) async {
    final values = {
      'name': name.trim(),
      'phone': PkPhone.normalize(phone),
      'business_type': type.trim(),
      'city': city.trim(),
      'area': area.trim(),
      'address': address.trim(),
    };
    try {
      if (id == null) {
        final existing = await _client
            .from('businesses')
            .select('id')
            .eq('owner_id', _requiredUserId)
            .maybeSingle();
        if (existing != null) {
          throw const OnlineFailure(
            'You already have a business. One owner can register one shop.',
          );
        }
        final created = await _client
            .from('businesses')
            .insert({'owner_id': _requiredUserId, ...values})
            .select('id')
            .single();
        return created['id'] as String;
      } else {
        await _client
            .from('businesses')
            .update(values)
            .eq('id', id)
            .eq('owner_id', _requiredUserId);
        return id;
      }
    } on OnlineFailure {
      rethrow;
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not save the business.');
    }
  }

  @override
  Future<String?> businessPhoto(SalonBusiness business) async =>
      business.logoPath == null
      ? null
      : _client.storage
            .from('business-photos')
            .createSignedUrl(business.logoPath!, 3600);

  @override
  Future<void> uploadBusinessPhoto(
    String businessId,
    Uint8List bytes,
    String extension,
  ) async {
    final mime = _mime(extension);
    if (!mime.startsWith('image/') ||
        bytes.isEmpty ||
        bytes.length > 2 * 1024 * 1024) {
      throw const OnlineFailure('Choose a JPG, PNG or WebP photo up to 2 MB.');
    }
    try {
      // Storage RLS checks businesses; wait until the new row is visible.
      await _waitForOwnedBusiness(businessId);
      final old = await _client
          .from('businesses')
          .select('logo_path')
          .eq('id', businessId)
          .eq('owner_id', _requiredUserId)
          .maybeSingle();
      final bucket = _client.storage.from('business-photos');
      final path = await _uploadBinaryWithRetry(
        bucketId: 'business-photos',
        pathBuilder: () => '$businessId/${const Uuid().v4()}.$extension',
        bytes: bytes,
        mime: mime,
      );
      try {
        final updated = await _client
            .from('businesses')
            .update({'logo_path': path})
            .eq('id', businessId)
            .eq('owner_id', _requiredUserId)
            .select('id')
            .maybeSingle();
        if (updated == null) {
          throw const PhotoUploadFailure(
            'Business was saved, but the photo could not be uploaded. Try again.',
          );
        }
      } catch (error) {
        try {
          await bucket.remove([path]);
        } catch (_) {}
        rethrow;
      }
      final previous = old?['logo_path'] as String?;
      if (previous != null && previous != path) {
        try {
          await bucket.remove([previous]);
        } catch (_) {}
      }
    } on OnlineFailure {
      rethrow;
    } catch (error) {
      _throwWriteFailure(
        error,
        fallback:
            'Business was saved, but the photo could not be uploaded. Try again.',
        asPhoto: true,
      );
    }
  }

  Never _throwWriteFailure(
    Object error, {
    required String fallback,
    bool asPhoto = false,
  }) {
    if (error is OnlineFailure) throw error;
    if (error is ClientException) {
      throw OnlineFailure(
        asPhoto
            ? fallback
            : 'Could not reach the server. Check your connection and try again.',
      );
    }
    if (error is PostgrestException) {
      final text =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      if (text.contains('duplicate') || error.code == '23505') {
        if (text.contains('cnic')) {
          throw const OnlineFailure('This CNIC is already registered.');
        }
        if (text.contains('owner') || text.contains('businesses_owner')) {
          throw const OnlineFailure(
            'You already have a business. One owner can register one shop.',
          );
        }
        throw const OnlineFailure('This record already exists.');
      }
      final message = error.message.trim();
      throw OnlineFailure(message.isEmpty ? fallback : message);
    }
    if (asPhoto) throw PhotoUploadFailure(fallback);
    throw OnlineFailure(fallback);
  }

  Never _throwJoinFailure(Object error) {
    if (error is OnlineFailure) throw error;
    if (error is ClientException) {
      throw const OnlineFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    if (error is PostgrestException) {
      final text =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      if (text.contains('create your profile')) {
        throw const OnlineFailure(
          'Create your personal profile first, then try again.',
        );
      }
      if (text.contains('salon not approved')) {
        throw const OnlineFailure(
          'This salon is waiting for admin approval. Try again after it is active.',
        );
      }
      if (text.contains('invite unavailable')) {
        throw const OnlineFailure(
          'This salon code is invalid or no longer available.',
        );
      }
      if (text.contains('owner access')) {
        throw const OnlineFailure(
          'Only the salon owner can view this joining code.',
        );
      }
      if (error.code == '22P02') {
        throw const OnlineFailure('Paste a valid salon joining code.');
      }
      final message = error.message.trim();
      throw OnlineFailure(
        message.isEmpty
            ? 'Could not complete this action. Try again.'
            : message,
      );
    }
    throw const OnlineFailure(
      'Could not complete this action. Check your connection and try again.',
    );
  }

  @override
  Future<String> businessInvite(String businessId) async {
    try {
      try {
        final code = await _client.rpc(
          'owner_invite_code',
          params: {'business': businessId},
        );
        if (code is String && code.isNotEmpty) return code;
      } on PostgrestException catch (error) {
        final missing =
            error.code == 'PGRST202' ||
            error.message.toLowerCase().contains('could not find');
        if (!missing) rethrow;
      }
      final existing = await _client
          .from('business_invites')
          .select('code')
          .eq('business_id', businessId)
          .maybeSingle();
      if (existing != null) return existing['code'] as String;
      try {
        await _client.from('business_invites').insert({
          'business_id': businessId,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
      final row = await _client
          .from('business_invites')
          .select('code')
          .eq('business_id', businessId)
          .single();
      return row['code'] as String;
    } catch (error) {
      _throwJoinFailure(error);
    }
  }

  @override
  Future<void> requestJoin(String code) async {
    try {
      await _client.rpc('request_join', params: {'invite_code': code.trim()});
    } catch (error) {
      _throwJoinFailure(error);
    }
  }

  @override
  Future<List<SalonJoinRequest>> joinRequests() async {
    final rows = await _client
        .from('business_employees')
        .select('id,join_status,businesses(name)')
        .eq('profile_id', _requiredUserId)
        .order('created_at', ascending: false);
    return rows.map(SalonJoinRequest.fromJson).toList();
  }

  @override
  Future<List<SalonBusiness>> discoverBusinesses({
    String search = '',
    int page = 0,
  }) async {
    final rows = await _client
        .from('businesses')
        .select()
        .eq('is_active', true)
        .ilike('name', '%${search.trim()}%')
        .order('name')
        .order('id')
        .range(page * 25, page * 25 + 24);
    return rows.map(SalonBusiness.fromJson).toList();
  }

  @override
  Future<List<SalonService>> services(
    String businessId, {
    bool includeInactive = false,
  }) async {
    var query = _client.from('services').select().eq('business_id', businessId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('name');
    return rows.map(SalonService.fromJson).toList();
  }

  @override
  Future<SalonService?> serviceById(String serviceId) async {
    try {
      final row = await _client
          .from('services')
          .select()
          .eq('id', serviceId)
          .maybeSingle();
      if (row == null) return null;
      return SalonService.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not load the service.');
    }
  }

  @override
  Future<SalonService> saveService({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required String description,
    required double price,
    required bool isActive,
    List<dynamic>? contentJson,
  }) async {
    final values = <String, dynamic>{
      'name': name.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'price': price,
      'is_active': isActive,
    };
    if (contentJson != null) {
      values['content_json'] = contentJson;
    }
    try {
      final Map<String, dynamic> row;
      if (id == null) {
        row = await _client
            .from('services')
            .insert({'business_id': businessId, ...values})
            .select()
            .single();
      } else {
        row = await _client
            .from('services')
            .update(values)
            .eq('id', id)
            .eq('business_id', businessId)
            .select()
            .single();
      }
      return SalonService.fromJson(row);
    } on OnlineFailure {
      rethrow;
    } catch (error) {
      _throwWriteFailure(error, fallback: 'Could not save the service.');
    }
  }

  @override
  Future<SalonService> saveServiceContent({
    required String serviceId,
    required List<dynamic> contentJson,
    required String description,
    String? name,
  }) async {
    final trimmedName = name?.trim();
    try {
      final row = await _client.rpc(
        'update_service_content',
        params: {
          'service': serviceId,
          'content': contentJson,
          'plain_description': description,
          'service_name': trimmedName,
        },
      );
      if (row is Map) {
        return SalonService.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (_) {
      // Older DBs may not have service_name yet.
    }

    try {
      final row = await _client.rpc(
        'update_service_content',
        params: {
          'service': serviceId,
          'content': contentJson,
          'plain_description': description,
        },
      );
      if (row is Map) {
        final saved = SalonService.fromJson(Map<String, dynamic>.from(row));
        if (trimmedName == null ||
            trimmedName.isEmpty ||
            saved.name == trimmedName) {
          return saved;
        }
        final biz = await _client
            .from('services')
            .select('business_id')
            .eq('id', serviceId)
            .single();
        return saveService(
          businessId: biz['business_id'] as String,
          id: serviceId,
          name: trimmedName,
          category: saved.category,
          description: description,
          price: saved.price,
          isActive: saved.isActive,
          contentJson: contentJson,
        );
      }
    } catch (_) {}

    try {
      final values = <String, dynamic>{
        'content_json': contentJson,
        'description': description,
      };
      if (trimmedName != null && trimmedName.isNotEmpty) {
        values['name'] = trimmedName;
      }
      final updated = await _client
          .from('services')
          .update(values)
          .eq('id', serviceId)
          .select()
          .single();
      return SalonService.fromJson(updated);
    } on OnlineFailure {
      rethrow;
    } catch (error) {
      _throwWriteFailure(
        error,
        fallback: 'Could not save customer view. Try again.',
      );
    }
  }
}
