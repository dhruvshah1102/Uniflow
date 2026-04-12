import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId; // UID of the user this notification belongs to
  final String title;
  final String body;
  final String type; // e.g., 'assignment', 'attendance', 'general'
  final String? courseId;
  final String? audience;
  final List<String> targetUserIds;
  final String? route;
  final String? sourceId;
  final bool deliveryCopy;
  final bool read;
  final Timestamp createdAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.courseId,
    this.audience,
    this.targetUserIds = const [],
    this.route,
    this.sourceId,
    this.deliveryCopy = false,
    this.read = false,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory NotificationModel.fromMap(Map<String, dynamic> data, String documentId) {
    return NotificationModel(
      notificationId: documentId,
      userId: data['userId'] ?? data['targetUserId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? data['message'] ?? '',
      type: data['type'] ?? 'general',
      courseId: data['courseId']?.toString(),
      audience: data['audience']?.toString(),
      targetUserIds: (data['targetUserIds'] is List)
          ? List<String>.from((data['targetUserIds'] as List).map((value) => value.toString()))
          : const [],
      route: data['route']?.toString(),
      sourceId: data['sourceId']?.toString(),
      deliveryCopy: data['deliveryCopy'] == true,
      read: data['read'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      if (courseId != null) 'courseId': courseId,
      if (audience != null) 'audience': audience,
      if (targetUserIds.isNotEmpty) 'targetUserIds': targetUserIds,
      if (route != null) 'route': route,
      if (sourceId != null) 'sourceId': sourceId,
      if (deliveryCopy) 'deliveryCopy': deliveryCopy,
      'read': read,
      'createdAt': createdAt,
    };
  }
}
