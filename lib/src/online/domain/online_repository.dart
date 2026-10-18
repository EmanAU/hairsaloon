import 'online_models.dart';
import 'dart:typed_data';

abstract interface class OnlineRepository {
  Future<Map<String, dynamic>?> businessSnapshot(String businessId);
  Future<Map<String, dynamic>> syncBusiness(
    String businessId,
    int revision,
    String operation,
    Map<String, dynamic> data,
  );
  Future<SalonBusiness?> findBusiness(String id, {bool barber = false});
  Future<List<Map<String, dynamic>>> reviews(
    String businessId, {
    String? employeeId,
  });
  Future<void> saveReview(
    String businessId,
    int rating,
    String body, {
    String? employeeId,
    String? id,
  });
  Future<void> deleteReview(String id);
  Future<List<Map<String, dynamic>>> media(String serviceId);
  Future<void> uploadMedia(
    String businessId,
    String serviceId,
    String kind,
    Uint8List bytes,
    String extension, {
    String? pairId,
  });
  Future<void> deleteMedia(String id, String path);
  Future<void> uploadProfilePhoto(Uint8List bytes, String extension);
  Future<String?> profilePhoto({String? barberId});
  Future<List<SalonStaff>> staff(String businessId);
  Future<List<SalonStaff>> team(String businessId);
  Future<void> reviewJoin(String employeeId, bool accept);
  Future<void> inviteEmployee(String businessId, String profileCode);
  Future<List<WorkContract>> contracts({String? employeeId});
  Future<EmployeeDashboardData> employeeDashboard();
  Future<void> proposeContract({
    required String employeeId,
    required String kind,
    required DateTime starts,
    DateTime? ends,
    required double salary,
    required double commission,
    required String terms,
  });
  Future<void> respondToContract(String id, bool accept);
  Future<void> releaseContract(String id, String reason);
  String? get userId;
  Stream<String?> get authChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<OnlineWorkspace> loadWorkspace();
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String cnic,
    required DateTime dateOfBirth,
    required DateTime workStartedOn,
  });
  Future<String> saveBusiness({
    String? id,
    required String name,
    required String phone,
    required String type,
    required String city,
    required String area,
    required String address,
  });
  Future<void> uploadBusinessPhoto(
    String businessId,
    Uint8List bytes,
    String extension,
  );
  Future<String?> businessPhoto(SalonBusiness business);
  Future<String> businessInvite(String businessId);
  Future<void> requestJoin(String code);
  Future<List<SalonJoinRequest>> joinRequests();
  Future<List<SalonBusiness>> discoverBusinesses({
    String search = '',
    int page = 0,
  });
  Future<List<SalonService>> services(
    String businessId, {
    bool includeInactive = false,
  });
  Future<void> saveService({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required String description,
    required double price,
    required bool isActive,
  });
}
