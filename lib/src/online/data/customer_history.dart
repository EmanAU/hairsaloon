import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/online_models.dart';

class ScannedSalon {
  const ScannedSalon(this.business, this.scans, this.lastScanned);
  final SalonBusiness business;
  final int scans;
  final DateTime lastScanned;
  Map<String, dynamic> toJson() => {
    'business': {
      'id': business.id,
      'name': business.name,
      'phone': business.phone,
      'business_type': business.type,
      'city': business.city,
      'area': business.area,
      'address': business.address,
      'is_active': business.isActive,
      'logo_path': business.logoPath,
    },
    'scans': scans,
    'last_scanned': lastScanned.toIso8601String(),
  };
}

/// QR scan history on this device, isolated by the signed-in account.
/// Scanning is not proof of a completed appointment.
class CustomerHistory {
  CustomerHistory(this.userId);
  final String userId;
  String get _key => 'customer_scan_history_v1_$userId';
  Future<List<ScannedSalon>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final rows = <ScannedSalon>[];
    for (final raw in preferences.getStringList(_key) ?? <String>[]) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        rows.add(
          ScannedSalon(
            SalonBusiness.fromJson(
              Map<String, dynamic>.from(data['business'] as Map),
            ),
            data['scans'] as int,
            DateTime.parse(data['last_scanned'] as String),
          ),
        );
      } catch (_) {
        /* Skip an incomplete local entry. */
      }
    }
    rows.sort((a, b) => b.lastScanned.compareTo(a.lastScanned));
    return rows;
  }

  Future<void> record(SalonBusiness business) async {
    final rows = await load();
    final previous = rows
        .where((r) => r.business.id == business.id)
        .firstOrNull;
    rows.removeWhere((r) => r.business.id == business.id);
    rows.insert(
      0,
      ScannedSalon(business, (previous?.scans ?? 0) + 1, DateTime.now()),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      rows.take(100).map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
