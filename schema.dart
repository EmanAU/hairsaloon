enum DiscountType { none, percent, amount }

enum ExpenseStatus { paid, unpaid }

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    required this.passwordHash,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String username;
  final String phone;
  final String passwordHash;
  final DateTime createdAt;
}

class ShopModel {
  const ShopModel({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.phoneNumber,
    required this.businessType,
    required this.city,
    required this.area,
    required this.address,
    this.logoUrl,
    required this.createdAt,
  });

  final String id;
  final String ownerId; // User.id
  final String businessName;
  final String phoneNumber;
  final String businessType;
  final String city;
  final String area;
  final String address;
  final String? logoUrl;
  final DateTime createdAt;
}

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.shopId,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.cnicNumber,
    required this.homeAddress,
    required this.isActive,
    this.photoUrl,
    this.speciality,
    this.employeeType,
    this.basicSalary,
    required this.commissionPercent,
    this.agreementDescription,
    required this.createdAt,
  });

  final String id;
  final String shopId; // Shop.id
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String cnicNumber;
  final String homeAddress;
  final bool isActive;
  final String? photoUrl;
  final String? speciality;
  final String? employeeType;
  final double? basicSalary;
  final double commissionPercent;
  final String? agreementDescription;
  final DateTime createdAt;
}

class EmployeeAssignmentModel {
  const EmployeeAssignmentModel({
    required this.id,
    required this.shopId,
    required this.employeeId,
    required this.assignedToEmployeeId,
  });

  final String id;
  final String shopId; // Shop.id
  final String employeeId; // Employee.id
  final String assignedToEmployeeId; // Employee.id
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.shopId,
    required this.name,
  });

  final String id;
  final String shopId; // Shop.id
  final String name;
}

class SubcategoryModel {
  const SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  final String id;
  final String categoryId; // Category.id
  final String name;
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.shopId,
    required this.subcategoryId,
    required this.name,
    required this.gender,
    required this.ageGroup,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String shopId; // Shop.id
  final String subcategoryId; // Subcategory.id
  final String name;
  final String gender;
  final String ageGroup;
  final double price;
  final bool isActive;
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String shopId; // Shop.id
  final String name;
  final String phone;
  final DateTime createdAt;
}

class BillModel {
  const BillModel({
    required this.id,
    required this.shopId,
    this.customerId,
    required this.employeeId,
    required this.customerName,
    required this.customerPhone,
    required this.employeeName,
    required this.commissionPercent,
    required this.paymentType,
    required this.subTotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.grandTotal,
    required this.createdAt,
  });

  final String id;
  final String shopId; // Shop.id
  final String? customerId; // Customer.id
  final String employeeId; // Employee.id
  final String customerName;
  final String customerPhone;
  final String employeeName;
  final double commissionPercent;
  final String paymentType;
  final double subTotal;
  final DiscountType discountType;
  final double discountValue;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double grandTotal;
  final DateTime createdAt;
}

class BillItemModel {
  const BillItemModel({
    required this.id,
    required this.billId,
    this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.unitPrice,
    required this.tag,
  });

  final String id;
  final String billId; // Bill.id
  final String? serviceId; // Service.id
  final String serviceName;
  final int quantity;
  final double unitPrice;
  final String tag;
}

class ShopExpenseModel {
  const ShopExpenseModel({
    required this.id,
    required this.shopId,
    this.employeeId,
    this.customerId,
    this.billId,
    required this.date,
    required this.amount,
    required this.status,
    required this.paymentType,
    this.expenseType,
    this.quantity,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String shopId; // Shop.id
  final String? employeeId; // Employee.id
  final String? customerId; // Customer.id
  final String? billId; // Bill.id
  final DateTime date;
  final double amount;
  final ExpenseStatus status;
  final String paymentType;
  final String? expenseType;
  final int? quantity;
  final String? description;
  final DateTime createdAt;
}

class EmployeePaymentModel {
  const EmployeePaymentModel({
    required this.id,
    required this.shopId,
    required this.employeeId,
    required this.amount,
    required this.bonusAmount,
    required this.paidAt,
    this.note,
  });

  final String id;
  final String shopId; // Shop.id
  final String employeeId; // Employee.id
  final double amount;
  final double bonusAmount;
  final DateTime paidAt;
  final String? note;
}

class EmployeePaymentAllocationModel {
  const EmployeePaymentAllocationModel({
    required this.id,
    required this.paymentId,
    required this.workDate,
    required this.incomeAmount,
  });

  final String id;
  final String paymentId; // EmployeePayment.id
  final DateTime workDate;
  final double incomeAmount;
}

class ShopSettingsModel {
  const ShopSettingsModel({
    required this.shopId,
    required this.taxPercent,
    required this.currencyCode,
    required this.specialistCategories,
  });

  final String shopId; // Shop.id
  final double taxPercent;
  final String currencyCode;
  final List<String> specialistCategories;
}
