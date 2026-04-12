import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String studentId;
  final String courseId;
  final Timestamp date; // date of class
  final bool present;

  AttendanceModel({
    required this.attendanceId,
    required this.studentId,
    required this.courseId,
    required this.date,
    required this.present,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> data, String documentId) {
    final rawPresent = data['present'];
    final rawStatus = data['status'];
    final derivedPresent = rawPresent is bool
        ? rawPresent
        : rawStatus is String
            ? rawStatus.toLowerCase() == 'present'
            : false;

    return AttendanceModel(
      attendanceId: documentId,
      studentId: data['studentId'] ?? '',
      courseId: data['courseId'] ?? '',
      date: data['date'] ?? Timestamp.now(),
      present: derivedPresent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'courseId': courseId,
      'date': date,
      'present': present,
      'status': present ? 'present' : 'absent',
    };
  }
}
