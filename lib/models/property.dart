import 'package:equatable/equatable.dart';

class Property extends Equatable{
  final int id;
  final String name;
  final String address;
  final int totalUnits;
  final int availableUnits;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String organizationId;

  const Property(
      {required this.id,
      required this.name,
      required this.address,
      required this.totalUnits,
      required this.availableUnits,
      required this.createdAt,
      required this.updatedAt,
      required this.organizationId});

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      totalUnits: json['total_units'] as int,
      availableUnits: json['available_units'] as int,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      organizationId: json['organization_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'totalUnits': totalUnits,
      'availableUnits': availableUnits,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'organizationId': organizationId,
    };
  }

  static Property get empty {
    return Property(
      id: 0,
      name: '',
      address: '',
      totalUnits: 0,
      availableUnits: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      organizationId: '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    totalUnits,
    availableUnits,
    createdAt,
    updatedAt,
    organizationId,
  ];
}
