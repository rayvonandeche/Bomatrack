import 'package:equatable/equatable.dart';

class Unit extends Equatable {
  final int id;
  final int floorId;
  final String unitNumber;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String organizationId;
  final int propertyId;

  const Unit({
    required this.id,
    required this.floorId,
    required this.unitNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.organizationId,
    required this.propertyId,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as int,
      floorId: json['floor_id'] as int,
      unitNumber: json['unit_number'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      organizationId: json['organization_id'] as String,
      propertyId: json['property_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'floor_id': floorId,
      'unit_number': unitNumber,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'organization_id': organizationId,
      'property_id': propertyId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        floorId,
        unitNumber,
        status,
        createdAt,
        updatedAt,
        organizationId,
        propertyId,
      ];
}
