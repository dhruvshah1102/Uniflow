class StudentModel {
  final String id;
  final String userId;
  final String enrollmentNo;
  final String department;
  final int semester;
  final String section;
  final String? classroomStudentId;

  StudentModel({
    required this.id,
    required this.userId,
    required this.enrollmentNo,
    required this.department,
    required this.semester,
    required this.section,
    this.classroomStudentId,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map, String id) {
    final semesterValue = map['semester'];
    final semester = semesterValue is int
        ? semesterValue
        : semesterValue is num
            ? semesterValue.toInt()
            : int.tryParse(semesterValue?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 1;
    return StudentModel(
      id: id,
      userId: map['user_id'] ?? '',
      enrollmentNo: map['enrollment_no'] ?? '',
      department: map['department'] ?? '',
      semester: semester,
      section: map['section'] ?? '',
      classroomStudentId: map['classroom_student_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'enrollment_no': enrollmentNo,
      'department': department,
      'semester': semester,
      'section': section,
      'classroom_student_id': classroomStudentId,
    };
  }
}
