import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/screens/notifications/notifications_screen.dart';
import 'package:bomatrack/features/home/presentation/widgets/activity_event_item.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state is! HomeLoaded) {
          return const SizedBox.shrink();
        }

        final activityEvents = state.activityEvents;
        
        if (activityEvents.isEmpty) {
          return _buildEmptyActivityView(context);
        }
        
        // Sort activity events by date in descending order
        final sortedEvents = List<ActivityEvent>.from(activityEvents)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: BlocProvider.of<HomeBloc>(context),
                            child: const NotificationsScreen(),
                          ),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedEvents.length > 5 ? 5 : sortedEvents.length,
                  itemBuilder: (context, index) {
                    final event = sortedEvents[index];
                    return ActivityEventItem(
                      key: ValueKey(event.id), // Add key for better widget updates
                      event: event,
                      onTap: () => _handleActivityTap(context, event),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyActivityView(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity related to your properties will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      case 'payment_overdue':
        return Icons.warning;
      case 'tenant_added':
        return Icons.person_add;
      case 'tenant_removed':
        return Icons.person_off;
      case 'unit_rented':
        return Icons.home;
      case 'unit_vacated':
        return Icons.no_accounts;
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
      case 'payment_overdue':
        return 'Payment Overdue';
      case 'tenant_added':
        return 'New Tenant';
      case 'tenant_removed':
        return 'Tenant Removed';
      case 'unit_rented':
        return 'Unit Rented';
      case 'unit_vacated':
        return 'Unit Vacated';
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