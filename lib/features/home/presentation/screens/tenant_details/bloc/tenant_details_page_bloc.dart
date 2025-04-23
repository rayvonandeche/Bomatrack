import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'tenant_details_page_event.dart';
part 'tenant_details_page_state.dart';

class TenantDetailsPageBloc
    extends Bloc<TenantDetailsPageEvent, TenantDetailsPageState> {
  final _supabase = Supabase.instance.client;
  
  TenantDetailsPageBloc() : super(TenantDetailsPageInitial()) {
    on<AddPaymentPressed>(_onAddPaymentPressed);
    on<RemoveTenantPressed>(_onRemoveTenant);
    on<RemoveUnitPressed>(_onRemoveUnitPressed);
    on<AddUnitPressed>(_onAddUnitPressed);
    on<ChangeUnitPressed>(_onChangeUnitPressed);
    on<CreateBundledUnitsPressed>(_onCreateBundledUnitsPressed);
  }

  Future<void> _onAddPaymentPressed(
      AddPaymentPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Using RPC function to add a payment with all the pending IDs
      await _supabase.rpc(
        'add_payment',
        params: {
          'p_tenant_id': event.tenantId,
          'p_pending_payment_ids': event.pendingPaymentId,
          'p_amount': event.amount,
          'p_payment_date': event.paymentDate,
          'p_payment_method': event.paymentMethod,
          'p_reference_number': event.referenceNumber,
          'p_description': event.description,
        },
      );

      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error adding payment: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }

  Future<void> _onRemoveTenant(
      RemoveTenantPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Call your remove tenant function
      await _supabase.rpc('delete_tenant', params: {'t_id': event.tenantId});

      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error removing tenant: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }

  Future<void> _onRemoveUnitPressed(
      RemoveUnitPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Call the new database function for removing a unit from a tenant
      // Get the tenant ID from the unit_tenancy table
      int tenantId;
      
      try {
        final response = await _supabase
            .from('unit_tenancy')
            .select('tenant_id')
            .eq('unit_id', event.unitId)
            .eq('status', 'active')
            .single();
        
        tenantId = response['tenant_id'] as int;
      } catch (e) {
        log('Error finding tenant for unit: $e');
        // If we can't find the tenant, we can't proceed
        emit(TenantDetailsPageError(error:'Could not find active tenant for this unit.'));
        return;
      }
      
      // Use the new remove_unit_from_tenant function
      final result = await _supabase.rpc('remove_unit_from_tenant', params: {
        'p_tenant_id': tenantId,
        'p_unit_id': event.unitId,
        'p_end_date': DateTime.now().toIso8601String().split('T')[0], // Current date in YYYY-MM-DD format
      });
      
      log('Remove unit result: $result');
      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error removing unit: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }

  Future<void> _onAddUnitPressed(
      AddUnitPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Call the new database function for adding a unit to a tenant
      final result = await _supabase.rpc('add_unit_to_tenant', params: {
        'p_tenant_id': event.tenantId,
        'p_unit_id': event.unitId,
        'p_monthly_rent': event.monthlyRent,
        'p_start_date': event.startDate,
      });
      
      log('Add unit result: $result');
      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error adding unit: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }

  Future<void> _onChangeUnitPressed(
      ChangeUnitPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Call the new database function for changing a tenant's unit
      final result = await _supabase.rpc('change_tenant_unit', params: {
        'p_tenant_id': event.tenantId,
        'p_old_unit_id': event.oldUnitId,
        'p_new_unit_id': event.newUnitId,
        'p_monthly_rent': event.monthlyRent,
        'p_start_date': event.startDate,
      });
      
      log('Change unit result: $result');
      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error changing unit: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }
  
  Future<void> _onCreateBundledUnitsPressed(
      CreateBundledUnitsPressed event, Emitter<TenantDetailsPageState> emit) async {
    try {
      emit(TenantDetailsPageLoading());

      // Call the database function to create a bundled unit group with discount
      final result = await _supabase.rpc('create_discounted_tenancy_group', params: {
        'p_tenant_id': event.tenantId,
        'p_unit_ids': event.unitIds,
        'p_discount_name': event.discountName,
        'p_discount_type': event.discountType,
        'p_discount_value': event.discountValue,
        'p_monthly_rent': event.monthlyRent,
        'p_start_date': event.startDate,
      });
      
      log('Create bundled units result: $result');
      emit(TenantDetailsPageSuccess());
    } catch (error) {
      log('Error creating bundled units: $error');
      emit(TenantDetailsPageError(error: error.toString()));
    }
  }
}
