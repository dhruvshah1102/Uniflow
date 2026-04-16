import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/notification.dart';
import '../models/quiz_model.dart';
import '../models/quiz_submission_model.dart';
import '../models/study_material.dart';
import '../models/semester_registration.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';

class StudentDashboardData {
  final UserModel user;
  final StudentModel? studentProfile;
  final double overallAttendance;
  final List<AttendanceModel> attendanceRecords;
  final List<CourseDashboardItem> currentCourses;
  final List<UpcomingCourseDashboardItem> upcomingCourses;
  final List<DashboardTaskItem> pendingTasks;
  final List<QuizDashboardItem> quizzes;
  final List<QuizSubmissionModel> quizSubmissions;
  final List<StudyMaterialDashboardItem> studyMaterials;
  final List<DashboardNotificationItem> notifications;
  final DateTime? nextDeadline;
  final SemesterRegistrationRecord? nextSemesterRegistration;
  final bool registrationOpen;

  const StudentDashboardData({
    required this.user,
    required this.studentProfile,
    required this.overallAttendance,
    required this.attendanceRecords,
    required this.currentCourses,
    required this.upcomingCourses,
    required this.pendingTasks,
    required this.quizzes,
    required this.quizSubmissions,
    required this.studyMaterials,
    required this.notifications,
    required this.nextDeadline,
    required this.nextSemesterRegistration,
    required this.registrationOpen,
  });

  int get unreadNotifications =>
      notifications.where((item) => !item.read).length;

  List<CourseDashboardItem> get courses => currentCourses;

  factory StudentDashboardData.fromMap(Map<String, dynamic> map) {
    return StudentDashboardData(
      user: UserModel.fromMap(_map(map['user']), _string(_map(map['user'])['uid']) ?? _string(_map(map['user'])['id']) ?? ''),
      studentProfile: map['studentProfile'] == null
          ? null
          : StudentModel.fromMap(
              _map(map['studentProfile']),
              _string(_map(map['studentProfile'])['id']) ?? '',
            ),
      overallAttendance: _double(map['overallAttendance']) ?? 0.0,
      attendanceRecords: _list(map['attendanceRecords'])
          .map((item) => AttendanceModel.fromMap(_map(item), _string(_map(item)['attendanceId']) ?? ''))
          .toList(),
      currentCourses: _list(map['currentCourses'])
          .map((item) => CourseDashboardItem.fromMap(_map(item)))
          .toList(),
      upcomingCourses: _list(map['upcomingCourses'])
          .map((item) => UpcomingCourseDashboardItem.fromMap(_map(item)))
          .toList(),
      pendingTasks: _list(map['pendingTasks'])
          .map((item) => DashboardTaskItem.fromMap(_map(item)))
          .toList(),
      quizzes: _list(map['quizzes'])
          .map((item) => QuizDashboardItem.fromMap(_map(item)))
          .toList(),
      quizSubmissions: _list(map['quizSubmissions'])
          .map((item) => QuizSubmissionModel.fromMap(_map(item), _string(_map(item)['id']) ?? ''))
          .toList(),
      studyMaterials: _list(map['studyMaterials'])
          .map((item) => StudyMaterialDashboardItem.fromMap(_map(item)))
          .toList(),
      notifications: _list(map['notifications'])
          .map((item) => DashboardNotificationItem.fromMap(_map(item)))
          .toList(),
      nextDeadline: _timestamp(map['nextDeadline'])?.toDate(),
      nextSemesterRegistration: map['nextSemesterRegistration'] == null
          ? null
          : SemesterRegistrationRecord.fromMap(
              _map(map['nextSemesterRegistration']),
              _string(_map(map['nextSemesterRegistration'])['id']) ?? '',
            ),
      registrationOpen: map['registrationOpen'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': {
        'uid': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role,
      },
      'studentProfile': studentProfile == null
          ? null
          : {
              'id': studentProfile!.id,
              'userId': studentProfile!.userId,
              'enrollmentNo': studentProfile!.enrollmentNo,
              'department': studentProfile!.department,
              'semester': studentProfile!.semester,
              'section': studentProfile!.section,
            },
      'overallAttendance': overallAttendance,
      'attendanceRecords': attendanceRecords
          .map(
            (record) => {
              'attendanceId': record.attendanceId,
              'studentId': record.studentId,
              'courseId': record.courseId,
              'date': record.date.toDate().toIso8601String(),
              'present': record.present,
            },
          )
          .toList(),
      'courses': currentCourses.map((item) => item.toMap()).toList(),
      'currentCourses': currentCourses.map((item) => item.toMap()).toList(),
      'upcomingCourses': upcomingCourses.map((item) => item.toMap()).toList(),
      'pendingTasks': pendingTasks.map((item) => item.toMap()).toList(),
      'quizzes': quizzes.map((item) => item.toMap()).toList(),
      'quizSubmissions': quizSubmissions.map((item) => item.toMap()).toList(),
      'studyMaterials': studyMaterials.map((item) => item.toMap()).toList(),
      'notifications': notifications.map((item) => item.toMap()).toList(),
      'attendanceBreakdown': currentCourses
          .map(
            (item) => {
              'courseId': item.course.courseId,
              'courseCode': item.course.code,
              'courseName': item.course.title,
              'facultyName': item.facultyName,
              'attendancePercentage': item.attendancePercentage,
              'presentClasses': item.presentClasses,
              'totalClasses': item.totalClasses,
            },
          )
          .toList(),
      'nextDeadline': nextDeadline?.toIso8601String(),
      'unreadNotifications': unreadNotifications,
      'nextSemesterRegistration': nextSemesterRegistration == null
          ? null
          : {
              'id': nextSemesterRegistration!.id,
              'targetSemester': nextSemesterRegistration!.targetSemester,
              'status': nextSemesterRegistration!.status,
              'selectedCourseNames': nextSemesterRegistration!.selectedCourseNames,
              'backlogCourseNames': nextSemesterRegistration!.backlogCourseNames,
            },
      'registrationOpen': registrationOpen,
    };
  }
}

