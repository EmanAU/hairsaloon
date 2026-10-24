class BillLine {
  const BillLine({
    required this.serviceName,
    required this.price,
    this.qty = 1,
    this.tag = '',
  });

  final String serviceName;
  final int qty;
  final double price;
  final String tag;

  double get total => qty * price;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serviceName': serviceName,
      'qty': qty,
      'price': price,
      'tag': tag,
    };
  }

  factory BillLine.fromJson(Map<String, dynamic> json) {
    return BillLine(
      serviceName: (json['serviceName'] ?? '').toString(),
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      tag: (json['tag'] ?? '').toString(),
    );
  }
}

enum BillDiscountType {
  none,
  percent,
  amount;

  static BillDiscountType fromName(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return none;
  }
}

/// Bill amounts. Discount is capped at the subtotal and tax is charged on
/// the discounted amount.
class BillTotals {
  const BillTotals._({
    required this.subTotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.grandTotal,
  });

  factory BillTotals.compute({
    required double subTotal,
    required double taxPercent,
    BillDiscountType discountType = BillDiscountType.none,
    double discountValue = 0,
  }) {
    final safeSub = subTotal < 0 ? 0.0 : subTotal;
    final value = discountValue < 0 ? 0.0 : discountValue;
    final rawDiscount = switch (discountType) {
      BillDiscountType.none => 0.0,
      BillDiscountType.percent => safeSub * (value > 100 ? 100 : value) / 100,
      BillDiscountType.amount => value,
    };
    final discount = rawDiscount > safeSub ? safeSub : rawDiscount;
    final taxable = safeSub - discount;
    final tax = taxable * taxPercent / 100;
    return BillTotals._(
      subTotal: safeSub,
      discountAmount: discount,
      taxAmount: tax,
      grandTotal: taxable + tax,
    );
  }

  final double subTotal;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
}

class Bill {
  const Bill({
    required this.id,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.employeeName,
    required this.paymentType,
    required this.lines,
    required this.subTotal,
    required this.taxPercent,
    required this.taxAmount,
    required this.grandTotal,
    this.discountType = BillDiscountType.none,
    this.discountValue = 0,
    this.discountAmount = 0,
    this.employeeId,
  });

  final String id;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final String employeeName;
  final String? employeeId;
  final String paymentType;
  final List<BillLine> lines;
  final double subTotal;
  final double taxPercent;
  final double taxAmount;
  final double grandTotal;
  final BillDiscountType discountType;
  final double discountValue;
  final double discountAmount;

  bool get hasDiscount => discountAmount > 0;
  bool belongsToEmployee(String id, String name) =>
      employeeId?.trim().isNotEmpty == true
      ? employeeId == id
      : employeeName.trim().toLowerCase() == name.trim().toLowerCase();

  /// Shop discounts and tax never change an employee's service commission.
  double get commissionBase => subTotal < 0 ? 0 : subTotal;

  String get shortNumber => id.length > 6 ? id.substring(id.length - 6) : id;

  String get discountLabel => discountType == BillDiscountType.percent
      ? 'Discount (${_trim(discountValue)}%)'
      : 'Discount';

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'employeeName': employeeName,
      'employeeId': employeeId,
      'paymentType': paymentType,
      'lines': lines.map((line) => line.toJson()).toList(),
      'subTotal': subTotal,
      'taxPercent': taxPercent,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'discountType': discountType.name,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
    };
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List?) ?? const <dynamic>[];
    return Bill(
      id: (json['id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      customerName: (json['customerName'] ?? '').toString(),
      customerPhone: (json['customerPhone'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      employeeId: json['employeeId']?.toString(),
      paymentType: (json['paymentType'] ?? '').toString(),
      lines: rawLines
          .whereType<Map>()
          .map((line) => BillLine.fromJson(Map<String, dynamic>.from(line)))
          .toList(growable: false),
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0,
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      discountType: BillDiscountType.fromName(json['discountType']),
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
