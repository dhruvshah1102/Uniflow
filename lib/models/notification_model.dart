import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String senderId;
  final String targetRole;
  final String? targetId;
  final String title;
  final String message;
  final String type;
  final Timestamp createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.senderId,
    required this.targetRole,
    this.targetId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      senderId: map['sender_id'] ?? '',
      targetRole: map['target_role'] ?? '',
      targetId: map['target_id'],
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      createdAt: map['created_at'] ?? Timestamp.now(),
      isRead: map['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'target_role': targetRole,
      'target_id': targetId,
      'title': title,
      'message': message,
      'type': type,
      'created_at': createdAt,
      'is_read': isRead,
    };
  }
}