class CourseDashboardItem {
  final CourseModel course;
  final String facultyName;
  final double attendancePercentage;
  final int presentClasses;
  final int totalClasses;
  final int pendingTaskCount;
  final DateTime? nextDeadline;

  const CourseDashboardItem({
    required this.course,
    required this.facultyName,
    required this.attendancePercentage,
    required this.presentClasses,
    required this.totalClasses,
    required this.pendingTaskCount,
    required this.nextDeadline,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': course.courseId,
      'courseCode': course.code,
      'title': course.title,
      'facultyName': facultyName,
      'description': course.description,
      'credits': course.credits,
      'facultyId': course.facultyId,
      'semester': course.semester,
      'attendancePercentage': attendancePercentage,
      'presentClasses': presentClasses,
      'totalClasses': totalClasses,
      'pendingTaskCount': pendingTaskCount,
      'nextDeadline': nextDeadline?.toIso8601String(),
    };
  }

  factory CourseDashboardItem.fromMap(Map<String, dynamic> map) {
    return CourseDashboardItem(
      course: CourseModel.fromMap(map, _string(map['courseId']) ?? ''),
      facultyName: _string(map['facultyName']) ?? '',
      attendancePercentage: _double(map['attendancePercentage']) ?? 0.0,
      presentClasses: _int(map['presentClasses']) ?? 0,
      totalClasses: _int(map['totalClasses']) ?? 0,
      pendingTaskCount: _int(map['pendingTaskCount']) ?? 0,
      nextDeadline: _timestamp(map['nextDeadline'])?.toDate(),
    );
  }
}

class UpcomingCourseDashboardItem {
  final CourseModel course;
  final String facultyName;

  const UpcomingCourseDashboardItem({
    required this.course,
    required this.facultyName,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': course.courseId,
      'courseCode': course.code,
      'title': course.title,
      'facultyName': facultyName,
      'credits': course.credits,
      'semester': course.semester,
      'semesterNumber': course.semesterNumber,
    };
  }

  factory UpcomingCourseDashboardItem.fromMap(Map<String, dynamic> map) {
    return UpcomingCourseDashboardItem(
      course: CourseModel.fromMap(map, _string(map['courseId']) ?? ''),
      facultyName: _string(map['facultyName']) ?? '',
    );
  }
}

class DashboardTaskItem {
  final AssignmentModel assignment;
  final String courseCode;
  final bool isOverdue;

  const DashboardTaskItem({
    required this.assignment,
    required this.courseCode,
    required this.isOverdue,
  });

