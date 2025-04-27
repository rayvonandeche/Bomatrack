part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<dynamic> data;
  final List<dynamic> data2;
  final List<dynamic> data3;
  final List<dynamic> data4;
  final List<dynamic> data5;
  final List<dynamic> data6;
  final List<dynamic> data7;
  final List<dynamic> data8;

  final Property? selectedProperty;

  const HomeLoaded(
      this.data,
      this.data2,
      this.data3,
      this.data4,
      this.data5,
      this.data6,
      this.data7,
      this.data8, {
        this.selectedProperty,
      });

  List<Property> get properties {
    return data.map((e) => Property.fromJson(e)).toList();
  }

  List<Floor> get floors {
    return data2.map((e) => Floor.fromJson(e)).toList();
  }

  List<Unit> get units {
    return data3.map((e) => Unit.fromJson(e)).toList();
  }

  List<Tenant> get tenants {
    return data4.map((e) => Tenant.fromJson(e)).toList();
  }

  List<UnitTenancy> get unitTenancies {
    return data5.map((e) => UnitTenancy.fromJson(e)).toList();
  }

  List<Payment> get payments {
    return data6.map((e) => Payment.fromJson(e)).toList();
  }

  List<TenantDiscountGroup> get discountGroups {
    return data7.map((e) => TenantDiscountGroup.fromJson(e)).toList();
  }
  
  List<ActivityEvent> get activityEvents {
    // Ensure each dynamic element is cast to Map<String, dynamic>
    return data8
        .map((e) => ActivityEvent.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList();
  }

  @override
  List<Object?> get props =>
      [data, data2, data3, data4, data5, data6, data7, data8, selectedProperty];
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
