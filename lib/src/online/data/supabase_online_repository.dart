import 'package:supabase_flutter/supabase_flutter.dart';
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
  SupabaseOnlineRepository(this._client, {required this.redirectUri});
  final SupabaseClient _client;
  final String redirectUri;

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

  @override
  Future<void> uploadProfilePhoto(Uint8List bytes, String extension) async {
    final mime = _mime(extension);
    if (!mime.startsWith('image/') || bytes.length > 5 * 1024 * 1024) {
      throw const OnlineFailure('Choose a photo under 5 MB.');
    }
    final old = await _client
        .from('profiles')
        .select('photo_path')
        .eq('user_id', _requiredUserId)
        .single();
    final path = '$_requiredUserId/${const Uuid().v4()}.$extension';
    final bucket = _client.storage.from('profile-photos');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    try {
      await _client
          .from('profiles')
          .update({'photo_path': path})
          .eq('user_id', _requiredUserId);
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
    if (old['photo_path'] != null) {
      await bucket.remove([old['photo_path'] as String]);
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
    await _client.rpc(
      'invite_employee',
      params: {'business': businessId, 'profile_code': profileCode.trim()},
    );
  }

  @override
  Future<List<WorkContract>> contracts({String? employeeId}) async {
    var query = _client
        .from('employee_contracts')
        .select('*,business_employees(businesses(name))');
    query = employeeId == null
        ? query.eq('profile_id', _requiredUserId)
        : query.eq('employee_id', employeeId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map(WorkContract.fromJson).toList();
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
    try {
      await _client.rpc(
        'respond_to_contract',
        params: {'contract': id, 'accept': accept},
      );
    } on PostgrestException catch (error) {
      if (error.code == '23P01') {
        throw const OnlineFailure(
          'This period overlaps another accepted contract. Request release or ask the owner to revise the dates.',
        );
      }
      rethrow;
    }
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
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUri,
    );
    if (!launched) throw StateError('Could not open Google sign-in.');
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

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
    required String phone,
    required String cnic,
    required DateTime dateOfBirth,
  }) async {
    final id = _requiredUserId;
    final values = {
      'phone': PkPhone.normalize(phone),
      'cnic': cnic.replaceAll('-', '').trim(),
      'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
    };
    final existing = await _client
        .from('profiles')
        .select('user_id')
        .eq('user_id', id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('profiles').insert({'user_id': id, ...values});
    } else {
      await _client.from('profiles').update(values).eq('user_id', id);
    }
  }

  @override
  Future<void> saveBusiness({
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
    if (id == null) {
      await _client.from('businesses').insert({
        'owner_id': _requiredUserId,
        ...values,
      });
    } else {
      await _client
          .from('businesses')
          .update(values)
          .eq('id', id)
          .eq('owner_id', _requiredUserId);
    }
  }

  @override
  Future<String> businessInvite(String businessId) async {
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
  }

  @override
  Future<void> requestJoin(String code) async {
    await _client.rpc('request_join', params: {'invite_code': code.trim()});
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
  Future<void> saveService({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required String description,
    required double price,
    required bool isActive,
  }) async {
    final values = {
      'name': name.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'price': price,
      'is_active': isActive,
    };
    if (id == null) {
      await _client.from('services').insert({
        'business_id': businessId,
        ...values,
      });
    } else {
      await _client
          .from('services')
          .update(values)
          .eq('id', id)
          .eq('business_id', businessId);
    }
  }
}
