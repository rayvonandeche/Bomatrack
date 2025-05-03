part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHome extends HomeEvent {}

class HomeDataChanged extends HomeEvent {
  final List<Map<String, dynamic>> data;
  final String organizationId;
  final List<Map<String, dynamic>> initialActivityEvents;

  const HomeDataChanged(this.data, {
    this.organizationId = '',
    this.initialActivityEvents = const [],
  });

  @override
  List<Object?> get props => [data, organizationId, initialActivityEvents];

  List<Property> get properties => data.map((e) => Property.fromJson(e)).toList();
}

class RealtimeTableUpdated extends HomeEvent {
  final String tableName;
  final List<Map<String, dynamic>> data;
  
  const RealtimeTableUpdated(this.tableName, this.data);
  
  @override
  List<Object?> get props => [tableName, data];
}

class SelectProperty extends HomeEvent {
  final Property property;

  const SelectProperty(this.property);

  @override
  List<Object?> get props => [property];
}

class AddUnit extends HomeEvent {
  final int floorId;
  final String unitNumber;
  final int propertyId;

  const AddUnit({
    required this.floorId,
    required this.unitNumber,
    required this.propertyId,
  });

  @override
  List<Object?> get props => [floorId, unitNumber, propertyId];
}

class UpdateUnitStatus extends HomeEvent {
  final int unitId;
  final String newStatus;

  const UpdateUnitStatus({
    required this.unitId,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [unitId, newStatus];
}

class MarkActivityAsRead extends HomeEvent {
  final int eventId;

  const MarkActivityAsRead(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

