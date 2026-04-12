class AttendanceModel {
  final String id;
  final String courseId;
  final String studentId;
  final String facultyId;
  final String date;
  final String status;
  final String session;

  AttendanceModel({
    required this.id,
    required this.courseId,
    required this.studentId,
    required this.facultyId,
    required this.date,
    required this.status,
    required this.session,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      courseId: map['course_id'] ?? '',
      studentId: map['student_id'] ?? '',
      facultyId: map['faculty_id'] ?? '',
      date: map['date'] ?? '',
      status: map['status'] ?? '',
      session: map['session'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'student_id': studentId,
      'faculty_id': facultyId,
      'date': date,
      'status': status,
      'session': session,
    };
  }
}
