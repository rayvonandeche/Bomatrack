part of 'add_tenant_bloc.dart';

abstract class AddTenantEvent extends Equatable {
  const AddTenantEvent();

  @override
  List<Object?> get props => [];
}

class AddTenantPressed extends AddTenantEvent {
  final String firstName;
  final String secondName;
  final String? email;
  final String phone;
  final String idNumber;
  final String emergencyContact;
  final List<int> unitIds;
  final int propertyId;
  final String startDate;
  final int? deposit;
  final int rent;

  const AddTenantPressed({
    required this.firstName,
    required this.secondName,
    required this.idNumber,
    required this.emergencyContact,
    required this.unitIds,
    required this.phone,
    required this.propertyId,
    required this.startDate,
    required this.rent,
    this.deposit,
    this.email,
  });

  @override
  List<Object?> get props => [
        firstName,
        secondName,
        email,
        phone,
        idNumber,
        emergencyContact,
        unitIds,
        propertyId,
        startDate,
        deposit,
        rent
      ];
}
