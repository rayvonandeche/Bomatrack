import 'package:equatable/equatable.dart';

class Tenant extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String phone;
  final String idNumber;
  final String emergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String organizationId;
  final int propertyId;

  const Tenant({
    required this.id,
    required this.firstName,
    required this.lastName,
     this.email,
    required this.phone,
    required this.idNumber,
    required this.emergencyContact,
    required this.createdAt,
    required this.updatedAt,
    required this.organizationId,
    required this.propertyId,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      idNumber: json['id_number'] as String,
      emergencyContact: json['emergency_contact'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      organizationId: json['organization_id'] as String,
      propertyId: json['property_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'id_number': idNumber,
      'emergency_contact': emergencyContact,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'organization_id': organizationId,
      'property_id': propertyId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        phone,
        idNumber,
        emergencyContact,
        createdAt,
        updatedAt,
        organizationId,
        propertyId,
      ];
}
