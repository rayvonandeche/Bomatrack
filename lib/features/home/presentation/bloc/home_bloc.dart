import 'dart:async';

import 'package:bomatrack/core/config/config.dart';
import 'package:bomatrack/models/models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'home_event.dart';
part 'home_state.dart';

final supabase = SupabaseConfig.supabase;

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<LoadHome>(_onLoadHome);
    on<HomeDataChanged>(_onHomeDataChanged);
    on<SelectProperty>(_onSelectProperty);
    on<AddUnit>(_onAddUnit);
    on<UpdateUnitStatus>(_onUpdateUnitStatus);
  }

  StreamSubscription? _supabaseSubscription;

  Future<void> _onLoadHome(LoadHome event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      await _supabaseSubscription?.cancel();
      final stream = supabase.from('properties').stream(primaryKey: ['id']);

      // Get the organization ID from the current user
      final user = supabase.auth.currentUser;
      String organizationId = '';
      if (user != null && user.userMetadata != null) {
        organizationId = user.userMetadata?['organization'] as String? ?? '';
      }

      _supabaseSubscription = stream.listen(
        (data) {
          if (!isClosed) {
            add(HomeDataChanged(data, organizationId: organizationId));
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(HomeError(error: error.toString()));
          }
        },
      );
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } on RealtimeSubscribeException {
      emit(const HomeError(error: 'Something went wrong. Please try again.'));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  Future<void> _onHomeDataChanged(
      HomeDataChanged event, Emitter<HomeState> emit) async {
    try {
      final currentState = state;
      final selectedProperty =
          currentState is HomeLoaded && currentState.selectedProperty != null
              ? currentState.selectedProperty
              : event.properties.isNotEmpty
                  ? event.properties.first
                  : null;

      if (selectedProperty == null) {
        emit(HomeLoaded(event.data, const [], const [], const [], const [],
            const [], const [], const [],
            selectedProperty: null));
        return;
      }
      // Fetch floors for the selected property (assuming selectedProperty has an 'id' field)
      final floors = await supabase
          .from('floors')
          .select()
          .eq('property_id', selectedProperty.id); // adjust if using a model

      // Fetch units for the selected property
      final units = await supabase
          .from('units')
          .select()
          .eq('property_id', selectedProperty.id);

      final tenants = await supabase
          .from('tenants')
          .select()
          .eq('property_id', selectedProperty.id);

      final unitTenancies = await supabase
          .from('unit_tenancy')
          .select()
          .eq('property_id', selectedProperty.id);

      final payments = await supabase
          .from('payments')
          .select()
          .eq('property_id', selectedProperty.id);

      // Fetch tenant discount groups
      final discountGroups = await supabase
          .from('tenant_discount_groups')
          .select()
          .eq('organization_id', event.organizationId);

      final activityEvents = await supabase
          .from('activity_events')
          .select()
          .eq('property_id', selectedProperty.id);

      emit(HomeLoaded(
        event.data,
        floors,
        units,
        tenants,
        unitTenancies,
        payments,
        discountGroups,
        activityEvents,
        selectedProperty: selectedProperty,
      ));
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  void _onSelectProperty(SelectProperty event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      try {
        emit(HomeLoading());
        final floors = await supabase
            .from('floors')
            .select()
            .eq('property_id', event.property.id);

        final units = await supabase
            .from('units')
            .select()
            .eq('property_id', event.property.id);

        final tenants = await supabase
            .from('tenants')
            .select()
            .eq('property_id', event.property.id);

        final unitTenancies = await supabase
            .from('unit_tenancy')
            .select()
            .eq('property_id', event.property.id);

        final payments = await supabase
            .from('payments')
            .select()
            .eq('property_id', event.property.id);

        final activityEvents = await supabase
            .from('activity_events')
            .select()
            .eq('property_id', event.property.id);

        // Get the current organization ID from user metadata or another source
        final user = supabase.auth.currentUser;
        String organizationId = '';
        if (user != null && user.userMetadata != null) {
          organizationId = user.userMetadata?['organization'] as String? ?? '';
        }

        // Fetch tenant discount groups
        final discountGroups = await supabase
            .from('tenant_discount_groups')
            .select()
            .eq('organization_id', organizationId);

        emit(HomeLoaded(
          currentState.data,
          floors,
          units,
          tenants,
          unitTenancies,
          payments,
          discountGroups,
          activityEvents,
          selectedProperty: event.property,
        ));
      } on PostgrestException catch (e) {
        emit(HomeError(error: e.message));
      } catch (e) {
        emit(HomeError(error: e.toString()));
      }
    }
  }

  Future<void> _onAddUnit(AddUnit event, Emitter<HomeState> emit) async {
    try {
      if (state is! HomeLoaded) {
        return;
      }

      // final currentState = state as HomeLoaded;
      emit(HomeLoading());

      // Get user's organization ID
      final user = supabase.auth.currentUser;
      String organizationId = '';
      if (user != null && user.userMetadata != null) {
        organizationId = user.userMetadata?['organization'] as String? ?? '';
      }

      // Create the new unit
      await supabase.from('units').insert({
        'floor_id': event.floorId,
        'unit_number': event.unitNumber,
        'status': 'available',
        'organization_id': organizationId,
        'property_id': event.propertyId,
      });

      // Reload the data
      add(LoadHome());
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  Future<void> _onUpdateUnitStatus(
      UpdateUnitStatus event, Emitter<HomeState> emit) async {
    try {
      if (state is! HomeLoaded) {
        return;
      }

      // final currentState = state as HomeLoaded;
      emit(HomeLoading());

      // Update the unit status
      await supabase.from('units').update({
        'status': event.newStatus,
      }).eq('id', event.unitId);

      // Reload the data
      add(LoadHome());
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _supabaseSubscription?.cancel();
    return super.close();
  }
}
