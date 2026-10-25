import 'dart:convert';
import '../../features/billing/domain/entities/bill.dart';
import '../../features/finance/domain/entities/salary_payout.dart';

enum AppAudience { business, customer }

class OnlineFailure implements Exception {
  const OnlineFailure(this.message);
  final String message;
}

/// Primary data was saved, but a photo upload failed afterward.
class PhotoUploadFailure extends OnlineFailure {
  const PhotoUploadFailure([
    super.message =
        'Details were saved, but the photo could not be uploaded. Try again.',
  ]);
}

class SalonStaff {
  const SalonStaff({
    required this.id,
    required this.name,
    required this.isWorking,
    this.joinStatus = 'accepted',
    this.isManager = false,
    this.phone = '',
    this.cnic = '',
    this.isActive = true,
    this.localEmployeeId,
    this.requestedAt,
  });
  final String id;
  final String name;
  final bool isWorking;
  final String joinStatus;
  final bool isManager;
  final String phone;
  final String cnic;
  final bool isActive;
  final String? localEmployeeId;
  final DateTime? requestedAt;
  factory SalonStaff.fromJson(Map<String, dynamic> json) => SalonStaff(
    id: json['membership_id'] as String,
    name: json['display_name'] as String,
    isWorking: json['is_working'] as bool,
    joinStatus: json['join_status'] as String? ?? 'accepted',
    isManager: json['is_manager'] as bool? ?? false,
    phone: json['phone'] as String? ?? '',
    cnic: json['cnic'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    localEmployeeId: json['local_employee_id'] as String?,
    requestedAt: DateTime.tryParse(json['join_requested_at']?.toString() ?? ''),
  );
}

/// Owner-visible invite row (pending / declined / accepted).
class OwnerEmployeeInvite {
  const OwnerEmployeeInvite({
    required this.id,
    required this.businessId,
    required this.displayName,
    required this.cnic,
    required this.phone,
    required this.email,
    required this.status,
  });
  final String id;
  final String businessId;
  final String displayName;
  final String cnic;
  final String phone;
  final String email;
  final String status;

  factory OwnerEmployeeInvite.fromJson(Map<String, dynamic> json) =>
      OwnerEmployeeInvite(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        cnic: json['cnic'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );
}

class PendingEmployeeInvite {
  const PendingEmployeeInvite({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerName,
    required this.cnic,
    required this.phone,
    required this.email,
  });
  final String id;
  final String businessId;
  final String businessName;
  final String ownerName;
  final String cnic;
  final String phone;
  final String email;

