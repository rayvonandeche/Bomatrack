part of 'tenant_details_page_bloc.dart';

abstract class TenantDetailsPageEvent extends Equatable {
  const TenantDetailsPageEvent();

  @override
  List<Object?> get props => [];
}

class AddPaymentPressed extends TenantDetailsPageEvent {
  final int tenantId;
  final int amount;
  final String paymentDate;
  final String paymentMethod;
  final String referenceNumber;
  final String? description;
  final List<int> pendingPaymentId;

  const AddPaymentPressed({
    required this.tenantId,
    required this.pendingPaymentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.referenceNumber,
    this.description,
  });

  @override
  List<Object?> get props => [
        tenantId,
        pendingPaymentId,
        amount,
        paymentDate,
        paymentMethod,
        referenceNumber,
        description,
      ];
}

class RemoveTenantPressed extends TenantDetailsPageEvent {
  final int tenantId;

  const RemoveTenantPressed({
    required this.tenantId,
  });

  @override
  List<Object?> get props => [tenantId];
}

class RemoveUnitPressed extends TenantDetailsPageEvent {
  final int unitId;
  final int newMonthlyRent;

  const RemoveUnitPressed({
    required this.unitId,
    required this.newMonthlyRent,
  });

  @override
  List<Object?> get props => [unitId, newMonthlyRent];
}

class AddUnitPressed extends TenantDetailsPageEvent {
  final int tenantId;
  final int unitId;
  final int monthlyRent;
  final String startDate;

  const AddUnitPressed({
    required this.tenantId,
    required this.unitId,
    required this.monthlyRent,
    required this.startDate,
  });

  @override
  List<Object?> get props => [tenantId, unitId, monthlyRent, startDate];
}

class ChangeUnitPressed extends TenantDetailsPageEvent {
  final int tenantId;
  final int oldUnitId;
  final int newUnitId;
  final int monthlyRent;
  final String startDate;

  const ChangeUnitPressed({
    required this.tenantId,
    required this.oldUnitId,
    required this.newUnitId,
    required this.monthlyRent,
    required this.startDate,
  });

  @override
  List<Object?> get props => [tenantId, oldUnitId, newUnitId, monthlyRent, startDate];
}

class CreateBundledUnitsPressed extends TenantDetailsPageEvent {
  final int tenantId;
  final List<int> unitIds;
  final String discountName;
  final String discountType;
  final double discountValue;
  final double monthlyRent;
  final String startDate;

  const CreateBundledUnitsPressed({
    required this.tenantId,
    required this.unitIds,
    required this.discountName,
    required this.discountType,
    required this.discountValue,
    required this.monthlyRent,
    required this.startDate,
  });

  @override
  List<Object?> get props => [
        tenantId,
        unitIds,
        discountName,
        discountType,
        discountValue,
        monthlyRent,
        startDate,
      ];
}
