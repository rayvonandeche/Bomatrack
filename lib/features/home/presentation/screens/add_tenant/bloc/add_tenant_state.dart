part of 'add_tenant_bloc.dart';

abstract class AddTenantState extends Equatable {
  const AddTenantState();

  @override
  List<Object?> get props => [];
}

class AddTenantInitial extends AddTenantState {}

class AddTenantLoading extends AddTenantState {}

class AddTenantError extends AddTenantState {
  final String error;

  const AddTenantError({required this.error});

  @override
  List<Object?> get props => [error];
}

class AddTenantSuccess extends AddTenantState {}