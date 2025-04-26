import 'package:bomatrack/core/config/config.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'add_property_state.dart';
part 'add_property_event.dart';

final supabase = SupabaseConfig.supabase;

class AddPropertyBloc extends Bloc<AddPropertyEvent, AddPropertyState> {
  AddPropertyBloc() : super(AddPropertyInitial()) {
    on<AddPropertyPressed>(_onAddPropertyPressed);
  }

  Future<void> _onAddPropertyPressed(
      AddPropertyPressed event, Emitter<AddPropertyState> emit) async {
    emit(AddPropertyLoading());
    try {
      await supabase.rpc(
        'create_property',
        params: {
          'property_name': event.propertyName,
          'property_address': event.propertyAddress,
          'f_count': event.floorCount,
          'start_f': 1,
          'units_p_floor': event.unitsPerFloor,
          'custom_f_units': event.customFloorUnits,
        },
      );
      emit(AddPropertySuccess());
    } on PostgrestException catch (e) {
      emit(AddPropertyFailure(error: e.message));
    } catch (e) {
      emit(AddPropertyFailure(error: e.toString()));
    }
  }
}
