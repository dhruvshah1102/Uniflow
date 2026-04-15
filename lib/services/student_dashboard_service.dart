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
import 'semester_registration_service.dart';
import 'storage_service.dart';

class StudentDashboardService {
  StudentDashboardService._privateConstructor();

  static final StudentDashboardService instance =
      StudentDashboardService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<StudentDashboardData> loadDashboard({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
  }) async {
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

    final attendanceRecords = await _fetchAttendance(candidateIds, currentCourseIds);
    final assignments = await _fetchAssignments(currentCourseIds);
    final quizzes = await _fetchQuizzes(currentCourseIds, courseById);
    final quizSubmissions = await _fetchQuizSubmissions(candidateIds);
    final studyMaterials = await _fetchStudyMaterials(allCourseIds, courseById);
    final notifications = await _fetchNotifications(
      candidateIds: candidateIds,
      courseIds: allCourseIds,
    );
    final registrationOpen = latestSemester != null && latestSemester > 0
        ? await SemesterRegistrationService.instance.isRegistrationOpen(
            semester: latestSemester + 1,
            department: studentProfile?.department.trim().isNotEmpty == true
                ? studentProfile!.department.trim()
                : user.department.trim(),
          )
        : false;
    final nextSemesterRegistration = await _fetchNextSemesterRegistration(
      candidateIds: candidateIds,
      currentSemester: latestSemester,
    );

    final attendanceByCourse = <String, List<AttendanceModel>>{};
    for (final record in attendanceRecords) {
      attendanceByCourse.putIfAbsent(record.courseId, () => []).add(record);
    }

    final taskByCourse = <String, List<AssignmentModel>>{};
    final pendingTasks = <DashboardTaskItem>[];
    final now = DateTime.now();
    for (final assignment in assignments) {
      final course = courseById[assignment.courseId];
      if (course == null) {
        continue;
      }

      pendingTasks.add(
        DashboardTaskItem(
          assignment: assignment,
          courseCode: course.code,
          isOverdue: assignment.dueDate.toDate().isBefore(now),
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

    return StudentDashboardData(
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
  }

  Stream<StudentDashboardData> watchDashboard({
    required String firebaseUid,
    required UserModel user,
    StudentModel? studentProfile,
  }) {
    final controller = StreamController<StudentDashboardData>.broadcast();
    final fixedSubscriptions = <StreamSubscription<dynamic>>[];
    final courseSubscriptions = <StreamSubscription<dynamic>>[];
    var closed = false;
    var currentCourseIds = <String>{};
    var refreshInFlight = false;
    var refreshQueued = false;
    Timer? debounceTimer;

    Future<void> emitSnapshot() async {
      if (closed || controller.isClosed) return;
      try {
        final data = await loadDashboard(
          firebaseUid: firebaseUid,
          user: user,
          studentProfile: studentProfile,
        );
        if (!closed && !controller.isClosed) {
          controller.add(data);
        }
      } catch (error, stackTrace) {
        if (!closed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    void scheduleEmitSnapshot() {
      if (closed || controller.isClosed) return;
      refreshQueued = true;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 120), () {
        if (closed || controller.isClosed) return;
        if (refreshInFlight) {
          refreshQueued = true;
          return;
        }

        refreshQueued = false;
        refreshInFlight = true;
        unawaited(() async {
          try {
            await emitSnapshot();
          } finally {
            refreshInFlight = false;
            if (!closed && !controller.isClosed && refreshQueued) {
              scheduleEmitSnapshot();
            }
          }
        }());
      });
    }

    Future<void> resetCourseListeners(Iterable<String> courseIds) async {
      final nextCourseIds = courseIds.where((id) => id.trim().isNotEmpty).map((id) => id.trim()).toSet();
      if (nextCourseIds.length == currentCourseIds.length && nextCourseIds.difference(currentCourseIds).isEmpty) {
        return;
      }

      currentCourseIds = nextCourseIds;
      for (final sub in courseSubscriptions) {
        await sub.cancel();
      }
      courseSubscriptions.clear();

      if (currentCourseIds.isEmpty) {
        return;
      }

      for (final batch in _chunk(currentCourseIds.toList(), 10)) {
        final assignmentSub = _db
            .collection('assignments')
            .where('courseId', whereIn: batch)
            .snapshots()
            .listen((_) => scheduleEmitSnapshot());
        courseSubscriptions.add(assignmentSub);

        final quizSub = _db
            .collection('quizzes')
            .where('course_id', whereIn: batch)
            .snapshots()
            .listen((_) => scheduleEmitSnapshot());
        courseSubscriptions.add(quizSub);

        final materialSub = _db
            .collection('materials')
            .where('courseId', whereIn: batch)
            .snapshots()
            .listen((_) => scheduleEmitSnapshot());
        courseSubscriptions.add(materialSub);

        final courseSub = _db
            .collection('courses')
            .where(FieldPath.documentId, whereIn: batch)
            .snapshots()
            .listen((_) => scheduleEmitSnapshot());
        courseSubscriptions.add(courseSub);
      }
    }

    void startFixedListeners() {
      final enrollmentCandidates = _candidateIds(
        firebaseUid: firebaseUid,
        user: user,
        studentProfile: studentProfile,
      );

      if (enrollmentCandidates.isNotEmpty) {
        for (final batch in _chunk(enrollmentCandidates, 10)) {
          for (final collection in ['enrollments', 'upcomingEnrollments']) {
            final enrollmentSub = _db
                .collection(collection)
                .where('studentId', whereIn: batch)
                .snapshots()
                .listen((_) async {
                  final liveCurrent = await _fetchEnrollments(
                    collection: 'enrollments',
                    candidateIds: enrollmentCandidates,
                  );
                  final liveUpcoming = await _fetchEnrollments(
                    collection: 'upcomingEnrollments',
                    candidateIds: enrollmentCandidates,
                  );
                  final courseIds = {
                    ...liveCurrent.map((doc) => _string(doc['courseId']) ?? ''),
                    ...liveUpcoming.map((doc) => _string(doc['courseId']) ?? ''),
                  }.where((id) => id.trim().isNotEmpty);
                  await resetCourseListeners(courseIds);
                  scheduleEmitSnapshot();
                });
            fixedSubscriptions.add(enrollmentSub);
          }

          final userNoticeSub = _db
              .collection('notifications')
              .where('userId', whereIn: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(userNoticeSub);

          final sharedNoticeSub = _db
              .collection('notifications')
              .where('targetUserIds', arrayContainsAny: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(sharedNoticeSub);

          final attendanceSub = _db
              .collection('attendance')
              .where('studentId', whereIn: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(attendanceSub);

          final registrationSub = _db
              .collection('registrations')
              .where('studentId', whereIn: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(registrationSub);

          final quizSubmissionSub = _db
              .collection('quiz_submissions')
              .where('student_id', whereIn: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(quizSubmissionSub);
        }
      }

      if (currentCourseIds.isNotEmpty) {
        for (final batch in _chunk(currentCourseIds.toList(), 10)) {
          final courseNoticeSub = _db
              .collection('notifications')
              .where('courseId', whereIn: batch)
              .snapshots()
              .listen((_) => scheduleEmitSnapshot());
          fixedSubscriptions.add(courseNoticeSub);
        }
      }

      final globalNoticeSub = _db
          .collection('notifications')
          .where('audience', isEqualTo: 'all')
          .snapshots()
          .listen((_) => scheduleEmitSnapshot());
      fixedSubscriptions.add(globalNoticeSub);
    }

    controller.onListen = () {
      startFixedListeners();
      unawaited(emitSnapshot());
    };

    controller.onCancel = () {
      closed = true;
      for (final sub in fixedSubscriptions) {
        unawaited(sub.cancel());
      }
      for (final sub in courseSubscriptions) {
        unawaited(sub.cancel());
      }
      debounceTimer?.cancel();
      unawaited(controller.close());
    };

    return controller.stream;
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
}
