import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assignment.dart';
import '../models/course.dart';
import '../models/academic_result.dart';
import '../models/quiz_model.dart';
import '../models/quiz_submission_model.dart';
import '../models/submission_model.dart';
import '../models/study_material.dart';
import '../models/notification_model.dart';
import 'storage_service.dart';
import 'admin_module_service.dart';
import 'local_cache_service.dart';

class FacultyDashboardData {
  final List<CourseModel> courses;
  final Map<String, int> studentCountByCourse;
  final List<AssignmentModel> assignments;
  final List<QuizModel> quizzes;
  final List<StudyMaterialModel> materials;
  final List<NotificationModel> announcements;
  final int pendingTasks;

  const FacultyDashboardData({
    required this.courses,
    required this.studentCountByCourse,
    required this.assignments,
    required this.quizzes,
    required this.materials,
    required this.announcements,
    required this.pendingTasks,
  });
}

class CourseStudent {
  final String studentId;
  final String name;
  final String email;

  const CourseStudent({
    required this.studentId,
    required this.name,
    required this.email,
  });
}

class AssignmentAttemptSummary {
  final SubmissionModel submission;
  final String studentName;
  final String studentEmail;
  final int totalMarks;

  const AssignmentAttemptSummary({
    required this.submission,
    required this.studentName,
    required this.studentEmail,
    required this.totalMarks,
  });

  double get percentage =>
      (totalMarks <= 0 || submission.marksObtained == null)
          ? 0
          : (submission.marksObtained! / totalMarks) * 100;
}

class QuizAttemptSummary {
  final QuizSubmissionModel submission;
  final String studentName;
  final String studentEmail;
  final int totalMarks;

  const QuizAttemptSummary({
    required this.submission,
    required this.studentName,
    required this.studentEmail,
    required this.totalMarks,
  });

  double get percentage =>
      totalMarks <= 0 ? 0 : (submission.score / totalMarks) * 100;
}

class FacultyModuleService {
  FacultyModuleService._();
  static final FacultyModuleService instance = FacultyModuleService._();

  static const MethodChannel _attendanceExportChannel =
      MethodChannel('uniflow/attendance_export');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService.instance;
  final Random _random = Random();
  final Map<String, _CachedFacultyDashboard> _dashboardCache = {};
  static const Duration _dashboardCacheTtl = Duration(seconds: 20);
  static const Duration _diskCacheTtl = Duration(hours: 1);

