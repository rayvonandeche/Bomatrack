import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/widgets/activity_event_item.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ActivityEvent> _filterEvents(List<ActivityEvent> events) {
    var filtered = events;
    
    // Apply type filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((e) => e.eventType == _selectedFilter).toList();
    }
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((e) => 
        e.title.toLowerCase().contains(searchTerm) ||
        e.description.toLowerCase().contains(searchTerm)
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Filter Notifications'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile(
                        title: const Text('All'),
                        value: 'all',
                        groupValue: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value.toString());
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile(
                        title: const Text('Payments'),
                        value: 'payment_received',
                        groupValue: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value.toString());
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile(
                        title: const Text('Tenants'),
                        value: 'tenant_added',
                        groupValue: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value.toString());
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile(
                        title: const Text('Units'),
                        value: 'unit_rented',
                        groupValue: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value.toString());
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile(
                        title: const Text('Maintenance'),
                        value: 'maintenance_request',
                        groupValue: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value.toString());
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                if (state is! HomeLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activityEvents = state.activityEvents;
                if (activityEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Notifications',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort and filter events
                final sortedEvents = List<ActivityEvent>.from(activityEvents)
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final filteredEvents = _filterEvents(sortedEvents);

                return ListView.builder(
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return ActivityEventItem(
                      key: ValueKey(event.id),
                      event: event,
                      onTap: () => _handleActivityTap(context, event),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleActivityTap(BuildContext context, ActivityEvent event) {
    // Mark as read
    if (!event.isRead) {
      context.read<HomeBloc>().add(MarkActivityAsRead(event.id));
    }

    // Always show the event details in a modal
    _showEventDetailsDialog(context, event);
  }

  void _showEventDetailsDialog(BuildContext context, ActivityEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getEventIcon(event.eventType),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Details',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      'Type',
                      _getEventTypeLabel(event.eventType),
                    ),
                    _buildDetailRow(
                      context,
                      'Date',
                      _formatDate(event.createdAt),
                    ),
                    if (event.entityId != null)
                      _buildDetailRow(
                        context,
                        'Related to',
                        event.entityType?.toUpperCase() ?? '',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'payment_received':
        return Icons.payment;
      case 'tenant_added':
        return Icons.person_add;
      case 'unit_rented':
        return Icons.home;
      case 'maintenance_request':
        return Icons.build;
      default:
        return Icons.notifications;
    }
  }

  String _getEventTypeLabel(String eventType) {
    switch (eventType) {
      case 'payment_received':
        return 'Payment Received';
      case 'tenant_added':
        return 'New Tenant';
      case 'unit_rented':
        return 'Unit Rented';
      case 'maintenance_request':
        return 'Maintenance Request';
      default:
        return eventType.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
} 