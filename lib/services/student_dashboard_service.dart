import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/notification.dart';
import '../models/quiz_model.dart';
import '../models/quiz_question_model.dart';
import '../models/quiz_submission_model.dart';
import '../models/submission_model.dart';
import '../models/study_material.dart';
import '../models/semester_registration.dart';
import '../models/student_dashboard_data.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import 'admin_module_service.dart';
import 'dart:typed_data';
import 'local_cache_service.dart';
import 'semester_registration_service.dart';
import 'storage_service.dart';

class StudentDashboardService {
  StudentDashboardService._privateConstructor();

  static final StudentDashboardService instance =
      StudentDashboardService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, _CachedStudentDashboard> _dashboardCache = {};
  static const Duration _dashboardCacheTtl = Duration(seconds: 20);
  static const Duration _diskCacheTtl = Duration(hours: 1);

  Future<StudentDashboardData> loadDashboard({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(
      firebaseUid: firebaseUid,
      user: user,
      studentProfile: studentProfile,
    );
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
    final candidateIds = _candidateIds(
      firebaseUid: firebaseUid,
      user: user,
      studentProfile: studentProfile,
    );
    final latestSemester = await _resolveLatestSemester(
      candidateIds: candidateIds,
      fallback: studentProfile?.semester,
    );

    if ((latestSemester ?? 0) > 0) {
      final seedStudentId = firebaseUid.trim().isNotEmpty
          ? firebaseUid.trim()
          : (user.uidFirebase.trim().isNotEmpty ? user.uidFirebase.trim() : user.id.trim());
      if (seedStudentId.isNotEmpty) {
        final department = studentProfile?.department.trim().isNotEmpty == true
            ? studentProfile!.department.trim()
            : user.department.trim();
        if (department.isNotEmpty) {
          await AdminModuleService.instance.seedSemesterEnrollments(
            studentId: seedStudentId,
            department: department,
            semester: latestSemester!,
          );
        }
      }
    }

    var currentEnrollments = await _fetchEnrollments(
      collection: 'enrollments',
      candidateIds: candidateIds,
    );
    final upcomingEnrollments = await _fetchEnrollments(
      collection: 'upcomingEnrollments',
      candidateIds: candidateIds,
    );

    final currentSemesterFilter = latestSemester;
    if (currentSemesterFilter != null && currentSemesterFilter > 0) {
      currentEnrollments = currentEnrollments.where((doc) => _semesterFromData(doc) == currentSemesterFilter).toList();
    }

    final visibleUpcomingEnrollments = (currentSemesterFilter != null && currentSemesterFilter > 0)
        ? upcomingEnrollments.where((doc) {
            final semester = _semesterFromData(doc);
            return semester != null && semester > currentSemesterFilter;
          }).toList()
        : upcomingEnrollments;

    final approvedCurrentSemesterCourseIds = await _fetchApprovedRegistrationCourseIds(
      candidateIds: candidateIds,
      semester: currentSemesterFilter,
    );
    final approvedUpcomingCourseIds = upcomingEnrollments
        .where((doc) => _status(doc) == 'approved')
        .map((doc) => _string(doc['courseId']) ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toList();

    final currentCourseIds = {
      ...currentEnrollments.map((doc) => _string(doc['courseId']) ?? ''),
      ...approvedCurrentSemesterCourseIds,
      ...approvedUpcomingCourseIds,
    }.where((id) => id.trim().isNotEmpty).toList();

    final upcomingCourseIds = visibleUpcomingEnrollments
        .where((doc) => _status(doc) != 'approved')
        .map((doc) => _string(doc['courseId']) ?? '')
        .toSet()
        .toList();
    final allCourseIds = {...currentCourseIds, ...upcomingCourseIds}.toList();

    final courses = await _fetchCourses(allCourseIds);
    final courseById = {for (final course in courses) course.courseId: course};
    final facultyNames = await _fetchFacultyNames(
      courses.map((course) => course.facultyId).where((id) => id.isNotEmpty).toSet().toList(),
    );

    final attendanceFuture = _fetchAttendance(candidateIds, currentCourseIds);
    final assignmentsFuture = _fetchAssignments(currentCourseIds);
    final quizzesFuture = _fetchQuizzes(currentCourseIds, courseById);
    final quizSubmissionsFuture = _fetchQuizSubmissions(candidateIds);
    final studyMaterialsFuture = _fetchStudyMaterials(allCourseIds, courseById);
    final notificationsFuture = _fetchNotifications(
      candidateIds: candidateIds,
      courseIds: allCourseIds,
    );
    final registrationOpenFuture = latestSemester != null && latestSemester > 0
        ? SemesterRegistrationService.instance.isRegistrationOpen(
            semester: latestSemester + 1,
            department: studentProfile?.department.trim().isNotEmpty == true
                ? studentProfile!.department.trim()
                : user.department.trim(),
          )
        : Future.value(false);
    final nextSemesterRegistrationFuture = _fetchNextSemesterRegistration(
      candidateIds: candidateIds,
      currentSemester: latestSemester,
    );

    final results = await Future.wait([
      attendanceFuture,
      assignmentsFuture,
      quizzesFuture,
      quizSubmissionsFuture,
      studyMaterialsFuture,
      notificationsFuture,
      registrationOpenFuture,
      nextSemesterRegistrationFuture,
    ]);

    final attendanceRecords = results[0] as List<AttendanceModel>;
    final assignments = results[1] as List<AssignmentModel>;
    final quizzes = results[2] as List<QuizDashboardItem>;
    final quizSubmissions = results[3] as List<QuizSubmissionModel>;
    final studyMaterials = results[4] as List<StudyMaterialDashboardItem>;
    final notifications = results[5] as List<NotificationModel>;
    final registrationOpen = results[6] as bool;
    final nextSemesterRegistration = results[7] as SemesterRegistrationRecord?;

    final attendanceByCourse = <String, List<AttendanceModel>>{};
    for (final record in attendanceRecords) {
      attendanceByCourse.putIfAbsent(record.courseId, () => []).add(record);
    }

    final taskByCourse = <String, List<AssignmentModel>>{};
    final pendingTasks = <DashboardTaskItem>[];
    final taskNow = DateTime.now();
    for (final assignment in assignments) {
      final course = courseById[assignment.courseId];
      if (course == null) {
        continue;
      }

      pendingTasks.add(
        DashboardTaskItem(
          assignment: assignment,
          courseCode: course.code,
          isOverdue: assignment.dueDate.toDate().isBefore(taskNow),
        ),
      );
      taskByCourse.putIfAbsent(course.courseId, () => []).add(assignment);
    }
    pendingTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final currentCourseSummaries = currentCourseIds
        .map((courseId) => courseById[courseId])
        .whereType<CourseModel>()
        .map((course) {
      final attendance = buildAttendanceSummary(
        courseId: course.courseId,
        records: attendanceByCourse[course.courseId] ?? const <AttendanceModel>[],
      );

      final tasksForCourse = taskByCourse[course.courseId] ?? const <AssignmentModel>[];
      final dueDates = tasksForCourse.map((assignment) => assignment.dueDate.toDate()).toList();
      dueDates.sort();

      return CourseDashboardItem(
        course: course,
        facultyName: course.facultyName.isNotEmpty
            ? course.facultyName
            : facultyNames[course.facultyId] ?? 'Faculty',
        attendancePercentage: attendance.percentage,
        presentClasses: attendance.presentClasses,
        totalClasses: attendance.totalClasses,
        pendingTaskCount: tasksForCourse.length,
        nextDeadline: dueDates.isEmpty ? null : dueDates.first,
      );
    }).toList()
      ..sort((a, b) => a.course.code.compareTo(b.course.code));

    final upcomingCourseSummaries = upcomingCourseIds
        .map((courseId) => courseById[courseId])
        .whereType<CourseModel>()
        .map(
          (course) => UpcomingCourseDashboardItem(
            course: course,
            facultyName: course.facultyName.isNotEmpty
                ? course.facultyName
                : facultyNames[course.facultyId] ?? 'Faculty',
          ),
        )
        .toList()
      ..sort((a, b) => a.course.code.compareTo(b.course.code));

    final totalPresent = attendanceRecords.where((record) => record.present).length;
    final overallAttendance = attendanceRecords.isEmpty
        ? 0.0
        : (totalPresent / attendanceRecords.length) * 100;

    final data = StudentDashboardData(
      user: user,
      studentProfile: studentProfile,
      overallAttendance: overallAttendance,
      attendanceRecords: attendanceRecords,
      currentCourses: currentCourseSummaries,
      upcomingCourses: upcomingCourseSummaries,
      pendingTasks: pendingTasks,
      quizzes: quizzes,
      quizSubmissions: quizSubmissions,
      studyMaterials: studyMaterials,
      notifications: notifications
          .where((n) => n.title != 'Welcome to UniFlow')
          .map((notification) => DashboardNotificationItem(notification: notification))
          .toList(),
      nextDeadline: pendingTasks.isEmpty ? null : pendingTasks.first.dueDate,
      nextSemesterRegistration: nextSemesterRegistration,
      registrationOpen: registrationOpen,
    );

    _dashboardCache[cacheKey] = _CachedStudentDashboard(
      data: data,
      fetchedAt: DateTime.now(),
    );
    await _writeCachedDashboard(cacheKey, data);
    return data;
  }

  Stream<StudentDashboardData> watchDashboard({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
    bool forceRefresh = false,
  }) {
    return Stream<StudentDashboardData>.fromFuture(
      loadDashboard(
        firebaseUid: firebaseUid,
        user: user,
        studentProfile: studentProfile,
        forceRefresh: forceRefresh,
      ),
    );
  }

  Future<StudentDashboardData?> _readCachedDashboard(String cacheKey) async {
    final map = await LocalCacheService.instance.readJson(cacheKey);
    if (map == null) return null;
    try {
      final cachedAt = _timestamp(map['cachedAt']);
      if (cachedAt != null && DateTime.now().difference(cachedAt.toDate()) > _diskCacheTtl) {
        return null;
      }
      final payload = _map(map['payload']);
      return StudentDashboardData.fromMap(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedDashboard(String cacheKey, StudentDashboardData data) async {
    await LocalCacheService.instance.writeJson(cacheKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'payload': data.toMap(),
    });
  }

  String _cacheKey({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
  }) {
    return [
      firebaseUid.trim(),
      user.id.trim(),
      user.role.trim().toLowerCase(),
      user.department.trim().toLowerCase(),
      user.semester.toString(),
      studentProfile?.semester.toString() ?? '',
      studentProfile?.department.trim().toLowerCase() ?? '',
      studentProfile?.section.trim().toLowerCase() ?? '',
    ].join('|');
  }

  Future<List<Map<String, dynamic>>> _fetchEnrollments({
    required String collection,
    required List<String> candidateIds,
  }) async {
    if (candidateIds.isEmpty) {
      return [];
    }

    final results = <Map<String, dynamic>>[];
    for (final batch in _chunk(candidateIds, 10)) {
      final snap = await _db
          .collection(collection)
          .where('studentId', whereIn: batch)
          .get();
      results.addAll(snap.docs.map((doc) => doc.data()));
    }
    return results;
  }

  Future<List<CourseModel>> _fetchCourses(List<String> courseIds) async {
    if (courseIds.isEmpty) {
      return [];
    }

    final refs = courseIds.map((courseId) => _db.collection('courses').doc(courseId));
    final snaps = await Future.wait(refs.map((ref) => ref.get()));
    return snaps
        .where((snap) => snap.exists && snap.data() != null)
        .map((snap) => CourseModel.fromMap(snap.data() as Map<String, dynamic>, snap.id))
        .toList();
  }

  Future<Map<String, String>> _fetchFacultyNames(List<String> facultyIds) async {
    if (facultyIds.isEmpty) {
      return {};
    }

    final result = <String, String>{};
    for (final facultyId in facultyIds) {
      final doc = await _db.collection('users').doc(facultyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = _string(data['name']);
        result[facultyId] = name != null && name.trim().isNotEmpty ? name : 'Faculty';
        continue;
      }

      final query = await _db
          .collection('users')
          .where('uid_firebase', isEqualTo: facultyId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        result[facultyId] = _string(query.docs.first.data()['name']) ?? 'Faculty';
      }
    }
    return result;
  }

  Future<List<AttendanceModel>> _fetchAttendance(
    List<String> candidateIds,
    List<String> courseIds,
  ) async {
    if (candidateIds.isEmpty) {
      return [];
    }

    final results = <AttendanceModel>[];
    for (final batch in _chunk(candidateIds, 10)) {
      final snap = await _db
          .collection('attendance')
          .where('studentId', whereIn: batch)
          .get();
      results.addAll(
        snap.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .where((record) => courseIds.isEmpty || courseIds.contains(record.courseId)),
      );
    }
    return results;
  }

  Future<List<AssignmentModel>> _fetchAssignments(List<String> courseIds) async {
    if (courseIds.isEmpty) {
      return [];
    }

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
    results.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return results;
  }

  Future<List<QuizDashboardItem>> _fetchQuizzes(
    List<String> courseIds,
    Map<String, CourseModel> courseById,
  ) async {
    if (courseIds.isEmpty) return [];

    final quizzes = <QuizModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db.collection('quizzes').where('course_id', whereIn: batch).get();
      quizzes.addAll(snap.docs.map((doc) => QuizModel.fromMap(doc.data(), doc.id)));
    }
    quizzes.sort((a, b) => a.endTime.compareTo(b.endTime));

    final quizIds = quizzes.map((quiz) => quiz.id).toList();
    final questionCounts = await _fetchQuizQuestionCounts(quizIds);

    return quizzes.map((quiz) {
      final course = courseById[quiz.courseId];
      return QuizDashboardItem(
        quiz: quiz,
        courseCode: course?.code ?? quiz.courseId,
        courseTitle: course?.title ?? quiz.courseId,
        questionCount: questionCounts[quiz.id] ?? 0,
      );
    }).toList();
  }

  Future<List<QuizSubmissionModel>> _fetchQuizSubmissions(List<String> candidateIds) async {
    if (candidateIds.isEmpty) return [];

    final results = <QuizSubmissionModel>[];
    for (final batch in _chunk(candidateIds, 10)) {
      final snap = await _db.collection('quiz_submissions').where('student_id', whereIn: batch).get();
      results.addAll(snap.docs.map((doc) => QuizSubmissionModel.fromMap(doc.data(), doc.id)));
    }
    results.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return results;
  }

  Future<Map<String, int>> _fetchQuizQuestionCounts(List<String> quizIds) async {
    if (quizIds.isEmpty) return {};

    final counts = <String, int>{};
    for (final batch in _chunk(quizIds, 10)) {
      final snap = await _db.collection('quiz_questions').where('quiz_id', whereIn: batch).get();
      for (final doc in snap.docs) {
        final quizId = (doc.data()['quiz_id'] ?? '').toString();
        if (quizId.isEmpty) continue;
        counts[quizId] = (counts[quizId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<List<StudyMaterialDashboardItem>> _fetchStudyMaterials(
    List<String> courseIds,
    Map<String, CourseModel> courseById,
  ) async {
    if (courseIds.isEmpty) return [];

    final materials = <StudyMaterialModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db.collection('materials').where('courseId', whereIn: batch).get();
      materials.addAll(snap.docs.map((doc) => StudyMaterialModel.fromMap(doc.data(), doc.id)));
    }
    materials.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return materials.map((material) {
      final course = courseById[material.courseId];
      return StudyMaterialDashboardItem(
        material: material,
        courseCode: course?.code ?? material.courseId,
        courseTitle: course?.title ?? material.courseId,
      );
    }).toList();
  }

  Future<QuizModel?> fetchQuizById(String quizId) async {
    final doc = await _db.collection('quizzes').doc(quizId).get();
    if (!doc.exists || doc.data() == null) return null;
    return QuizModel.fromMap(doc.data()!, doc.id);
  }

  Future<QuizSubmissionModel?> fetchQuizSubmissionForStudent({
    required String quizId,
    required String studentId,
  }) async {
    final doc = await _db.collection('quiz_submissions').doc('${quizId}_$studentId').get();
    if (!doc.exists || doc.data() == null) return null;
    return QuizSubmissionModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<QuizQuestionModel>> fetchQuizQuestions(String quizId) async {
    final snap = await _db.collection('quiz_questions').where('quiz_id', isEqualTo: quizId).get();
    final questions = snap.docs.map((doc) => QuizQuestionModel.fromMap(doc.data(), doc.id)).toList();
    questions.sort((a, b) => a.id.compareTo(b.id));
    return questions;
  }

  Future<void> submitQuizAttempt({
    required String quizId,
    required String studentId,
    required Map<String, String> answers,
  }) async {
    final existing = await fetchQuizSubmissionForStudent(quizId: quizId, studentId: studentId);
    if (existing != null) {
      throw Exception('You have already submitted this quiz.');
    }

    final quiz = await fetchQuizById(quizId);
    if (quiz == null) {
      throw Exception('Quiz not found.');
    }

    final questions = await fetchQuizQuestions(quizId);
    var score = 0;
    for (final question in questions) {
      final answer = (answers[question.id] ?? '').trim().toLowerCase();
      final correct = question.correctAnswer.trim().toLowerCase();
      if (answer.isNotEmpty && answer == correct) {
        score += question.marks;
      }
    }

    await _db.collection('quiz_submissions').doc('${quizId}_$studentId').set(
      {
        'quiz_id': quizId,
        'student_id': studentId,
        'answers': answers,
        'score': score,
        'total_marks': quiz.totalMarks,
        'submitted_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<SubmissionModel?> fetchAssignmentSubmissionForStudent({
    required String assignmentId,
    required String studentId,
  }) async {
    final snap = await _db
        .collection('submissions')
        .where('assignment_id', isEqualTo: assignmentId)
        .where('student_id', isEqualTo: studentId)
        .get();

    if (snap.docs.isEmpty) return null;
    return SubmissionModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  Future<void> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String courseId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final existing = await fetchAssignmentSubmissionForStudent(
      assignmentId: assignmentId,
      studentId: studentId,
    );

    if (existing != null) {
      throw Exception('You have already submitted this assignment.');
    }

    final upload = await StorageService.instance.uploadStudyMaterial(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      courseId: courseId,
      facultyId: studentId, // Using facultyId parameter for student doc folder path in this bucket instance
    );

    await _db.collection('submissions').doc().set({
      'assignment_id': assignmentId,
      'student_id': studentId,
      'file_url': upload.publicUrl,
      'marks_obtained': null,
      'submitted_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<NotificationModel>> _fetchNotifications({
    required List<String> candidateIds,
    required List<String> courseIds,
  }) async {
    final resultsByKey = <String, NotificationModel>{};

    Future<void> addQuery(Future<QuerySnapshot<Map<String, dynamic>>> Function() run) async {
      final snap = await run();
      for (final doc in snap.docs) {
        final data = doc.data();
        final notification = NotificationModel.fromMap(data, doc.id);
        final key = _notificationDedupKey(data);
        resultsByKey[key] = notification;
      }
    }

    for (final batch in _chunk(candidateIds, 10)) {
      await addQuery(() => _db.collection('notifications').where('userId', whereIn: batch).get());
      await addQuery(() => _db.collection('notifications').where('targetUserIds', arrayContainsAny: batch).get());
    }

    for (final batch in _chunk(courseIds, 10)) {
      await addQuery(() => _db.collection('notifications').where('courseId', whereIn: batch).get());
    }

    await addQuery(() => _db.collection('notifications').where('audience', isEqualTo: 'all').get());

    final results = resultsByKey.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  Future<Set<String>> _fetchApprovedRegistrationCourseIds({
    required List<String> candidateIds,
    required int? semester,
  }) async {
    if (candidateIds.isEmpty || semester == null || semester <= 0) {
      return <String>{};
    }

    final courseIds = <String>{};
    for (final batch in _chunk(candidateIds, 10)) {
      final snap = await _db.collection('registrations').where('studentId', whereIn: batch).get();
      for (final doc in snap.docs) {
        final record = SemesterRegistrationRecord.fromMap(doc.data(), doc.id);
        if (record.status != 'approved' || record.targetSemester != semester) {
          continue;
        }
        courseIds.addAll(record.selectedCourseIds);
        courseIds.addAll(record.backlogCourseIds);
      }
    }
    return courseIds;
  }

  Future<SemesterRegistrationRecord?> _fetchNextSemesterRegistration({
    required List<String> candidateIds,
    required int? currentSemester,
  }) async {
    if (candidateIds.isEmpty || currentSemester == null || currentSemester <= 0) {
      return null;
    }

    final targetSemester = currentSemester + 1;
    final records = <SemesterRegistrationRecord>[];
    for (final batch in _chunk(candidateIds, 10)) {
      final snap = await _db.collection('registrations').where('studentId', whereIn: batch).get();
      records.addAll(
        snap.docs
            .map((doc) => SemesterRegistrationRecord.fromMap(doc.data(), doc.id))
            .where((record) => record.targetSemester == targetSemester),
      );
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final status in ['approved', 'pending', 'rejected']) {
      final match = records.where((record) => record.status == status);
      if (match.isNotEmpty) return match.first;
    }
    return records.isEmpty ? null : records.first;
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  List<String> _uniqueIds(Iterable<String?> ids) {
    return ids
        .where((id) => id != null && id.trim().isNotEmpty)
        .map((id) => id!.trim())
        .toSet()
        .toList();
  }

  List<String> _candidateIds({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
  }) {
    final ids = <String>[
      firebaseUid,
      user.id,
      user.uidFirebase,
    ];

    final profileIds = <String>[
      studentProfile?.id ?? '',
      studentProfile?.userId ?? '',
    ].where((id) => id.trim().isNotEmpty).toList();

    for (final id in profileIds) {
      if (id == firebaseUid || id == user.id || id == user.uidFirebase) {
        ids.add(id);
      }
    }

    return _uniqueIds(ids);
  }

  Future<int?> _resolveLatestSemester({
    required List<String> candidateIds,
    required int? fallback,
  }) async {
    for (final id in candidateIds) {
      final userDoc = await _db.collection('users').doc(id).get();
      final userSemester = _semesterFromData(userDoc.data());
      if (userSemester != null && userSemester > 0) return userSemester;

      final studentDoc = await _db.collection('students').doc(id).get();
      final studentSemester = _semesterFromData(studentDoc.data());
      if (studentSemester != null && studentSemester > 0) return studentSemester;
    }
    return fallback;
  }

  int? _semesterFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['semester'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _notificationDedupKey(Map<String, dynamic> data) {
    final sourceId = (data['sourceId'] ?? '').toString().trim();
    if (sourceId.isNotEmpty) {
      final sourceCollection = (data['sourceCollection'] ?? '').toString().trim();
      if (sourceCollection.isNotEmpty) {
        return '$sourceCollection|$sourceId';
      }
      return sourceId;
    }

    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final courseId = (data['courseId'] ?? '').toString().trim().toLowerCase();
    final title = (data['title'] ?? '').toString().trim().toLowerCase();
    final body = (data['body'] ?? data['message'] ?? '').toString().trim().toLowerCase();
    final audience = (data['audience'] ?? '').toString().trim().toLowerCase();
    return '$type|$courseId|$audience|$title|$body';
  }

  String _status(Map<String, dynamic> data) {
    return _string(data['status'])?.toLowerCase() ?? '';
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
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

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}

class _CachedStudentDashboard {
  final StudentDashboardData data;
  final DateTime fetchedAt;

  const _CachedStudentDashboard({
    required this.data,
    required this.fetchedAt,
  });
}
