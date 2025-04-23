import 'package:equatable/equatable.dart';
import 'dart:convert';

class Payment extends Equatable {
  final int id;
  final int? unitTenancyId;
  final double amount;
  final DateTime? paymentDate;
  final DateTime dueDate;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? organizationId;
  final int? propertyId;
  final bool? isBundlePayment;
  final int? discountGroupId;

  const Payment({
    required this.id,
    this.unitTenancyId,
    required this.amount,
    this.paymentDate,
    required this.dueDate,
    this.paymentStatus,
    this.paymentMethod,
    this.referenceNumber,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.organizationId,
    this.propertyId,
    this.isBundlePayment,
    this.discountGroupId,
  });

  Payment copyWith({
    int? id,
    int? unitTenancyId,
    double? amount,
    DateTime? paymentDate,
    DateTime? dueDate,
    String? paymentStatus,
    String? paymentMethod,
    String? referenceNumber,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationId,
    int? propertyId,
    bool? isBundlePayment,
    int? discountGroupId,
  }) {
    return Payment(
      id: id ?? this.id,
      unitTenancyId: unitTenancyId ?? this.unitTenancyId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      dueDate: dueDate ?? this.dueDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizationId: organizationId ?? this.organizationId,
      propertyId: propertyId ?? this.propertyId,
      isBundlePayment: isBundlePayment ?? this.isBundlePayment,
      discountGroupId: discountGroupId ?? this.discountGroupId,
    );
  }

  factory Payment.fromJson(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int,
      unitTenancyId: map['unit_tenancy_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['payment_date'] != null
          ? DateTime.parse(map['payment_date'])
          : null,
      dueDate: DateTime.parse(map['due_date']),
      paymentStatus: map['payment_status'] as String?,
      paymentMethod: map['payment_method'] as String?,
      referenceNumber: map['reference_number'] as String?,
      description: map['description'] as String?,
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      organizationId: map['organization_id'] as String,
      propertyId: map['property_id'] as int?,
      isBundlePayment: map['is_bundle_payment'] ?? false,
      discountGroupId: map['discount_group_id']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_tenancy_id': unitTenancyId,
      'amount': amount,
      'payment_date': paymentDate?.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'organization_id': organizationId,
      'property_id': propertyId,
      'is_bundle_payment': isBundlePayment,
      'discount_group_id': discountGroupId,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory Payment.fromJsonString(String source) => Payment.fromJson(json.decode(source));

  @override
  List<Object?> get props => [
        id,
        unitTenancyId,
        amount,
        paymentDate,
        dueDate,
        paymentStatus,
        paymentMethod,
        referenceNumber,
        description,
        createdAt,
        updatedAt,
        organizationId,
        propertyId,
        isBundlePayment,
        discountGroupId,
      ];

  @override
  String toString() {
    return 'Payment(id: $id, unitTenancyId: $unitTenancyId, amount: $amount, dueDate: $dueDate, paymentDate: $paymentDate, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, referenceNumber: $referenceNumber, description: $description, isBundlePayment: $isBundlePayment, discountGroupId: $discountGroupId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Payment &&
      other.id == id &&
      other.unitTenancyId == unitTenancyId &&
      other.amount == amount &&
      other.dueDate == dueDate &&
      other.paymentDate == paymentDate &&
      other.paymentStatus == paymentStatus &&
      other.paymentMethod == paymentMethod &&
      other.referenceNumber == referenceNumber &&
      other.description == description &&
      other.isBundlePayment == isBundlePayment &&
      other.discountGroupId == discountGroupId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      unitTenancyId.hashCode ^
      amount.hashCode ^
      dueDate.hashCode ^
      paymentDate.hashCode ^
      paymentStatus.hashCode ^
      paymentMethod.hashCode ^
      referenceNumber.hashCode ^
      description.hashCode ^
      isBundlePayment.hashCode ^
      discountGroupId.hashCode;
  }
}