  factory PendingEmployeeInvite.fromJson(Map<String, dynamic> json) =>
      PendingEmployeeInvite(
        id: json['invite_id'] as String,
        businessId: json['business_id'] as String,
        businessName: json['business_name'] as String? ?? 'Salon',
        ownerName: json['owner_name'] as String? ?? 'Owner',
        cnic: json['cnic'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class ManagerBusiness {
  const ManagerBusiness({
    required this.businessId,
    required this.businessName,
    required this.membershipId,
  });
  final String businessId;
  final String businessName;
  final String membershipId;

  factory ManagerBusiness.fromJson(Map<String, dynamic> json) =>
      ManagerBusiness(
        businessId: json['business_id'] as String,
        businessName: json['business_name'] as String? ?? 'Salon',
        membershipId: json['membership_id'] as String,
      );
}

class SalonJoinRequest {
  const SalonJoinRequest({
    required this.id,
    required this.businessName,
    required this.status,
    this.businessId = '',
    this.isActive = true,
  });
  final String id, businessName, status;
  final String businessId;
  final bool isActive;
  factory SalonJoinRequest.fromJson(Map<String, dynamic> json) =>
      SalonJoinRequest(
        id: json['id'] as String,
        businessName:
            (json['businesses'] as Map?)?['name'] as String? ??
            'Salon unavailable',
        status: json['join_status'] as String,
        businessId: json['business_id'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class WorkContract {
  const WorkContract({
    required this.id,
    required this.employeeId,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.salary,
    required this.commission,
    required this.terms,
    this.businessId = '',
    this.businessName = 'Salon unavailable',
    this.releaseReason,
    this.createdAt,
    this.releasedAt,
  });
  final String id;
  final String employeeId;
  final String businessId;
  final String kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String status;
  final double salary;
  final double commission;
  final String terms;
  final String businessName;
  final String? releaseReason;
  final DateTime? createdAt;
  final DateTime? releasedAt;

  bool get isLive => displayStatus == 'active';

  bool get canRelease =>
      status == 'accepted' &&
      (endsAt == null || endsAt!.isAfter(DateTime.now()));
  bool get endingSoon =>
      canRelease &&
      endsAt != null &&
      endsAt!.difference(DateTime.now()) <= const Duration(days: 7);
  String get displayStatus {
    if (status != 'accepted') return status;
    if (endsAt != null && !endsAt!.isAfter(DateTime.now())) return 'expired';
    return startsAt.isAfter(DateTime.now()) ? 'scheduled' : 'active';
  }

  factory WorkContract.fromJson(Map<String, dynamic> json) {
    final membership = json['business_employees'] as Map?;
    return WorkContract(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      businessId: membership?['business_id'] as String? ?? '',
      kind: json['kind'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      status: json['status'] as String,
      salary: (json['salary'] as num).toDouble(),
      commission: (json['commission_percent'] as num).toDouble(),
      terms: json['terms'] as String,
      businessName:
          (membership?['businesses'] as Map?)?['name'] as String? ??
          'Salon unavailable',
      releaseReason: json['release_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      releasedAt: DateTime.tryParse(json['released_at']?.toString() ?? ''),
    );
  }
}

/// One billed job attributed to the signed-in employee.
class EmployeeWorkJob {
  const EmployeeWorkJob({
    required this.id,
    required this.createdAt,
    required this.customerName,
    required this.total,
    required this.services,
    required this.businessName,
    required this.commissionPercent,
    this.bill,
  });
  final String id;
  final DateTime createdAt;
  final String customerName;
  final double total;
  final List<String> services;
  final String businessName;
  final double commissionPercent;
  final Bill? bill;
  double get commissionBase => bill?.commissionBase ?? total;
  String get paymentType => bill?.paymentType ?? 'Unspecified';

  double get earning => double.parse(
    (commissionBase * commissionPercent / 100).toStringAsFixed(2),
  );
}

class EmployeeDayWork {
  const EmployeeDayWork({
    required this.date,
    required this.jobs,
    this.payments = const [],
  });
  final DateTime date;
  final List<EmployeeWorkJob> jobs;
  final List<EmployeePayment> payments;
  double get paid =>
      payments.fold<double>(0, (sum, payment) => sum + payment.payout.amount);
  double get bonus => payments.fold<double>(
    0,
    (sum, payment) => sum + payment.payout.bonusAmount,
  );
  double get due => double.parse(
    (earning - (paid - bonus)).clamp(0, double.infinity).toStringAsFixed(2),
  );
  String get settlementStatus => payments.isEmpty
      ? 'Pending'
      : due == 0
      ? 'Paid'
      : 'Partially paid';

  double get sales => jobs.fold<double>(0, (sum, job) => sum + job.total);
  double get earning => double.parse(
    jobs
        .fold<double>(
          0,
          (sum, job) => sum + job.commissionBase * job.commissionPercent / 100,
        )
        .toStringAsFixed(2),
  );
  int get jobCount => jobs.length;
}

class EmployeePayment {
  const EmployeePayment({
    required this.businessId,
    required this.businessName,
    required this.payout,
  });
  final String businessId;
  final String businessName;
  final SalaryPayout payout;
}

class EmployeeNotice {
  const EmployeeNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.payment,
  });
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final EmployeePayment? payment;
}

class EmployeeDashboardData {
  const EmployeeDashboardData({
    required this.contracts,
    required this.joinRequests,
    required this.days,
    this.payments = const [],
  });
  final List<EmployeePayment> payments;
  final List<WorkContract> contracts;
  final List<SalonJoinRequest> joinRequests;
  final List<EmployeeDayWork> days;

  factory EmployeeDashboardData.fromHistory({
    required List<WorkContract> contracts,
    required List<SalonJoinRequest> joinRequests,
    required List<dynamic> rows,
  }) {
    final jobs = <EmployeeWorkJob>[];
    final payments = <EmployeePayment>[];
    for (final raw in rows.whereType<Map>()) {
      final businessId = raw['businessId'].toString();
      final businessName = raw['businessName']?.toString() ?? 'Salon';
      final fallback =
          double.tryParse(raw['commission']?.toString() ?? '') ?? 0;
      for (final item in (raw['bills'] as List? ?? []).whereType<Map>()) {
        final bill = Bill.fromJson({
          ...Map<String, dynamic>.from(item),
          'id': '$businessId:${item['id']}',
        });
        final applicable =
            contracts
                .where(
                  (c) =>
                      c.businessId == businessId &&
                      !bill.createdAt.isBefore(c.startsAt) &&
                      (c.endsAt == null ||
                          bill.createdAt.isBefore(c.endsAt!)) &&
                      (c.releasedAt == null ||
                          bill.createdAt.isBefore(c.releasedAt!)) &&
                      (c.status == 'accepted' || c.status == 'released'),
                )
                .toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        jobs.add(
          EmployeeWorkJob(
            id: bill.id,
            createdAt: bill.createdAt.toLocal(),
            customerName: bill.customerName,
            total: bill.grandTotal,
            services: bill.lines.map((l) => l.serviceName).toList(),
            businessName: businessName,
            commissionPercent: applicable.firstOrNull?.commission ?? fallback,
            bill: bill,
          ),
        );
      }
      for (final item in (raw['payouts'] as List? ?? []).whereType<Map>()) {
        payments.add(
          EmployeePayment(
            businessId: businessId,
            businessName: businessName,
            payout: SalaryPayout.fromMap(Map<String, dynamic>.from(item)),
          ),
        );
      }
    }
    DateTime day(DateTime time) {
      final local = time.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final dates = {
      ...jobs.map((j) => day(j.createdAt)),
      ...payments.map((p) => day(p.payout.workDate)),
    }.toList()..sort((a, b) => b.compareTo(a));
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return EmployeeDashboardData(
      contracts: contracts,
      joinRequests: joinRequests,
      payments: payments,
      days: dates
          .map(
            (date) => EmployeeDayWork(
              date: date,
              jobs: jobs.where((j) => day(j.createdAt) == date).toList(),
              payments: payments
                  .where((p) => day(p.payout.workDate) == date)
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  List<EmployeeNotice> get notifications {
    final notices = <EmployeeNotice>[
      for (final payment in payments)
        EmployeeNotice(
          id: 'payment:${payment.businessId}:${payment.payout.id}:${payment.payout.amount}:${payment.payout.settledAt.toIso8601String()}',
          title: 'Payment recorded',
          message:
              '${payment.businessName} paid Rs ${payment.payout.amount.toStringAsFixed(0)} for ${payment.payout.workDate.day}/${payment.payout.workDate.month}/${payment.payout.workDate.year}.',
          date: payment.payout.settledAt,
          payment: payment,
        ),
      for (final contract in contracts)
        EmployeeNotice(
          id: 'contract:${contract.id}:${contract.status}',
          title: contract.status == 'released'
              ? 'Contract ended'
              : 'Contract saved',
          message:
              '${contract.businessName} · ${contract.commission.toStringAsFixed(0)}% commission · ${contract.displayStatus}',
          date: contract.releasedAt ?? contract.createdAt ?? contract.startsAt,
        ),
    ];
    return notices..sort((a, b) => b.date.compareTo(a.date));
  }

  List<WorkContract> get liveContracts =>
      contracts.where((c) => c.isLive).toList();

  /// Contracts set by the owner that have not started yet (notify-only).
  List<WorkContract> get notifiedContracts => contracts
      .where((c) => c.status == 'accepted' && c.displayStatus == 'scheduled')
      .toList();

  @Deprecated('Owner sets contracts; employees no longer accept drafts')
  List<WorkContract> get draftContracts => const [];
}

class OnlineAccount {
  const OnlineAccount({required this.id, required this.name});
  final String id;
  final String name;
}

class PersonalProfile {
  const PersonalProfile({
    required this.code,
    required this.phone,
    this.cnic,
    this.dateOfBirth,
    this.workStartedOn,
    this.photoPath,
  });
  final String code;
  final String phone;
  final String? cnic;
  final DateTime? dateOfBirth;
  final DateTime? workStartedOn;
  final String? photoPath;

  bool get isComplete =>
      phone.isNotEmpty &&
      (cnic?.length == 13) &&
      dateOfBirth != null &&
      workStartedOn != null &&
      (photoPath?.isNotEmpty ?? false);

  String experienceAt(DateTime today) {
    final start = workStartedOn;
    if (start == null || start.isAfter(today)) return 'Not set';
    var months = (today.year - start.year) * 12 + today.month - start.month;
    if (today.day < start.day) months--;
    if (months <= 0) return 'Less than a month';
    final years = months ~/ 12;
    final remaining = months % 12;
    return [
      if (years > 0) '$years ${years == 1 ? 'year' : 'years'}',
      if (remaining > 0) '$remaining ${remaining == 1 ? 'month' : 'months'}',
    ].join(' ');
  }

  factory PersonalProfile.fromJson(Map<String, dynamic> json) =>
      PersonalProfile(
        code: json['code'] as String,
        phone: json['phone'] as String,
        cnic: json['cnic'] as String?,
        dateOfBirth: DateTime.tryParse(json['date_of_birth'] as String? ?? ''),
        workStartedOn: DateTime.tryParse(
          json['work_started_on'] as String? ?? '',
        ),
        photoPath: json['photo_path'] as String?,
      );
}

class SalonBusiness {
  const SalonBusiness({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.city,
    required this.area,
    required this.address,
    required this.isActive,
    this.logoPath,
  });
  final String id;
  final String name;
  final String phone;
  final String type;
  final String city;
  final String area;
  final String address;
  final bool isActive;
  final String? logoPath;

  factory SalonBusiness.fromJson(Map<String, dynamic> json) => SalonBusiness(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    type: json['business_type'] as String,
    city: json['city'] as String,
    area: json['area'] as String,
    address: json['address'] as String,
    isActive: json['is_active'] as bool,
    logoPath: json['logo_path'] as String?,
  );
}

class BusinessSettings {
  const BusinessSettings({
    required this.taxRate,
    required this.currencyCode,
    required this.expenseTypes,
    required this.paymentAccounts,
  });

  final double taxRate;
  final String currencyCode;
  final List<String> expenseTypes;
  final List<String> paymentAccounts;

  factory BusinessSettings.fromJson(Map<String, dynamic> json) =>
      BusinessSettings(
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 17,
        currencyCode:
            (json['currency_code'] as String?)?.trim().isNotEmpty == true
            ? (json['currency_code'] as String).trim().toUpperCase()
            : 'PKR',
        expenseTypes: _stringList(json['expense_types']),
        paymentAccounts: _stringList(json['payment_accounts']),
      );

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}

class OnlineWorkspace {
  const OnlineWorkspace({
    required this.account,
    this.profile,
    this.businesses = const [],
    this.isCached = false,
  });
  final OnlineAccount account;
  final PersonalProfile? profile;
  final List<SalonBusiness> businesses;
  final bool isCached;
}

class SalonService {
  const SalonService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isActive = true,
    this.contentJson = const <dynamic>[],
  });
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isActive;

  /// Flutter Quill Delta JSON (list of ops).
  final List<dynamic> contentJson;

  bool get hasRichContent {
    if (contentJson.isEmpty) return false;
    // Empty docs are often [{"insert":"\n"}].
    final text = contentJson
        .whereType<Map>()
        .map((op) => op['insert'])
        .whereType<String>()
        .join()
        .trim();
    return text.isNotEmpty;
  }

  factory SalonService.fromJson(Map<String, dynamic> json) {
    return SalonService(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      isActive: json['is_active'] as bool? ?? true,
      contentJson: _parseContentJson(json['content_json']),
    );
  }

  /// Quill Delta ops list; keeps bold/italic/underline/list attributes intact.
  static List<dynamic> _parseContentJson(Object? raw) {
    Object? value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    if (value is Map && value['ops'] is List) {
      value = value['ops'];
    }
    if (value is! List) return const [];
    final ops = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) continue;
      final op = <String, dynamic>{
        for (final e in item.entries) e.key.toString(): e.value,
      };
      if (op['attributes'] is Map) {
        final attrs = op['attributes'] as Map;
        op['attributes'] = <String, dynamic>{
          for (final e in attrs.entries) e.key.toString(): e.value,
        };
      }
      if (op.containsKey('insert')) ops.add(op);
    }
    return ops;
  }
}
