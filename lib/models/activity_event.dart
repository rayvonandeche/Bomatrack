import 'package:equatable/equatable.dart';

class ActivityEvent extends Equatable {
  final int id;
  final String organizationId;
  final String eventType;
  final String entityType;
  final int entityId;
  final int? propertyId;
  final int? unitId;
  final int? tenantId;
  final String title;
  final String description;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool requiresAction;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityEvent({
    required this.id,
    required this.organizationId,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    this.propertyId,
    this.unitId,
    this.tenantId,
    required this.title,
    required this.description,
    this.data,
    required this.isRead,
    required this.requiresAction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'],
      organizationId: json['organization_id'],
      eventType: json['event_type'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      propertyId: json['property_id'],
      unitId: json['unit_id'],
      tenantId: json['tenant_id'],
      title: json['title'],
      description: json['description'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      isRead: json['is_read'] ?? false,
      requiresAction: json['requires_action'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'event_type': eventType,
      'entity_type': entityType,
      'entity_id': entityId,
      'property_id': propertyId,
      'unit_id': unitId,
      'tenant_id': tenantId,
      'title': title,
      'description': description,
      'data': data,
      'is_read': isRead,
      'requires_action': requiresAction,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        eventType,
        entityType,
        entityId,
        propertyId,
        unitId,
        tenantId,
        title,
        description,
        data,
        isRead,
        requiresAction,
        createdAt,
        updatedAt,
      ];

  ActivityEvent copyWith({
    int? id,
    String? organizationId,
    String? eventType,
    String? entityType,
    int? entityId,
    int? propertyId,
    int? unitId,
    int? tenantId,
    String? title,
    String? description,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? requiresAction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityEvent(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      eventType: eventType ?? this.eventType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      description: description ?? this.description,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      requiresAction: requiresAction ?? this.requiresAction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}