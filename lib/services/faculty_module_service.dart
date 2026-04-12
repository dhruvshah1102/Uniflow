import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/assignment.dart';
import '../models/course.dart';
import '../models/academic_result.dart';
import '../models/notification.dart';

class FacultyDashboardData {
  final List<CourseModel> courses;
  final Map<String, int> studentCountByCourse;
  final List<AssignmentModel> assignments;
  final List<NotificationModel> announcements;
  final int pendingTasks;

  const FacultyDashboardData({
    required this.courses,
    required this.studentCountByCourse,
    required this.assignments,
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

class FacultyModuleService {
  FacultyModuleService._();
  static final FacultyModuleService instance = FacultyModuleService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<FacultyDashboardData> loadDashboard({
    required String firebaseUid,
    required String userDocId,
  }) async {
    final facultyIds = _uniqueIds([firebaseUid, userDocId]);
    final courses = await _fetchCoursesForFaculty(facultyIds);
    final courseIds = courses.map((course) => course.courseId).toList();
    final enrollments = await _fetchEnrollments(courseIds);
    final assignments = await _fetchAssignments(courseIds);
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
      for (final entry in studentsByCourse.entries) entry.key: entry.value.length,
    };

    assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final now = DateTime.now();
    final dueSoonCount = assignments
        .where((assignment) => assignment.dueDate.toDate().isBefore(now.add(const Duration(days: 3))))
        .length;

    return FacultyDashboardData(
      courses: courses,
      studentCountByCourse: studentCountByCourse,
      assignments: assignments,
      announcements: announcements,
      pendingTasks: dueSoonCount + courses.length,
    );
  }

  Stream<FacultyDashboardData> watchDashboard({
    required String firebaseUid,
    required String userDocId,
  }) {
    final controller = StreamController<FacultyDashboardData>.broadcast();
    final fixedSubscriptions = <StreamSubscription<dynamic>>[];
    final courseSubscriptions = <StreamSubscription<dynamic>>[];
    var closed = false;
    var currentCourseIds = <String>{};

    Future<void> emitSnapshot() async {
      if (closed || controller.isClosed) return;
      try {
        final data = await loadDashboard(
          firebaseUid: firebaseUid,
          userDocId: userDocId,
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

      if (currentCourseIds.isEmpty) return;

      final courseIdList = currentCourseIds.toList();
      for (final batch in _chunk(courseIdList, 10)) {
        courseSubscriptions.add(
          _db.collection('courses').where(FieldPath.documentId, whereIn: batch).snapshots().listen((_) => emitSnapshot()),
        );
        courseSubscriptions.add(
          _db.collection('assignments').where('courseId', whereIn: batch).snapshots().listen((_) => emitSnapshot()),
        );
        courseSubscriptions.add(
          _db.collection('enrollments').where('courseId', whereIn: batch).snapshots().listen((_) => emitSnapshot()),
        );
      }
    }

    void startFixedListeners() {
      final facultyIds = _uniqueIds([firebaseUid, userDocId]);
      if (facultyIds.isEmpty) return;

      for (final batch in _chunk(facultyIds, 10)) {
        fixedSubscriptions.add(
          _db.collection('courses').where('facultyId', whereIn: batch).snapshots().listen((snapshot) async {
            final courseIds = snapshot.docs.map((doc) => doc.id).toSet();
            await resetCourseListeners(courseIds);
            await emitSnapshot();
          }),
        );
        fixedSubscriptions.add(
          _db.collection('notifications').where('createdBy', whereIn: batch).snapshots().listen((_) => emitSnapshot()),
        );
      }
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
      unawaited(controller.close());
    };

    return controller.stream;
  }

  Future<List<CourseModel>> _fetchCoursesForFaculty(List<String> facultyIds) async {
    if (facultyIds.isEmpty) return [];
    final results = <CourseModel>[];

    for (final batch in _chunk(facultyIds, 10)) {
      final snap = await _db.collection('courses').where('facultyId', whereIn: batch).get();
      results.addAll(
        snap.docs.map((doc) => CourseModel.fromMap(doc.data(), doc.id)),
      );
    }

    results.sort((a, b) => a.code.compareTo(b.code));
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchEnrollments(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db.collection('enrollments').where('courseId', whereIn: batch).get();
      results.addAll(snap.docs.map((doc) => doc.data()));
    }
    return results;
  }

  Future<List<AssignmentModel>> _fetchAssignments(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    final results = <AssignmentModel>[];
    for (final batch in _chunk(courseIds, 10)) {
      final snap = await _db.collection('assignments').where('courseId', whereIn: batch).get();
      results.addAll(snap.docs.map((doc) => AssignmentModel.fromMap(doc.data(), doc.id)));
    }
    return results;
  }

  Future<List<NotificationModel>> _fetchAnnouncements(String firebaseUid, String userDocId) async {
    final actorIds = _uniqueIds([firebaseUid, userDocId]);
    if (actorIds.isEmpty) return [];

    final results = <NotificationModel>[];
    for (final batch in _chunk(actorIds, 10)) {
      final snap = await _db.collection('notifications').where('createdBy', whereIn: batch).get();
      results.addAll(snap.docs.map((doc) => NotificationModel.fromMap(doc.data(), doc.id)));
    }
    return results;
  }

  Future<List<CourseStudent>> fetchStudentsForCourse(String courseId) async {
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
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        students.add(
          CourseStudent(
            studentId: studentId,
            name: (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] as String : 'Student',
            email: (data['email'] as String?) ?? '',
          ),
        );
        continue;
      }

      final query = await _db.collection('users').where('uid_firebase', isEqualTo: studentId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        students.add(
          CourseStudent(
            studentId: studentId,
            name: (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] as String : 'Student',
            email: (data['email'] as String?) ?? '',
          ),
        );
      } else {
        students.add(CourseStudent(studentId: studentId, name: 'Student', email: ''));
      }
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
    final dayKey = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final batch = _db.batch();

    attendanceByStudent.forEach((studentId, present) {
      final docId = 'att_${courseId}_${studentId}_$dayKey';
      final ref = _db.collection('attendance').doc(docId);
      batch.set(
        ref,
        {
          'studentId': studentId,
          'courseId': courseId,
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'present': present,
          'status': present ? 'present' : 'absent',
          'markedBy': facultyId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    await batch.commit();
  }

  Future<void> createAssignment({
    required String facultyId,
    required String courseId,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final ref = _db.collection('assignments').doc();
    await ref.set({
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdBy': facultyId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadMaterial({
    required String facultyId,
    required String courseId,
    required String fileName,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storageRef = _storage
        .ref()
        .child('materials')
        .child(courseId)
        .child('${DateTime.now().millisecondsSinceEpoch}_$sanitized');

    UploadTask task;
    if (bytes != null) {
      task = storageRef.putData(bytes);
    } else if (filePath != null && filePath.isNotEmpty) {
      task = storageRef.putFile(File(filePath));
    } else {
      throw Exception('File data is missing for upload.');
    }

    final snapshot = await task;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await _db.collection('materials').add({
      'courseId': courseId,
      'fileUrl': downloadUrl,
      'fileName': fileName,
      'uploadedBy': facultyId,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    await _notifyCourseStudents(
      facultyId: facultyId,
      courseId: courseId,
      title: 'New Study Material Uploaded',
      body: fileName,
      type: 'material',
    );

    return downloadUrl;
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
      if (courseId != null && courseId.trim().isNotEmpty) 'courseId': courseId.trim(),
      if (userIds != null && userIds.isNotEmpty)
        'targetUserIds': userIds.where((id) => id.trim().isNotEmpty).map((id) => id.trim()).toList(),
      'createdBy': facultyId,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryCopy': false,
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
    final courseName = (courseData['courseName'] ?? courseData['course_name'] ?? courseData['title'] ?? courseId).toString();
    final courseCode = (courseData['courseCode'] ?? courseData['course_code'] ?? courseData['code'] ?? courseId).toString();
    final semester = (courseData['semester'] is num) ? (courseData['semester'] as num).toInt() : int.tryParse(courseData['semester']?.toString() ?? '') ?? 0;
    final credits = (courseData['credits'] as num?)?.toInt() ?? int.tryParse(courseData['credits']?.toString() ?? '') ?? 0;

    final batch = _db.batch();
    marksByStudent.forEach((studentId, marks) {
      final marksValue = marks.round().clamp(0, 100);
      final grade = gradeFromMarks(marksValue);
      final ref = _db.collection('results').doc('${courseId}_$studentId');
      batch.set(
        ref,
        {
          'studentId': studentId,
          'courseId': courseId,
          'courseName': courseName,
          'courseCode': courseCode,
          'semester': semester,
          'credits': credits,
          'marks': marksValue,
          'grade': grade,
          'gradePoint': gradePointForGrade(grade),
          'uploadedBy': facultyId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    await batch.commit();
  }

  Future<void> _notifyCourseStudents({
    required String facultyId,
    required String courseId,
    required String title,
    required String body,
    required String type,
  }) async {
    final students = await fetchStudentsForCourse(courseId);
    if (students.isEmpty) return;

    final batch = _db.batch();
    for (final student in students) {
      final doc = _db.collection('notifications').doc();
      batch.set(doc, {
        'userId': student.studentId,
        'courseId': courseId,
        'title': title,
        'body': body,
        'message': body,
        'type': type,
        'read': false,
        'createdBy': facultyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  List<String> _uniqueIds(List<String?> values) {
    return values
        .where((value) => value != null && value!.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toSet()
        .toList();
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    final output = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      output.add(values.sublist(i, i + size > values.length ? values.length : i + size));
    }
    return output;
  }
}
