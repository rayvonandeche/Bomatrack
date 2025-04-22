import 'package:bomatrack/config/config.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'add_tenant_event.dart';
part 'add_tenant_state.dart';

final supabase = SupabaseConfig.supabase;

class AddTenantBloc extends Bloc<AddTenantEvent, AddTenantState> {
  AddTenantBloc() : super(AddTenantInitial()) {
    on<AddTenantPressed>(_onAddTenantPressed);
  }

  Future<void> _onAddTenantPressed(
      AddTenantPressed event, Emitter<AddTenantState> emit) async {
    try {
      emit(AddTenantLoading());
      await supabase.rpc('create_unit_tenancy', params: {
        'p_property_id': event.propertyId,
        'p_unit_ids': event.unitIds,
        'p_first_name': event.firstName,
        'p_last_name': event.secondName,
        'p_email': event.email?.trim(),
        'p_phone': event.phone,
        'p_id_number': event.idNumber,
        'p_emergency_contact': event.emergencyContact,
        'p_start_date': event.startDate,
        'p_monthly_rent': event.rent,
      });
      emit(AddTenantSuccess());
    } on PostgrestException catch (e) {
      emit(AddTenantError(error: e.message));
    } catch (e) {
      emit(const AddTenantError(error: 'An error occurred'));
    }
  }
}
