import 'dart:async';

import 'package:bomatrack/core/config/config.dart';
import 'package:bomatrack/models/models.dart';
import 'package:bomatrack/services/supabase_stream_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'home_event.dart';
part 'home_state.dart';

final supabase = SupabaseConfig.supabase;

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SupabaseStreamService _streamService = SupabaseStreamService();
  late StreamSubscription _streamSubscription;

  HomeBloc() : super(HomeInitial()) {
    on<LoadHome>(_onLoadHome);
    on<HomeDataChanged>(_onHomeDataChanged);
    on<SelectProperty>(_onSelectProperty);
    on<AddUnit>(_onAddUnit);
    on<UpdateUnitStatus>(_onUpdateUnitStatus);
    on<RealtimeTableUpdated>(_onRealtimeTableUpdated);
    on<MarkActivityAsRead>(_onMarkActivityAsRead);
    
    // Listen to the stream service and handle all Supabase Realtime updates
    _streamSubscription = _streamService.stream.listen((update) {
      add(RealtimeTableUpdated(update['tableName'], update['data']));
    });
  }

  Future<void> _onLoadHome(LoadHome event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      // Cancel all existing subscriptions
      await _streamService.cancelAllSubscriptions();

      // Get the organization ID from the current user
      final user = supabase.auth.currentUser;
      String organizationId = '';
      if (user != null && user.userMetadata != null) {
        organizationId = user.userMetadata?['organization'] as String? ?? '';
      }

      // Subscribe to properties table first, as it's the primary one
      _streamService.subscribeToTable('properties', organizationId);

      // Get the initial properties data
      final propertiesData = await supabase.from('properties').select();
      
      // Get initial activity events for all properties in the organization
      final activityEvents = await supabase
          .from('activity_events')
          .select()
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);
      
      add(HomeDataChanged(propertiesData, 
          organizationId: organizationId,
          initialActivityEvents: activityEvents));
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } on RealtimeSubscribeException {
      emit(const HomeError(error: 'Something went wrong. Please try again.'));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  Future<void> _onRealtimeTableUpdated(
      RealtimeTableUpdated event, Emitter<HomeState> emit) async {
    // Only process if we're in a loaded state
    if (state is! HomeLoaded) return;
    
    final currentState = state as HomeLoaded;
    final selectedProperty = currentState.selectedProperty;
    
    // If no property is selected yet, just update properties list
    if (selectedProperty == null && event.tableName == 'properties') {
      emit(HomeLoaded(
        event.data, 
        currentState.data2, 
        currentState.data3, 
        currentState.data4,
        currentState.data5, 
        currentState.data6, 
        currentState.data7,
        currentState.data8,
      ));
      return;
    }
    
    // If the selected property exists, update the specific table data
    if (selectedProperty != null) {
      try {
        switch (event.tableName) {
          case 'properties':
            // If properties are updated, check if our selected property changed
            final updatedProperties = event.data.map((e) => Property.fromJson(e)).toList();
            final updatedSelected = updatedProperties.firstWhere(
              (p) => p.id == selectedProperty.id,
              orElse: () => selectedProperty,
            );
            
            emit(HomeLoaded(
              event.data,
              currentState.data2,
              currentState.data3,
              currentState.data4,
              currentState.data5,
              currentState.data6,
              currentState.data7,
              currentState.data8,
              selectedProperty: updatedSelected,
            ));
            break;
            
          case 'floors':
            // Only update floors for the current property
            final updatedFloors = await supabase
                .from('floors')
                .select()
                .eq('property_id', selectedProperty.id);
                
            emit(HomeLoaded(
              currentState.data,
              updatedFloors,
              currentState.data3,
              currentState.data4,
              currentState.data5,
              currentState.data6,
              currentState.data7,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'units':
            // Only update units for the current property
            final updatedUnits = await supabase
                .from('units')
                .select()
                .eq('property_id', selectedProperty.id);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              updatedUnits,
              currentState.data4,
              currentState.data5,
              currentState.data6,
              currentState.data7,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'tenants':
            // Only update tenants for the current property
            final updatedTenants = await supabase
                .from('tenants')
                .select()
                .eq('property_id', selectedProperty.id);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              currentState.data3,
              updatedTenants,
              currentState.data5,
              currentState.data6,
              currentState.data7,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'unit_tenancy':
            // Only update unit_tenancy for the current property
            final updatedUnitTenancies = await supabase
                .from('unit_tenancy')
                .select()
                .eq('property_id', selectedProperty.id);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              currentState.data3,
              currentState.data4,
              updatedUnitTenancies,
              currentState.data6,
              currentState.data7,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'payments':
            // Only update payments for the current property
            final updatedPayments = await supabase
                .from('payments')
                .select()
                .eq('property_id', selectedProperty.id);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              currentState.data3,
              currentState.data4,
              currentState.data5,
              updatedPayments,
              currentState.data7,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'tenant_discount_groups':
            // Update tenant discount groups
            final user = supabase.auth.currentUser;
            String organizationId = '';
            if (user != null && user.userMetadata != null) {
              organizationId = user.userMetadata?['organization'] as String? ?? '';
            }
            
            final updatedDiscountGroups = await supabase
                .from('tenant_discount_groups')
                .select()
                .eq('organization_id', organizationId);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              currentState.data3,
              currentState.data4,
              currentState.data5,
              currentState.data6,
              updatedDiscountGroups,
              currentState.data8,
              selectedProperty: selectedProperty,
            ));
            break;
            
          case 'activity_events':
            // Get activity events for both the organization and the selected property
            final user = supabase.auth.currentUser;
            String organizationId = user?.userMetadata?['organization'] as String? ?? '';
            
            final updatedActivityEvents = await supabase
                .from('activity_events')
                .select()
                .eq('organization_id', organizationId)
                .order('created_at', ascending: false);
                
            emit(HomeLoaded(
              currentState.data,
              currentState.data2,
              currentState.data3,
              currentState.data4,
              currentState.data5,
              currentState.data6,
              currentState.data7,
              updatedActivityEvents,
              selectedProperty: selectedProperty,
            ));
            break;
        }
      } catch (e) {
        // Log the error but don't emit error state to prevent UI disruption
        print('Error updating ${event.tableName} data: $e');
      }
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
        emit(HomeLoaded(
          event.data, 
          const [], 
          const [], 
          const [], 
          const [],
          const [], 
          const [], 
          event.initialActivityEvents,
          selectedProperty: null
        ));
        return;
      }
      
      // Subscribe to all other tables once we have selected a property
      final propId = selectedProperty!.id;
      _streamService.subscribeToTable('floors', propId);
      _streamService.subscribeToTable('units', propId);
      _streamService.subscribeToTable('tenants', propId);
      _streamService.subscribeToTable('unit_tenancy', propId);
      _streamService.subscribeToTable('payments', propId);
      _streamService.subscribeToTable('tenant_discount_groups', event.organizationId);
      _streamService.subscribeToTable('activity_events', propId);
      
      // Fetch floors for the selected property
      final floors = await supabase
          .from('floors')
          .select()
          .eq('property_id', selectedProperty.id);

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

      // Get activity events for the selected property
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

  Future<void> _onSelectProperty(SelectProperty event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      // Cancel existing subscriptions and resubscribe for new property
      await _streamService.cancelAllSubscriptions();
      final user = supabase.auth.currentUser;
      String organizationId = user?.userMetadata?['organization'] as String? ?? '';
      _streamService.subscribeToTable('properties', organizationId);
      final propId = event.property.id;
      _streamService.subscribeToTable('floors', propId);
      _streamService.subscribeToTable('units', propId);
      _streamService.subscribeToTable('tenants', propId);
      _streamService.subscribeToTable('unit_tenancy', propId);
      _streamService.subscribeToTable('payments', propId);
      _streamService.subscribeToTable('tenant_discount_groups', organizationId);
      _streamService.subscribeToTable('activity_events', propId);
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

      // We don't need to reload data manually as the realtime subscription will handle it
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

      emit(HomeLoading());

      // Update the unit status
      await supabase.from('units').update({
        'status': event.newStatus,
      }).eq('id', event.unitId);

      // We don't need to reload data manually as the realtime subscription will handle it
    } on PostgrestException catch (e) {
      emit(HomeError(error: e.message));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }
  
  Future<void> _onMarkActivityAsRead(
      MarkActivityAsRead event, Emitter<HomeState> emit) async {
    try {
      if (state is! HomeLoaded) {
        return;
      }

      final currentState = state as HomeLoaded;
      final activityEvents = List<dynamic>.from(currentState.data8);
      
      // Update the activity event in Supabase
      await supabase.from('activity_events').update({
        'is_read': true,
      }).eq('id', event.eventId);
      
      // Also update it locally in the state to immediately reflect the change
      for (int i = 0; i < activityEvents.length; i++) {
        if (activityEvents[i]['id'] == event.eventId) {
          activityEvents[i] = {
            ...activityEvents[i],
            'is_read': true,
          };
          break;
        }
      }
      
      // Emit the updated state
      emit(HomeLoaded(
        currentState.data,
        currentState.data2,
        currentState.data3,
        currentState.data4,
        currentState.data5, 
        currentState.data6,
        currentState.data7,
        activityEvents,
        selectedProperty: currentState.selectedProperty,
      ));
      
      // The realtime subscription will also handle updating the state when the server
      // confirms the change, so we don't need to reload the data manually
    } on PostgrestException catch (e) {
      // Just log the error but don't emit error state to prevent UI disruption
      print('Error marking activity as read: ${e.message}');
    } catch (e) {
      print('Error marking activity as read: $e');
    }
  }

  @override
  Future<void> close() {
    _streamSubscription.cancel();
    _streamService.dispose();
    return super.close();
  }
}
