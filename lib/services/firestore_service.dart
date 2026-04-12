import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/enrollment.dart';
import '../models/attendance.dart';
import '../models/assignment.dart';
import '../models/notification.dart';

class FirestoreService {
  FirestoreService._privateConstructor();
  static final FirestoreService instance = FirestoreService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- User ----------
  Future<UserModel?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromMap(snap.data()!, snap.id);
  }

  // ---------- Courses for a student ----------
  Future<List<CourseModel>> getStudentCourses(String uid) async {
    // Get enrollments for the student
    final enrollSnap = await _db
        .collection('enrollments')
        .where('studentId', isEqualTo: uid)
        .get();
    final courseIds = enrollSnap.docs
        .map((doc) => doc['courseId'] as String)
        .toSet()
        .toList();
    if (courseIds.isEmpty) return [];
    // Batch get courses (max 500 per batch)
    final List<DocumentReference> refs =
        courseIds.map((id) => _db.collection('courses').doc(id)).toList();
    final courseSnaps = await Future.wait(refs.map((ref) => ref.get()));
    return courseSnaps
        .where((snap) => snap.exists)
        .map((snap) => CourseModel.fromMap(snap.data() as Map<String, dynamic>, snap.id))
        .toList();
  }

  // ---------- Attendance ----------
  Future<List<AttendanceModel>> getAttendance(
      String uid, Timestamp start, Timestamp end) async {
    final snap = await _db
        .collection('attendance')
        .where('studentId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .orderBy('date')
        .get();
    return snap.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ---------- Assignments ----------
  Future<List<AssignmentModel>> getAssignments(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    List<AssignmentModel> result = [];
    // Firestore whereIn supports max 10 values per query
    for (var batch in _chunk(courseIds, 10)) {
      final snap = await _db
          .collection('assignments')
          .where('courseId', whereIn: batch)
          .orderBy('dueDate')
          .get();
      result.addAll(snap.docs
          .map((doc) => AssignmentModel.fromMap(doc.data(), doc.id)));
    }
    return result;
  }

  // ---------- Notifications ----------
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => query.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ---------- Helper for chunking ----------
  List<List<T>> _chunk<T>(List<T> list, int size) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  // ---------- CRUD examples (optional) ----------
  Future<void> addEnrollment(EnrollmentModel enrollment) async {
    await _db.collection('enrollments').doc(enrollment.enrollmentId).set(
        enrollment.toMap());
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _db
        .collection('notifications')
        .doc(notification.notificationId)
        .set(notification.toMap());
  }
}
