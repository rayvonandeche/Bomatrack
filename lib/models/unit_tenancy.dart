import 'package:equatable/equatable.dart';

class UnitTenancy extends Equatable {
  final int id;
  final int? unitId;
  final int? tenantId;
  final int? discountGroupId;
  final DateTime startDate;
  final DateTime? endDate;
  final double monthlyRent;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String organizationId;
  final int? propertyId;

  const UnitTenancy({
    required this.id,
    this.unitId,
    this.tenantId,
    this.discountGroupId,
    required this.startDate,
    this.endDate,
    required this.monthlyRent,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    required this.organizationId,
    this.propertyId,
  });

  // Factory constructor to create a `UnitTenancy` object from JSON
  factory UnitTenancy.fromJson(Map<String, dynamic> json) {
    return UnitTenancy(
      id: json['id'],
      unitId: json['unit_id'],
      tenantId: json['tenant_id'],
      discountGroupId: json['discount_group_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      monthlyRent: (json['monthly_rent'] as num).toDouble(),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      organizationId: json['organization_id'],
      propertyId: json['property_id'],
    );
  }

  // Method to convert a `UnitTenancy` object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_id': unitId,
      'tenant_id': tenantId,
      'discount_group_id': discountGroupId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'monthly_rent': monthlyRent,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'organization_id': organizationId,
      'property_id': propertyId,
    };
  }

  // Convenience method to create a list of `UnitTenancy` from JSON
  static List<UnitTenancy> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => UnitTenancy.fromJson(json)).toList();
  }

  // Convenience method to convert a list of `UnitTenancy` to JSON
  static List<Map<String, dynamic>> toJsonList(List<UnitTenancy> tenancies) {
    return tenancies.map((tenancy) => tenancy.toJson()).toList();
  }

  @override
  String toString() {
    return 'UnitTenancy(id: $id, unitId: $unitId, tenantId: $tenantId, discountGroupId: $discountGroupId, startDate: $startDate, endDate: $endDate, monthlyRent: $monthlyRent, status: $status, organizationId: $organizationId, propertyId: $propertyId)';
  }

  @override
  List<Object?> get props => [
        id,
        unitId,
        tenantId,
        discountGroupId,
        startDate,
        endDate,
        monthlyRent,
        status,
        createdAt,
        updatedAt,
        organizationId,
        propertyId,
      ];
}
