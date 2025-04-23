part of 'tenant_details_page_bloc.dart';

abstract class TenantDetailsPageState extends Equatable {
  const TenantDetailsPageState();

  @override
  List<Object> get props => [];
}

class TenantDetailsPageInitial extends TenantDetailsPageState {}

class TenantDetailsPageLoading extends TenantDetailsPageState {}

class TenantDetailsPageSuccess extends TenantDetailsPageState {}

class TenantDetailsPageError extends TenantDetailsPageState {
  final String error;

  const TenantDetailsPageError({required this.error});
  @override
  List<Object> get props => [error];
}
