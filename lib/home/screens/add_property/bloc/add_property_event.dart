part of 'add_property_bloc.dart';

abstract class AddPropertyEvent extends Equatable {
  const AddPropertyEvent();

  @override
  List<Object?> get props => [];
}

class AddPropertyPressed extends AddPropertyEvent {
  final String propertyName;
  final String propertyAddress;
  final String floorCount;
  final String unitsPerFloor;
  final String? customFloorUnits;

  const AddPropertyPressed({
    required this.propertyName,
    required this.propertyAddress,
    required this.floorCount,
    required this.unitsPerFloor,
    this.customFloorUnits,
  });

  @override
  List<Object?> get props => [
        propertyName,
        propertyAddress,
        floorCount,
        unitsPerFloor,
        customFloorUnits,
      ];
}
