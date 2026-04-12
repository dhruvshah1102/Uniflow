import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String courseId;
  final String title;
  final String code;
  final String description;
  final int credits;
  final String facultyId;
  final String facultyName;
  final String semester;
  final int semesterNumber;
  final String department;
  final Timestamp createdAt;

  CourseModel({
    required this.courseId,
    required this.title,
    required this.code,
    required this.description,
    required this.credits,
    required this.facultyId,
    this.facultyName = '',
    required this.semester,
    this.semesterNumber = 0,
    this.department = '',
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory CourseModel.fromMap(Map<String, dynamic> data, String documentId) {
    final semesterValue = data['semester'];
    final semesterNumber = semesterValue is int
        ? (semesterValue >= 1 && semesterValue <= 12 ? semesterValue : 0)
        : semesterValue is num
            ? (() {
                final value = semesterValue.toInt();
                return value >= 1 && value <= 12 ? value : 0;
              })()
            : (() {
                final raw = semesterValue?.toString() ?? '';
                final exact = int.tryParse(raw);
                if (exact != null && exact >= 1 && exact <= 12) return exact;
                final digits = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                return digits >= 1 && digits <= 12 ? digits : 0;
              })();
    return CourseModel(
      courseId: (data['courseId'] ?? data['courseID'] ?? documentId).toString(),
      title: (data['courseName'] ?? data['title'] ?? data['course_name'] ?? '').toString(),
      code: (data['courseCode'] ?? data['code'] ?? data['course_code'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      credits: data['credits'] ?? 0,
      facultyId: (data['facultyId'] ?? data['faculty_id'] ?? '').toString(),
      facultyName: (data['facultyName'] ?? data['faculty_name'] ?? '').toString(),
      semester: semesterNumber > 0 ? 'Semester $semesterNumber' : 'Semester -',
      semesterNumber: semesterNumber,
      department: (data['department'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseCode': code,
      'courseName': title,
      'title': title,
      'code': code,
      'course_code': code,
      'course_name': title,
      'description': description,
      'credits': credits,
      'facultyId': facultyId,
      'faculty_id': facultyId,
      if (facultyName.isNotEmpty) 'facultyName': facultyName,
      if (facultyName.isNotEmpty) 'faculty_name': facultyName,
      'semester': semesterNumber > 0 ? semesterNumber : semester,
      if (semesterNumber > 0) 'semesterLabel': semester,
      if (department.isNotEmpty) 'department': department,
      'createdAt': createdAt,
    };
  }
}