  DateTime get dueDate => assignment.dueDate.toDate();

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignment.assignmentId,
      'courseId': assignment.courseId,
      'courseCode': courseCode,
      'title': assignment.title,
      'description': assignment.description,
      'dueDate': dueDate.toIso8601String(),
      'createdBy': assignment.createdBy,
      'isOverdue': isOverdue,
    };
  }

  factory DashboardTaskItem.fromMap(Map<String, dynamic> map) {
    final assignment = AssignmentModel.fromMap(map, _string(map['assignmentId']) ?? '');
    return DashboardTaskItem(
      assignment: assignment,
      courseCode: _string(map['courseCode']) ?? '',
      isOverdue: map['isOverdue'] == true,
    );
  }
}

class DashboardNotificationItem {
  final NotificationModel notification;

  const DashboardNotificationItem({required this.notification});

  bool get read => notification.read;

  DateTime get createdAt => notification.createdAt.toDate();

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notification.notificationId,
      'title': notification.title,
      'body': notification.body,
      'type': notification.type,
      'read': notification.read,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DashboardNotificationItem.fromMap(Map<String, dynamic> map) {
    return DashboardNotificationItem(
      notification: NotificationModel.fromMap(map, _string(map['notificationId']) ?? ''),
    );
  }
}

class QuizDashboardItem {
  final QuizModel quiz;
  final String courseCode;
  final String courseTitle;
  final int questionCount;

  const QuizDashboardItem({
    required this.quiz,
    required this.courseCode,
    required this.courseTitle,
    required this.questionCount,
  });

  DateTime get startTime => quiz.startTime.toDate();
  DateTime get endTime => quiz.endTime.toDate();

  Map<String, dynamic> toMap() {
    return {
      'quizId': quiz.id,
      'courseId': quiz.courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'title': quiz.title,
      'totalMarks': quiz.totalMarks,
      'questionCount': questionCount,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory QuizDashboardItem.fromMap(Map<String, dynamic> map) {
    return QuizDashboardItem(
      quiz: QuizModel.fromMap(map, _string(map['quizId']) ?? ''),
      courseCode: _string(map['courseCode']) ?? '',
      courseTitle: _string(map['courseTitle']) ?? '',
      questionCount: _int(map['questionCount']) ?? 0,
    );
  }
}

class QuizResultSummary {
  final QuizSubmissionModel submission;
  final int totalMarks;

  const QuizResultSummary({
    required this.submission,
    required this.totalMarks,
  });

  double get percentage =>
      totalMarks <= 0 ? 0 : (submission.score / totalMarks) * 100;
}

class StudyMaterialDashboardItem {
  final StudyMaterialModel material;
  final String courseCode;
  final String courseTitle;

  const StudyMaterialDashboardItem({
    required this.material,
    required this.courseCode,
    required this.courseTitle,
  });

  DateTime get uploadedAt => material.uploadedAt.toDate();

  Map<String, dynamic> toMap() {
    return {
      'materialId': material.id,
      'courseId': material.courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'fileName': material.fileName,
      'fileUrl': material.fileUrl,
      'uploadedBy': material.uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory StudyMaterialDashboardItem.fromMap(Map<String, dynamic> map) {
    return StudyMaterialDashboardItem(
      material: StudyMaterialModel.fromMap(map, _string(map['materialId']) ?? ''),
      courseCode: _string(map['courseCode']) ?? '',
      courseTitle: _string(map['courseTitle']) ?? '',
    );
  }
}

class AttendanceSummary {
  final String courseId;
  final double percentage;
  final int presentClasses;
  final int totalClasses;

  const AttendanceSummary({
    required this.courseId,
    required this.percentage,
    required this.presentClasses,
    required this.totalClasses,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'percentage': percentage,
      'presentClasses': presentClasses,
      'totalClasses': totalClasses,
    };
  }
}

AttendanceSummary buildAttendanceSummary({
  required String courseId,
  required List<AttendanceModel> records,
}) {
  final presentClasses = records.where((record) => record.present).length;
  final totalClasses = records.length;
  final percentage =
      totalClasses == 0 ? 0.0 : (presentClasses / totalClasses) * 100;

  return AttendanceSummary(
    courseId: courseId,
    percentage: percentage,
    presentClasses: presentClasses,
    totalClasses: totalClasses,
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

String? _string(dynamic value) {
  if (value == null) return null;
  return value.toString().trim();
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
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
