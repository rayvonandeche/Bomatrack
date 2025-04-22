part of 'add_property_bloc.dart';

abstract class AddPropertyState extends Equatable {
  const AddPropertyState();

  @override
  List<Object?> get props => [];
}

class AddPropertyInitial extends AddPropertyState {}

class AddPropertyLoading extends AddPropertyState {}

class AddPropertySuccess extends AddPropertyState {}

class AddPropertyFailure extends AddPropertyState {
  final String error;
  const AddPropertyFailure({required this.error});

  @override
  List<Object> get props => [error];
}