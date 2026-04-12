class TimetableModel {
  final String id;
  final String courseId;
  final String facultyId;
  final String day;
  final String startTime;
  final String endTime;
  final String room;
  final String section;
  final int semester;

  TimetableModel({
    required this.id,
    required this.courseId,
    required this.facultyId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.section,
    required this.semester,
  });

  factory TimetableModel.fromMap(Map<String, dynamic> map, String id) {
    return TimetableModel(
      id: id,
      courseId: map['course_id'] ?? '',
      facultyId: map['faculty_id'] ?? '',
      day: map['day'] ?? '',
      startTime: map['start_time'] ?? '',
      endTime: map['end_time'] ?? '',
      room: map['room'] ?? '',
      section: map['section'] ?? '',
      semester: map['semester']?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'faculty_id': facultyId,
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'section': section,
      'semester': semester,
    };
  }
}
