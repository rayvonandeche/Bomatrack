import 'dart:async';

import 'package:bomatrack/core/config/config.dart';

class SupabaseStreamService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, StreamSubscription> _subscriptions = {};
  final supabase = SupabaseConfig.supabase;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  // Subscribe to a specific table with proper filtering
  void subscribeToTable(String tableName, dynamic filterValue) {
    // Determine column for filter
    final columnName = (tableName == 'properties' || tableName == 'tenant_discount_groups')
        ? 'organization_id'
        : 'property_id';
    
    // Subscribe with filter on the appropriate column
    final stream = supabase
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq(columnName, filterValue);
    
    _subscriptions[tableName] = stream.listen(
      (data) {
        _controller.add({
          'tableName': tableName,
          'data': data,
        });
      },
      onError: (error) {
        // Just log the error but don't emit state to prevent UI disruption
        print('Error in $tableName subscription: $error');
      },
    );
  }

  // Cancel a specific subscription
  Future<void> cancelSubscription(String tableName) async {
    final subscription = _subscriptions[tableName];
    if (subscription != null) {
      await subscription.cancel();
      _subscriptions.remove(tableName);
    }
  }

  // Cancel all subscriptions
  Future<void> cancelAllSubscriptions() async {
    for (var subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void dispose() {
    cancelAllSubscriptions();
    _controller.close();
  }
}