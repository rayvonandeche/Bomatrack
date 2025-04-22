part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> data2;
  final List<Map<String, dynamic>> data3;
  final List<Map<String, dynamic>> data4;
  final List<Map<String, dynamic>> data5;
  final List<Map<String, dynamic>> data6;
  final List<Map<String, dynamic>> data7; // Discount groups
  final Property? selectedProperty;

  const HomeLoaded(
      this.data, this.data2, this.data3, this.data4, this.data5, this.data6, this.data7,
      {this.selectedProperty});

  @override
  List<Object?> get props => [data, data2, data3, data4, data5, data6, data7, selectedProperty];

  List<Property> get properties =>
      data.map((e) => Property.fromJson(e)).toList();
  List<Floor> get floors => data2.map((e) => Floor.fromJson(e)).toList();
  List<Unit> get units => data3.map((e) => Unit.fromJson(e)).toList();
  List<Tenant> get tenants => data4.map((e) => Tenant.fromJson(e)).toList();
  List<UnitTenancy> get unitTenancies => data5.map((e) => UnitTenancy.fromJson(e)).toList();
  List<Payment> get payments => data6.map((e) => Payment.fromJson(e)).toList();
  List<TenantDiscountGroup> get discountGroups => 
      data7.map((e) => TenantDiscountGroup.fromMap(e)).toList();
}

class HomeError extends HomeState {
  final String error;
  const HomeError({required this.error});

  @override
  List<Object> get props => [error];
}

class PropertyLoading extends HomeEvent {}

class PropertyError extends HomeEvent {
  final String error;
  const PropertyError({required this.error});

  @override
  List<Object> get props => [error];
}
