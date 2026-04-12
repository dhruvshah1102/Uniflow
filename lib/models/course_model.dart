class CourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final int credits;
  final String department;
  final int semester;
  final String facultyId;
  final String? classroomCourseId;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.department,
    required this.semester,
    required this.facultyId,
    this.classroomCourseId,
  });

  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    final semesterValue = map['semester'];
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
      id: (map['courseId'] ?? id).toString(),
      courseCode: (map['courseCode'] ?? map['course_code'] ?? map['code'] ?? id).toString(),
      courseName: (map['courseName'] ?? map['course_name'] ?? map['title'] ?? '').toString(),
      credits: map['credits']?.toInt() ?? 0,
      department: (map['department'] ?? '').toString(),
      semester: semesterNumber,
      facultyId: (map['facultyId'] ?? map['faculty_id'] ?? '').toString(),
      classroomCourseId: map['classroom_course_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': id,
      'courseCode': courseCode,
      'courseName': courseName,
      'course_code': courseCode,
      'course_name': courseName,
      'credits': credits,
      'department': department,
      'semester': semester,
      'semesterLabel': 'Semester $semester',
      'facultyId': facultyId,
      'faculty_id': facultyId,
      'classroom_course_id': classroomCourseId,
    };
  }
}
