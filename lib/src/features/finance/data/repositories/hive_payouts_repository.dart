import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HivePayoutsRepository {
  HivePayoutsRepository({Box<Map>? box})
    : _box = box ?? Hive.box<Map>(HiveBoxes.employeePayouts);

  final Box<Map> _box;

  List<SalaryPayout> getAll() {
    final values = _box.values
        .map((raw) => SalaryPayout.fromMap(Map<String, dynamic>.from(raw)))
        .where((p) => p.id.isNotEmpty)
        .toList(growable: false);
    values.sort((a, b) => b.settledAt.compareTo(a.settledAt));
    return values;
  }

  Future<void> saveAll(List<SalaryPayout> payouts) async {
    await _box.putAll(<String, Map>{
      for (final p in payouts) p.id: p.toMap(),
    });
  }
}
