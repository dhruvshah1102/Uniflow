class FacultyModel {
  final String id;
  final String userId;
  final String employeeId;
  final String designation;
  final String department;
  final String? classroomTeacherId;

  FacultyModel({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.designation,
    required this.department,
    this.classroomTeacherId,
  });

  factory FacultyModel.fromMap(Map<String, dynamic> map, String id) {
    return FacultyModel(
      id: id,
      userId: map['user_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      designation: map['designation'] ?? '',
      department: map['department'] ?? '',
      classroomTeacherId: map['classroom_teacher_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'employee_id': employeeId,
      'designation': designation,
      'department': department,
      'classroom_teacher_id': classroomTeacherId,
    };
  }
}
