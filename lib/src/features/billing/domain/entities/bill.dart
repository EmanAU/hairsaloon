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
  });

  final String id;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final String employeeName;
  final String paymentType;
  final List<BillLine> lines;
  final double subTotal;
  final double taxPercent;
  final double taxAmount;
  final double grandTotal;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'employeeName': employeeName,
      'paymentType': paymentType,
      'lines': lines.map((line) => line.toJson()).toList(),
      'subTotal': subTotal,
      'taxPercent': taxPercent,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
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
      paymentType: (json['paymentType'] ?? '').toString(),
      lines: rawLines
          .whereType<Map>()
          .map((line) => BillLine.fromJson(Map<String, dynamic>.from(line)))
          .toList(growable: false),
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0,
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
