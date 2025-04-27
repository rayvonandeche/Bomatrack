import 'package:flutter/foundation.dart';

/// Model representing an activity event in the system
class ActivityEvent {
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

  ActivityEvent({
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

  /// Create an ActivityEvent from a JSON map
  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as int,
      organizationId: json['organization_id'] as String,
      eventType: json['event_type'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as int,
      propertyId: json['property_id'] as int?,
      unitId: json['unit_id'] as int?,
      tenantId: json['tenant_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool,
      requiresAction: json['requires_action'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert ActivityEvent to a JSON map
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

  /// Create a copy of this ActivityEvent with the given fields replaced
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityEvent &&
        other.id == id &&
        other.organizationId == organizationId &&
        other.eventType == eventType &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.propertyId == propertyId &&
        other.unitId == unitId &&
        other.tenantId == tenantId &&
        other.title == title &&
        other.description == description &&
        mapEquals(other.data, data) &&
        other.isRead == isRead &&
        other.requiresAction == requiresAction &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
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
    );
  }
}