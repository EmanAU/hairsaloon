import 'dart:async';
import 'dart:typed_data';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/domain/online_repository.dart';

class FakeOnlineRepository implements OnlineRepository {
  int reviewSaves = 0;
  String? savedReviewEmployee;
  String? savedReviewBody;
  @override
  Future<Map<String, dynamic>?> businessSnapshot(String businessId) async =>
      null;
  @override
  Future<Map<String, dynamic>> syncBusiness(
    String businessId,
    int revision,
    String operation,
    Map<String, dynamic> data,
  ) async => {'conflict': false, 'revision': revision + 1};
  @override
  Future<SalonBusiness?> findBusiness(String id, {bool barber = false}) async =>
      null;
  @override
  Future<List<Map<String, dynamic>>> reviews(
    String businessId, {
    String? employeeId,
  }) async => [];
  @override
  Future<void> saveReview(
    String businessId,
    int rating,
    String body, {
    String? employeeId,
    String? id,
  }) async {
    reviewSaves++;
    savedReviewEmployee = employeeId;
    savedReviewBody = body;
  }

  @override
  Future<void> deleteReview(String id) async {}
  @override
  Future<List<Map<String, dynamic>>> media(String serviceId) async => [];
  @override
  Future<void> uploadMedia(
    String businessId,
    String serviceId,
    String kind,
    Uint8List bytes,
    String extension, {
    String? pairId,
  }) async {}
  @override
  Future<void> deleteMedia(String id, String path) async {}
  @override
  Future<void> uploadProfilePhoto(Uint8List bytes, String extension) async {}
  @override
  Future<String?> profilePhoto({String? barberId}) async => null;
  List<WorkContract> contractRows = [];
  bool rejectAcceptance = false;
  @override
  Future<List<SalonStaff>> staff(String businessId) async => [];
  @override
  Future<void> inviteEmployee(String businessId, String profileCode) async {}
  @override
  Future<List<WorkContract>> contracts({String? employeeId}) async =>
      contractRows;
  @override
  Future<void> proposeContract({
    required String employeeId,
    required String kind,
    required DateTime starts,
    DateTime? ends,
    required double salary,
    required double commission,
    required String terms,
  }) async {}
  @override
  Future<void> respondToContract(String id, bool accept) async {
    if (rejectAcceptance) {
      throw const OnlineFailure('Contract overlaps another salon.');
    }
  }

  @override
  Future<void> releaseContract(String id, String reason) async {}
  @override
  String? userId;
  final events = StreamController<String?>.broadcast();
  OnlineWorkspace workspace = const OnlineWorkspace(
    account: OnlineAccount(id: 'user', name: 'Test User'),
  );
  Future<OnlineWorkspace>? pendingWorkspace;
  int profileSaves = 0;
  int signInCalls = 0;
  int businessSaves = 0;

  @override
  Stream<String?> get authChanges => events.stream;
  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
  }

  @override
  Future<void> signOut() async {
    userId = null;
    events.add(null);
  }

  @override
  Future<OnlineWorkspace> loadWorkspace() =>
      pendingWorkspace ?? Future.value(workspace);
  @override
  Future<void> saveProfile({
    required String phone,
    required String cnic,
    required DateTime dateOfBirth,
  }) async {
    profileSaves++;
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
    businessSaves++;
  }

  @override
  Future<String> businessInvite(String businessId) async =>
      '00000000-0000-4000-8000-000000000001';
  @override
  Future<void> requestJoin(String code) async {}
  @override
  Future<List<SalonBusiness>> discoverBusinesses({
    String search = '',
    int page = 0,
  }) async => const [
    SalonBusiness(
      id: 'salon',
      name: 'Test Salon',
      phone: '03000000000',
      type: 'Salon',
      city: 'Lahore',
      area: 'Test',
      address: 'Test address',
      isActive: true,
    ),
  ];
  @override
  Future<List<SalonService>> services(
    String businessId, {
    bool includeInactive = false,
  }) async => const [
    SalonService(
      id: 'service',
      name: 'Haircut',
      description: 'A haircut',
      price: 500,
      category: 'Hair',
    ),
  ];

  @override
  Future<void> saveService({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required String description,
    required double price,
    required bool isActive,
  }) async {}
}
