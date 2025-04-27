import 'package:bomatrack/models/models.dart';
import 'package:bomatrack/utils/date_format_utils.dart';
import 'package:flutter/material.dart';

class ActivityEventItem extends StatelessWidget {
  final ActivityEvent event;
  final VoidCallback? onTap;

  const ActivityEventItem({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event icon based on type
            _buildEventIcon(context),
            const SizedBox(width: 12),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: event.isRead ? FontWeight.normal : FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormatUtils.getRelativeTimeString(event.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.requiresAction) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Action Required',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!event.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventIcon(BuildContext context) {
    IconData iconData;
    Color iconColor;
    
    // Determine icon and color based on event type
    switch (event.eventType) {
      case 'payment_received':
        iconData = Icons.attach_money;
        iconColor = Colors.green;
        break;
      case 'payment_overdue':
        iconData = Icons.warning_amber;
        iconColor = Colors.orange;
        break;
      case 'tenant_added':
        iconData = Icons.person_add;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'tenant_removed':
        iconData = Icons.person_off;
        iconColor = Theme.of(context).colorScheme.error;
        break;
      case 'unit_rented':
        iconData = Icons.apartment;
        iconColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'unit_vacated':
        iconData = Icons.no_accounts;
        iconColor = Theme.of(context).colorScheme.error;
        break;
      case 'maintenance_request':
        iconData = Icons.build;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'system_notification':
        iconData = Icons.notifications;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      default:
        iconData = Icons.circle_notifications;
        iconColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }
}