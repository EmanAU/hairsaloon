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
  List<SalonStaff> teamRows = [];
  bool rejectJoinReview = false;
  @override
  Future<List<SalonStaff>> team(String businessId) async => teamRows;
  @override
  Future<void> reviewJoin(String employeeId, bool accept) async {
    if (rejectJoinReview) {
      throw const OnlineFailure('Could not review request. Please retry.');
    }
    teamRows = teamRows
        .map(
          (e) => e.id != employeeId
              ? e
              : SalonStaff(
                  id: e.id,
                  name: e.name,
                  isWorking: e.isWorking,
                  joinStatus: accept ? 'accepted' : 'declined',
                ),
        )
        .toList();
  }

  @override
  Future<void> inviteEmployee(String businessId, String profileCode) async {}

  List<PendingEmployeeInvite> pendingInviteRows = [];
  List<ManagerBusiness> managerBusinessRows = [];

  @override
  Future<String> inviteEmployeeByIdentity({
    required String businessId,
    required String cnic,
    required String phone,
    required String email,
    String name = '',
  }) async => 'invite-id';

  @override
  Future<List<PendingEmployeeInvite>> pendingInvitesForMe() async =>
      pendingInviteRows;

  @override
  Future<void> respondToEmployeeInvite(String inviteId, bool accept) async {
    pendingInviteRows = pendingInviteRows
        .where((invite) => invite.id != inviteId)
        .toList();
  }

  @override
  Future<void> setEmployeeManager({
    required String employeeId,
    required bool isManager,
    String? pin,
  }) async {
    teamRows = teamRows
        .map(
          (e) => e.id != employeeId
              ? e
              : SalonStaff(
                  id: e.id,
                  name: e.name,
                  isWorking: e.isWorking,
                  joinStatus: e.joinStatus,
                  isManager: isManager,
                ),
        )
        .toList();
  }

  @override
  Future<bool> verifyManagerPin(String businessId, String pin) async =>
      pin == '1234';

  @override
  Future<List<ManagerBusiness>> myManagerBusinesses() async =>
      managerBusinessRows;

  @override
  Future<void> ensureBusinessServices(String businessId) async {}

  @override
  Future<List<WorkContract>> contracts({String? employeeId}) async =>
      contractRows;
  EmployeeDashboardData? employeeDashboardData;
  @override
  Future<EmployeeDashboardData> employeeDashboard() async =>
      employeeDashboardData ??
      EmployeeDashboardData(
        contracts: contractRows,
        joinRequests: joinRequestRows,
        days: const [],
      );
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
  bool failRefreshAfterRegistration = false;

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
  Future<OnlineWorkspace> loadWorkspace() {
    if (failRefreshAfterRegistration && businessSaves > 0) {
      return Future.error(const OnlineFailure('Account refresh failed'));
    }
    return pendingWorkspace ?? Future.value(workspace);
  }

  @override
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String cnic,
    required DateTime dateOfBirth,
    required DateTime workStartedOn,
  }) async {
    profileSaves++;
    workspace = OnlineWorkspace(
      account: OnlineAccount(id: workspace.account.id, name: name),
      businesses: workspace.businesses,
      profile: PersonalProfile(
        code: workspace.profile?.code ?? 'generated-code',
        phone: phone,
        cnic: cnic,
        dateOfBirth: dateOfBirth,
        workStartedOn: workStartedOn,
        photoPath: workspace.profile?.photoPath,
      ),
    );
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
    businessSaves++;
    final saved = SalonBusiness(
      id: id ?? 'new-business',
      name: name,
      phone: phone,
      type: type,
      city: city,
      area: area,
      address: address,
      isActive: false,
      logoPath: workspace.businesses
          .where((b) => b.id == id)
          .firstOrNull
          ?.logoPath,
    );
    workspace = OnlineWorkspace(
      account: workspace.account,
      profile: workspace.profile,
      businesses: [
        ...workspace.businesses.where((b) => b.id != saved.id),
        saved,
      ],
    );
    return saved.id;
  }

  int businessPhotoUploads = 0;
  bool failBusinessPhoto = false;
  @override
  Future<void> uploadBusinessPhoto(
    String businessId,
    Uint8List bytes,
    String extension,
  ) async {
    businessPhotoUploads++;
    if (failBusinessPhoto) {
      throw const PhotoUploadFailure(
        'Could not upload photo. Please retry.',
      );
    }
  }

  @override
  Future<String?> businessPhoto(SalonBusiness business) async => null;

  @override
  Future<String> businessInvite(String businessId) async =>
      '00000000-0000-4000-8000-000000000001';
  @override
  Future<void> requestJoin(String code) async {
    if (rejectJoin) throw const OnlineFailure('Invite unavailable');
    requestedJoinCode = code;
  }

  bool rejectJoin = false;
  String? requestedJoinCode;
  List<SalonJoinRequest> joinRequestRows = [];
  @override
  Future<List<SalonJoinRequest>> joinRequests() async => joinRequestRows;
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
  List<SalonService> serviceRows = const [
    SalonService(
      id: 'service',
      name: 'Haircut',
      description: 'A haircut',
      price: 500,
      category: 'Hair',
    ),
  ];
  Map<String, dynamic>? lastSavedService;

  @override
  Future<List<SalonService>> services(
    String businessId, {
    bool includeInactive = false,
  }) async => serviceRows;

  @override
  Future<void> saveService({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required String description,
    required double price,
    required bool isActive,
    List<dynamic>? contentJson,
  }) async {
    lastSavedService = {
      'businessId': businessId,
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'isActive': isActive,
      'contentJson': contentJson,
    };
    if (id != null) {
      serviceRows = [
        for (final service in serviceRows)
          if (service.id == id)
            SalonService(
              id: id,
              name: name,
              category: category,
              description: description,
              price: price,
              isActive: isActive,
              contentJson: contentJson ?? service.contentJson,
            )
          else
            service,
      ];
    }
  }
}
