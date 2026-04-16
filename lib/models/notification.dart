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
  final String? sourceCollection;
  final String? assignmentId;
  final String? quizId;
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
    this.sourceCollection,
    this.assignmentId,
    this.quizId,
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
      sourceCollection: data['sourceCollection']?.toString(),
      assignmentId: data['assignmentId']?.toString(),
      quizId: data['quizId']?.toString(),
      deliveryCopy: data['deliveryCopy'] == true,
      read: data['read'] ?? false,
      createdAt: _timestamp(data['createdAt']) ?? Timestamp.now(),
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
      if (sourceCollection != null) 'sourceCollection': sourceCollection,
      if (assignmentId != null) 'assignmentId': assignmentId,
      if (quizId != null) 'quizId': quizId,
      if (deliveryCopy) 'deliveryCopy': deliveryCopy,
      'read': read,
      'createdAt': createdAt,
    };
  }
}

Timestamp? _timestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed == null ? null : Timestamp.fromDate(parsed);
}