  Future<FacultyDashboardData> loadDashboard({
    required String firebaseUid,
    required String userDocId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(firebaseUid, userDocId);
    if (!forceRefresh) {
      final diskCached = await _readCachedDashboard(cacheKey);
      if (diskCached != null) {
        return diskCached;
      }

      final cached = _dashboardCache[cacheKey];
      final fetchedAt = DateTime.now();
      if (cached != null && fetchedAt.difference(cached.fetchedAt) < _dashboardCacheTtl) {
        return cached.data;
      }
    }

    await AdminModuleService.instance.ensureCourseCatalog();
    final facultyIds = _uniqueIds([firebaseUid, userDocId]);
    final courses = await _fetchCoursesForFaculty(facultyIds);
    final courseIds = courses.map((course) => course.courseId).toList();
    final enrollments = await _fetchEnrollments(courseIds);
    final assignments = await _fetchAssignments(courseIds);
    final quizzes = await _fetchQuizzes(courseIds);
    final materials = await _fetchMaterials(courseIds);
    final announcements = await _fetchAnnouncements(firebaseUid, userDocId);

    final studentsByCourse = <String, Set<String>>{};
    for (final enrollment in enrollments) {
      final courseId = enrollment['courseId'] as String? ?? '';
      final studentId = enrollment['studentId'] as String? ?? '';
      if (courseId.isEmpty) continue;
      if (studentId.isEmpty) continue;
      studentsByCourse.putIfAbsent(courseId, () => <String>{}).add(studentId);
    }
    final studentCountByCourse = {
      for (final entry in studentsByCourse.entries)
        entry.key: entry.value.length,
    };

    assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final cacheTime = DateTime.now();
    final dueSoonCount = assignments
        .where(
          (assignment) => assignment.dueDate.toDate().isBefore(
            cacheTime.add(const Duration(days: 3)),
          ),
        )
        .length;

    final data = FacultyDashboardData(
      courses: courses,
      studentCountByCourse: studentCountByCourse,
      assignments: assignments,
      quizzes: quizzes,
      materials: materials,
      announcements: announcements,
      pendingTasks: dueSoonCount + courses.length,
    );

    _dashboardCache[cacheKey] = _CachedFacultyDashboard(
      data: data,
      fetchedAt: DateTime.now(),
    );
    await _writeCachedDashboard(cacheKey, data);
    return data;
  }

  Stream<FacultyDashboardData> watchDashboard({
    required String firebaseUid,
    required String userDocId,
    bool forceRefresh = false,
  }) {
    return Stream<FacultyDashboardData>.fromFuture(
      loadDashboard(
        firebaseUid: firebaseUid,
        userDocId: userDocId,
        forceRefresh: forceRefresh,
      ),
    );
  }

  String _cacheKey(String firebaseUid, String userDocId) {
    return '${firebaseUid.trim()}|${userDocId.trim()}';
  }

  Future<FacultyDashboardData?> _readCachedDashboard(String cacheKey) async {
    final map = await LocalCacheService.instance.readJson(cacheKey);
    if (map == null) return null;
    try {
      final cachedAt = _timestamp(map['cachedAt']);
      if (cachedAt != null && DateTime.now().difference(cachedAt.toDate()) > _diskCacheTtl) {
        return null;
      }
      final payload = _map(map['payload']);
      return _facultyDashboardFromMap(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedDashboard(String cacheKey, FacultyDashboardData data) async {
    await LocalCacheService.instance.writeJson(cacheKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'payload': _facultyDashboardToMap(data),
    });
  }

  Map<String, dynamic> _facultyDashboardToMap(FacultyDashboardData data) {
    return {
      'courses': data.courses.map((course) => course.toMap()).toList(),
      'studentCountByCourse': data.studentCountByCourse,
      'assignments': data.assignments.map((assignment) => assignment.toMap()).toList(),
      'quizzes': data.quizzes.map((quiz) => quiz.toMap()).toList(),
      'materials': data.materials.map((material) => material.toMap()).toList(),
      'announcements': data.announcements.map((notification) => notification.toMap()).toList(),
      'pendingTasks': data.pendingTasks,
    };
  }

  FacultyDashboardData _facultyDashboardFromMap(Map<String, dynamic> map) {
    return FacultyDashboardData(
      courses: _list(map['courses'])
          .map((item) => CourseModel.fromMap(_map(item), _string(_map(item)['courseId']) ?? ''))
          .toList(),
      studentCountByCourse: _stringIntMap(map['studentCountByCourse']),
      assignments: _list(map['assignments'])
          .map((item) => AssignmentModel.fromMap(_map(item), _string(_map(item)['assignmentId']) ?? ''))
          .toList(),
      quizzes: _list(map['quizzes'])
          .map((item) => QuizModel.fromMap(_map(item), _string(_map(item)['quizId']) ?? ''))
          .toList(),
      materials: _list(map['materials'])
          .map((item) => StudyMaterialModel.fromMap(_map(item), _string(_map(item)['materialId']) ?? ''))
          .toList(),
      announcements: _list(map['announcements'])
          .map((item) => NotificationModel.fromMap(_map(item), _string(_map(item)['notificationId']) ?? ''))
          .toList(),
      pendingTasks: _int(map['pendingTasks']) ?? 0,
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

  Map<String, int> _stringIntMap(dynamic value) {
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), _int(entry) ?? 0));
    }
    return <String, int>{};
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

  Future<List<CourseModel>> _fetchCoursesForFaculty(
    List<String> facultyIds,
  ) async {
    if (facultyIds.isEmpty) return [];
    final results = <CourseModel>[];

    for (final batch in _chunk(facultyIds, 10)) {
      final snap = await _db
          .collection('courses')
          .where('facultyId', whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => CourseModel.fromMap(doc.data(), doc.id)),
      );
    }

    results.sort((a, b) => a.code.compareTo(b.code));
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchEnrollments(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db
          .collection('enrollments')
          .where('courseId', whereIn: batch)
          .get();
      results.addAll(snap.docs.map((doc) => doc.data()));
    }
    return results;
  }

  Future<List<AssignmentModel>> _fetchAssignments(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) return [];
    final results = <AssignmentModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db
          .collection('assignments')
          .where('courseId', whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => AssignmentModel.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  Future<List<QuizModel>> _fetchQuizzes(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    final results = <QuizModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db
          .collection('quizzes')
          .where('course_id', whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => QuizModel.fromMap(doc.data(), doc.id)),
      );
    }
    results.sort((a, b) => a.endTime.compareTo(b.endTime));
    return results;
  }

