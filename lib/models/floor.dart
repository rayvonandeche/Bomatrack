import 'package:equatable/equatable.dart';

/// Model representing a floor in a property
class Floor extends  Equatable{
  final int id;
  final int propertyId;
  final int floorNumber;
  final String floorName;
  final int totalUnits;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String organizationId;

  const Floor(
      {required this.id,
      required this.propertyId,
      required this.floorNumber,
      required this.floorName,
      required this.totalUnits,
      required this.createdAt,
      required this.updatedAt,
      required this.organizationId});

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      floorNumber: json['floor_number'] as int,
      floorName: json['floor_name'] as String,
      totalUnits: json['total_units'] as int,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      organizationId: json['organization_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'floor_number': floorNumber,
      'floor_name': floorName,
      'total_units': totalUnits,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get totalunits => totalUnits;

  bool get isGroundFloor => floorName.startsWith('A');

 @override
 List<Object> get props => [id, propertyId, floorNumber, floorName, totalUnits, createdAt, updatedAt, organizationId];
}
