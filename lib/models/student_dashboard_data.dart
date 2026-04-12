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
  });

  int get unreadNotifications =>
      notifications.where((item) => !item.read).length;

  List<CourseDashboardItem> get courses => currentCourses;

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