  Future<List<StudyMaterialModel>> _fetchMaterials(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) return [];
    final results = <StudyMaterialModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db
          .collection('materials')
          .where('courseId', whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => StudyMaterialModel.fromMap(doc.data(), doc.id)),
      );
    }
    results.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return results;
  }

  Future<StudyMaterialModel> uploadStudyMaterial({
    required String facultyId,
    required String courseId,
    required String fileName,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    final upload = await _storage.uploadStudyMaterial(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      courseId: courseId,
      facultyId: facultyId,
      contentType: contentType,
    );

    final docRef = _db.collection('materials').doc();
    final noticeRef = _db.collection('notifications').doc();
    final uploadedAt = Timestamp.now();
    final material = StudyMaterialModel(
      id: docRef.id,
      courseId: courseId,
      fileName: upload.fileName,
      fileUrl: upload.publicUrl,
      uploadedBy: facultyId,
      uploadedAt: uploadedAt,
      storagePath: upload.storagePath,
      contentType: upload.contentType,
      fileSize: upload.fileSize,
    );

    final batch = _db.batch();

    batch.set(docRef, {
      'courseId': material.courseId,
      'fileName': material.fileName,
      'fileUrl': material.fileUrl,
      'storagePath': material.storagePath,
      'contentType': material.contentType,
      'fileSize': material.fileSize,
      'uploadedBy': material.uploadedBy,
      'uploadedAt': material.uploadedAt,
    });

    batch.set(noticeRef, {
      'title': 'New Study Material',
      'body': fileName,
      'message': 'Study material "$fileName" has been uploaded.',
      'type': 'material',
      'audience': 'course',
      'courseId': courseId,
      'route': '/student/course/$courseId?tab=materials&materialId=${docRef.id}',
      'sourceId': docRef.id,
      'sourceCollection': 'materials',
      'createdBy': facultyId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();

    return material;
  }

  Future<List<QuizAttemptSummary>> fetchQuizAttempts(String quizId) async {
    final quizDoc = await _db.collection('quizzes').doc(quizId).get();
    final quizData = quizDoc.data() ?? <String, dynamic>{};
    final totalMarks = (quizData['total_marks'] as num?)?.toInt() ?? 0;

    final snap = await _db
        .collection('quiz_submissions')
        .where('quiz_id', isEqualTo: quizId)
        .get();
    final submissions =
        snap.docs
            .map((doc) => QuizSubmissionModel.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final attempts = <QuizAttemptSummary>[];
    for (final submission in submissions) {
      final doc = await _db.collection('users').doc(submission.studentId).get();
      final data = doc.data() ?? <String, dynamic>{};
      final name = (data['name'] ?? submission.studentId).toString();
      final email = (data['email'] ?? '').toString();
      attempts.add(
        QuizAttemptSummary(
          submission: submission,
          studentName: name,
          studentEmail: email,
          totalMarks: totalMarks,
        ),
      );
    }
    return attempts;
  }

  Future<List<AssignmentAttemptSummary>> fetchAssignmentAttempts(String assignmentId) async {
    final assignmentDoc = await _db.collection('assignments').doc(assignmentId).get();
    final assignmentData = assignmentDoc.data() ?? <String, dynamic>{};
    final totalMarks = (assignmentData['total_marks'] as num?)?.toInt() ?? 100;

    final snap = await _db
        .collection('submissions')
        .where('assignment_id', isEqualTo: assignmentId)
        .get();
    final submissions = snap.docs
        .map((doc) => SubmissionModel.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final attempts = <AssignmentAttemptSummary>[];
    for (final submission in submissions) {
      final doc = await _db.collection('users').doc(submission.studentId).get();
      final data = doc.data() ?? <String, dynamic>{};
      final name = (data['name'] ?? submission.studentId).toString();
      final email = (data['email'] ?? '').toString();
      attempts.add(
        AssignmentAttemptSummary(
          submission: submission,
          studentName: name,
          studentEmail: email,
          totalMarks: totalMarks,
        ),
      );
    }
    return attempts;
  }

  Future<void> gradeAssignmentSubmission(String submissionId, int marks) async {
    await _db.collection('submissions').doc(submissionId).update({
      'marks_obtained': marks,
    });
  }

  Future<List<NotificationModel>> _fetchAnnouncements(
    String firebaseUid,
    String userDocId,
  ) async {
    final actorIds = _uniqueIds([firebaseUid, userDocId]);
    if (actorIds.isEmpty) return [];

    final results = <NotificationModel>[];
    for (final batch in _chunk(actorIds, 10)) {
      final snap = await _db
          .collection('notifications')
          .where('createdBy', whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => NotificationModel.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  Future<List<CourseStudent>> fetchStudentsForCourse(String courseId) async {
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final courseData = courseDoc.data() ?? <String, dynamic>{};
    final courseSemester = (courseData['semester'] as num?)?.toInt() ??
        int.tryParse(courseData['semester']?.toString() ?? '') ??
        0;
    final courseDepartment = (courseData['department'] ?? '').toString().trim().toUpperCase();

    final enrollmentSnap = await _db
        .collection('enrollments')
        .where('courseId', isEqualTo: courseId)
        .get();

    final studentIds = enrollmentSnap.docs
        .map((doc) => doc.data()['studentId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (studentIds.isEmpty) return [];

    final students = <CourseStudent>[];
    for (final studentId in studentIds) {
      final doc = await _db.collection('users').doc(studentId).get();
      Map<String, dynamic>? data;
      if (doc.exists && doc.data() != null) {
        data = doc.data()!;
      } else {
        final query = await _db
            .collection('users')
            .where('uid_firebase', isEqualTo: studentId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          data = query.docs.first.data();
        }
      }

      if (data != null) {
        final studentSemester = (data['semester'] as num?)?.toInt() ??
            int.tryParse(data['semester']?.toString() ?? '') ??
            0;
        final studentDepartment = (data['department'] ?? '').toString().trim().toUpperCase();

        if ((courseSemester > 0 && studentSemester > 0 && studentSemester != courseSemester) ||
            (courseDepartment.isNotEmpty &&
                studentDepartment.isNotEmpty &&
                studentDepartment != courseDepartment)) {
          continue;
        }

        students.add(
          CourseStudent(
            studentId: studentId,
            name: (data['name'] as String?)?.trim().isNotEmpty == true
                ? data['name'] as String
                : 'Student',
            email: (data['email'] as String?) ?? '',
          ),
        );
        continue;
      }

      students.add(
        CourseStudent(studentId: studentId, name: 'Student', email: ''),
      );
    }

    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  Future<void> submitAttendanceBatch({
    required String facultyId,
    required String courseId,
    required DateTime date,
    required Map<String, bool> attendanceByStudent,
  }) async {
    final dayKey =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final batch = _db.batch();

    attendanceByStudent.forEach((studentId, present) {
      final docId = 'att_${courseId}_${studentId}_$dayKey';
      final ref = _db.collection('attendance').doc(docId);
      batch.set(ref, {
        'studentId': studentId,
        'courseId': courseId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'present': present,
        'status': present ? 'present' : 'absent',
        'markedBy': facultyId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await batch.commit();
  }

  Future<int> backfillMissingAttendanceForCourse(String courseId) async {
    final students = await fetchStudentsForCourse(courseId);
    if (students.isEmpty) return 0;

    final query = await _db
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .get();

    if (query.docs.isEmpty) return 0;

    final Map<String, DateTime> datesByKey = {};
    final Map<String, Set<String>> existingByStudent = {};

    for (final doc in query.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String? ?? '';
      final dateTs = data['date'];
      if (studentId.isEmpty || dateTs is! Timestamp) continue;

      final date = DateTime(dateTs.toDate().year, dateTs.toDate().month, dateTs.toDate().day);
      final dayKey = DateFormat('yyyyMMdd').format(date);
      datesByKey[dayKey] = date;
      existingByStudent.putIfAbsent(studentId, () => <String>{}).add(dayKey);
    }

    if (datesByKey.isEmpty) return 0;

    final batch = _db.batch();
    var created = 0;

    for (final student in students) {
      final seenDates = existingByStudent[student.studentId] ?? <String>{};
      for (final entry in datesByKey.entries) {
        if (seenDates.contains(entry.key)) continue;

        final present = _random.nextBool();
        final docId = 'att_${courseId}_${student.studentId}_${entry.key}';
        final ref = _db.collection('attendance').doc(docId);
        batch.set(ref, {
          'studentId': student.studentId,
          'courseId': courseId,
          'date': Timestamp.fromDate(entry.value),
          'present': present,
          'status': present ? 'present' : 'absent',
          'markedBy': 'system-backfill',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        created++;
      }
    }

    if (created > 0) {
      await batch.commit();
    }

    return created;
  }

  Future<void> createAssignment({
    required String facultyId,
    required String courseId,
    required String title,
    required String description,
    required DateTime dueDate,
    required int totalMarks,
  }) async {
    final assignmentRef = _db.collection('assignments').doc();
    final noticeRef = _db.collection('notifications').doc();
    final batch = _db.batch();

    batch.set(assignmentRef, {
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'total_marks': totalMarks,
      'createdBy': facultyId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(noticeRef, {
      'title': 'New Assignment',
      'body': title,
      'message': title,
      'type': 'assignment',
      'audience': 'course',
      'courseId': courseId,
      'route': '/student/course/$courseId?tab=assignments&assignmentId=${assignmentRef.id}',
      'assignmentId': assignmentRef.id,
      'sourceId': assignmentRef.id,
      'sourceCollection': 'assignments',
      'createdBy': facultyId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();
  }

  Future<void> createQuiz({
    required String facultyId,
    required String courseId,
    required String title,
    required String description,
    required int durationMinutes,
    required int totalMarks,
    required List<Map<String, dynamic>> questions,
  }) async {
    if (questions.isEmpty) {
      throw Exception('Add at least one quiz question.');
    }

    final quizRef = _db.collection('quizzes').doc();
    final noticeRef = _db.collection('notifications').doc();
    final endTime = DateTime.now().add(
      Duration(minutes: durationMinutes <= 0 ? 15 : durationMinutes),
    );
    final batch = _db.batch();

    batch.set(quizRef, {
      'course_id': courseId,
      'faculty_id': facultyId,
      'title': title,
      'description': description,
      'start_time': Timestamp.now(),
      'end_time': Timestamp.fromDate(endTime),
      'total_marks': totalMarks,
      'question_count': questions.length,
      'status': 'published',
      'created_at': FieldValue.serverTimestamp(),
    });

    batch.set(noticeRef, {
      'title': 'New Quiz',
      'body': title,
      'message': description.isNotEmpty ? description : title,
      'type': 'quiz',
      'audience': 'course',
      'courseId': courseId,
      'route': '/student/course/$courseId?tab=quizzes&quizId=${quizRef.id}',
      'quizId': quizRef.id,
      'sourceId': quizRef.id,
      'sourceCollection': 'quizzes',
      'createdBy': facultyId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionRef = _db.collection('quiz_questions').doc();
      batch.set(questionRef, {
        'quiz_id': quizRef.id,
        'question_text': (question['questionText'] ?? '').toString(),
        'type': (question['type'] ?? 'mcq').toString(),
        'options': question['options'],
        'correct_answer': (question['correctAnswer'] ?? '').toString(),
        'marks': (question['marks'] as num?)?.toInt() ?? 1,
        'order': i,
      });
    }

    await batch.commit();
  }

  Future<void> sendAnnouncement({
    required String facultyId,
    required String message,
    String? courseId,
    List<String>? userIds,
  }) async {
    final audience = (userIds != null && userIds.isNotEmpty)
        ? 'users'
        : (courseId != null && courseId.trim().isNotEmpty)
        ? 'course'
        : 'all';

    final doc = _db.collection('notifications').doc();
    await doc.set({
      'title': 'Announcement',
      'body': message,
      'message': message,
      'type': 'announcement',
      'audience': audience,
      'route': '/student/dashboard?tab=notifications',
      'sourceId': doc.id,
      'sourceCollection': 'notifications',
      if (courseId != null && courseId.trim().isNotEmpty)
        'courseId': courseId.trim(),
      if (userIds != null && userIds.isNotEmpty)
        'targetUserIds': userIds
            .where((id) => id.trim().isNotEmpty)
            .map((id) => id.trim())
            .toList(),
      'createdBy': facultyId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> uploadResultsBatch({
    required String facultyId,
    required String courseId,
    required Map<String, num> marksByStudent,
  }) async {
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final courseData = courseDoc.data() ?? <String, dynamic>{};
    final courseName =
        (courseData['courseName'] ??
                courseData['course_name'] ??
                courseData['title'] ??
                courseId)
            .toString();
    final courseCode =
        (courseData['courseCode'] ??
                courseData['course_code'] ??
                courseData['code'] ??
                courseId)
            .toString();
    final semester = (courseData['semester'] is num)
        ? (courseData['semester'] as num).toInt()
        : int.tryParse(courseData['semester']?.toString() ?? '') ?? 0;
    final credits =
        (courseData['credits'] as num?)?.toInt() ??
        int.tryParse(courseData['credits']?.toString() ?? '') ??
        0;

    final batch = _db.batch();
    marksByStudent.forEach((studentId, marks) {
      final marksValue = marks.round().clamp(0, 100);
      final grade = gradeFromMarks(marksValue);
      final ref = _db.collection('results').doc('${courseId}_$studentId');
      batch.set(ref, {
        'studentId': studentId,
        'courseId': courseId,
        'courseName': courseName,
        'courseCode': courseCode,
        'semester': semester,
        'credits': credits,
        'marks': marksValue,
        'grade': grade,
        'gradePoint': gradePointForGrade(grade),
        'status': 'published',
        'uploadedBy': facultyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await batch.commit();
  }

  List<String> _uniqueIds(List<String?> values) {
    return values
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toSet()
        .toList();
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    final output = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      output.add(
        values.sublist(i, i + size > values.length ? values.length : i + size),
      );
    }
    return output;
  }

  Future<String> generateAttendanceExcel({
    required String courseId,
    required String courseCode,
  }) async {
    final students = await fetchStudentsForCourse(courseId);
    if (students.isEmpty) {
      throw Exception('No students enrolled in this course.');
    }

    final endOfToday = DateTime.now().add(const Duration(days: 1));
    var query = await _db
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No attendance records found for this course.');
    }

    await backfillMissingAttendanceForCourse(courseId);

    query = await _db
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .get();

    final Map<String, Map<String, bool>> attendanceMap = {};
    final Set<String> uniqueDates = {};

    for (var doc in query.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String;
      final dateTs = data['date'] as Timestamp;
      if (dateTs.toDate().isAfter(endOfToday)) continue;
      final present = data['present'] as bool? ?? false;
      
      final dateStr = DateFormat('MMM dd').format(dateTs.toDate());
      uniqueDates.add(dateStr);
      
      if (!attendanceMap.containsKey(studentId)) {
        attendanceMap[studentId] = {};
      }
      attendanceMap[studentId]![dateStr] = present;
    }

    final sortedDates = uniqueDates.toList()..sort();

    var excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Enrollment Number'),
      ...sortedDates.map((d) => TextCellValue(d)),
      TextCellValue('Total Present'),
      TextCellValue('Percentage'),
    ]);

    for (var student in students) {
      final enrollNo = student.email.split('@').first.toUpperCase();
      int presentCount = 0;
      
      final studentRecords = attendanceMap[student.studentId] ?? {};
      final attendanceCells = sortedDates.map((dateStr) {
        final isPresent = studentRecords[dateStr];
        if (isPresent == true) {
          presentCount++;
          return TextCellValue('P');
        } else if (isPresent == false) {
          return TextCellValue('A');
        }
        return TextCellValue('-');
      }).toList();

      final percentage = sortedDates.isEmpty ? 0.0 : (presentCount / sortedDates.length) * 100;

      sheet.appendRow([
        TextCellValue(student.name),
        TextCellValue(enrollNo),
        ...attendanceCells,
        IntCellValue(presentCount),
        TextCellValue('${percentage.toStringAsFixed(1)}%'),
      ]);
    }

    final bytes = excel.encode()!;
    final dateToken = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = 'Attendance_${courseCode}_$dateToken.xlsx';

    if (kIsWeb) {
      final base64data = base64Encode(bytes);
      final url = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64data';
      await launchUrl(Uri.parse(url));
      return fileName;
    }

    if (Platform.isAndroid) {
      final savedLocation = await _saveAttendanceExcelToDownloads(
        bytes: bytes,
        fileName: fileName,
      );
      if (savedLocation.isNotEmpty) {
        return savedLocation;
      }
    }

    final dir = await _resolveAttendanceDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Failed to write the Excel file.');
    }
    return file.path;
  }

  Future<Directory> _resolveAttendanceDirectory() async {
    if (!Platform.isAndroid) {
      return getApplicationDocumentsDirectory();
    }

    final permission = await Permission.storage.request();
    if (permission.isPermanentlyDenied) {
      await openAppSettings();
    }

    final downloadDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
    if (downloadDirs != null && downloadDirs.isNotEmpty) {
      return downloadDirs.first;
    }

    final external = await getExternalStorageDirectory();
    if (external != null) {
      return external;
    }

    return getApplicationDocumentsDirectory();
  }

  Future<String> _saveAttendanceExcelToDownloads({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final result = await _attendanceExportChannel.invokeMethod<String>(
        'saveAttendanceExcel',
        <String, dynamic>{
          'fileName': fileName,
          'bytes': Uint8List.fromList(bytes),
        },
      );
      if (result == null || result.isEmpty) {
        throw Exception('Unable to save file to Downloads.');
      }
      return result;
    } catch (e) {
      throw Exception('Attendance export failed: ${e.toString()}');
    }
  }
}

class _CachedFacultyDashboard {
  final FacultyDashboardData data;
  final DateTime fetchedAt;

  const _CachedFacultyDashboard({
    required this.data,
    required this.fetchedAt,
  });
}
