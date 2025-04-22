import 'dart:convert';

class TenantDiscountGroup {
  final int id;
  final int tenantId;
  final String discountName;
  final String discountType;  // 'flat' or 'percentage'
  final double discountValue;
  final String organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for convenience (not directly from DB)
  final List<int>? unitIds;
  final List<String>? unitNumbers;
  final double? monthlyRent;

  TenantDiscountGroup({
    required this.id,
    required this.tenantId,
    required this.discountName,
    required this.discountType,
    required this.discountValue,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
    this.unitIds,
    this.unitNumbers,
    this.monthlyRent,
  });

  TenantDiscountGroup copyWith({
    int? id,
    int? tenantId,
    String? discountName,
    String? discountType,
    double? discountValue,
    String? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int>? unitIds,
    List<String>? unitNumbers,
    double? monthlyRent,
  }) {
    return TenantDiscountGroup(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      discountName: discountName ?? this.discountName,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unitIds: unitIds ?? this.unitIds,
      unitNumbers: unitNumbers ?? this.unitNumbers,
      monthlyRent: monthlyRent ?? this.monthlyRent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'discount_name': discountName,
      'discount_type': discountType,
      'discount_value': discountValue,
      'organization_id': organizationId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'unit_ids': unitIds,
      'unit_numbers': unitNumbers,
      'monthly_rent': monthlyRent,
    };
  }

  factory TenantDiscountGroup.fromMap(Map<String, dynamic> map) {
    return TenantDiscountGroup(
      id: map['id']?.toInt() ?? 0,
      tenantId: map['tenant_id']?.toInt() ?? 0,
      discountName: map['discount_name'] ?? '',
      discountType: map['discount_type'] ?? '',
      discountValue: double.tryParse(map['discount_value']?.toString() ?? '0') ?? 0.0,
      organizationId: map['organization_id'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      unitIds: map['unit_ids'] != null ? 
               (map['unit_ids'] is List ? 
                List<int>.from(map['unit_ids']) : 
                jsonDecode(map['unit_ids'])) : 
                null,
      unitNumbers: map['unit_numbers'] != null ? 
                  (map['unit_numbers'] is List ? 
                   List<String>.from(map['unit_numbers']) : 
                   jsonDecode(map['unit_numbers'])) : null,
      monthlyRent: double.tryParse(map['monthly_rent']?.toString() ?? '0') ?? 0.0,
    );
  }

  // For the function that returns a table
  factory TenantDiscountGroup.fromFunction(Map<String, dynamic> map) {
    return TenantDiscountGroup(
      id: map['group_id']?.toInt() ?? 0,
      tenantId: 0, // Not returned by the function
      discountName: map['group_name'] ?? '',
      discountType: map['discount_type'] ?? '',
      discountValue: double.tryParse(map['discount_value']?.toString() ?? '0') ?? 0.0,
      organizationId: '', // Not returned by the function
      createdAt: DateTime.now(), // Not returned by the function
      updatedAt: DateTime.now(), // Not returned by the function
      unitIds: map['unit_ids'] != null ? List<int>.from(map['unit_ids']) : null,
      unitNumbers: map['unit_numbers'] != null ? List<String>.from(map['unit_numbers']) : null,
      monthlyRent: double.tryParse(map['monthly_rent']?.toString() ?? '0') ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory TenantDiscountGroup.fromJson(String source) => 
      TenantDiscountGroup.fromMap(json.decode(source));

  @override
  String toString() {
    return 'TenantDiscountGroup(id: $id, tenantId: $tenantId, discountName: $discountName, discountType: $discountType, discountValue: $discountValue, unitNumbers: $unitNumbers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is TenantDiscountGroup &&
      other.id == id &&
      other.tenantId == tenantId &&
      other.discountName == discountName &&
      other.discountType == discountType &&
      other.discountValue == discountValue &&
      other.organizationId == organizationId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      tenantId.hashCode ^
      discountName.hashCode ^
      discountType.hashCode ^
      discountValue.hashCode ^
      organizationId.hashCode;
  }
}