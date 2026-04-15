import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'canonical_firestore_reset_service.dart';
import 'semester_registration_service.dart';

String? _string(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  return value.toString().trim();
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class AdminOverview {
  final int totalStudents;
  final int totalFaculty;
  final int totalCourses;
  final int pendingRegistrations;

  const AdminOverview({
    required this.totalStudents,
    required this.totalFaculty,
    required this.totalCourses,
    required this.pendingRegistrations,
  });
}

class AdminUserItem {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final int? semester;
  final String division;
  final String uidFirebase;

  const AdminUserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.semester,
    required this.division,
    required this.uidFirebase,
  });

  factory AdminUserItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final role = (_string(data['role']) ?? 'student').toLowerCase();
    return AdminUserItem(
      id: doc.id,
      name: _string(data['name']) ?? 'Unnamed User',
      email: _string(data['email']) ?? '',
      role: AdminModuleService._normalizeRole(role),
      department: _string(data['department']) ?? '-',
      semester: _int(data['semester']),
      division: _string(data['division']) ?? _string(data['section']) ?? 'A',
      uidFirebase: _string(data['uid_firebase']) ?? _string(data['uid']) ?? doc.id,
    );
  }
}

class AdminCourseItem {
  final String id;
  final String courseId;
  final String courseName;
  final String code;
  final int credits;
  final String semester;
  final int semesterNumber;
  final String facultyId;
  final String facultyName;
  final String department;

  const AdminCourseItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.code,
    required this.credits,
    required this.semester,
    required this.semesterNumber,
    required this.facultyId,
    required this.facultyName,
    required this.department,
  });

  factory AdminCourseItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final semesterNumberRaw = _int(data['semester']) ?? _int(data['semesterNumber']) ?? 0;
    final semesterNumber = semesterNumberRaw >= 1 && semesterNumberRaw <= 12 ? semesterNumberRaw : 0;
    return AdminCourseItem(
      id: doc.id,
      courseId: _string(data['courseId']) ?? doc.id,
      courseName: _string(data['courseName']) ?? _string(data['title']) ?? _string(data['course_name']) ?? 'Untitled Course',
      code: _string(data['courseCode']) ?? _string(data['code']) ?? _string(data['course_code']) ?? doc.id.toUpperCase(),
      credits: _int(data['credits']) ?? 0,
      semester: semesterNumber > 0 ? 'Semester $semesterNumber' : 'Semester -',
      semesterNumber: semesterNumber,
      facultyId: _string(data['facultyId']) ?? _string(data['faculty_id']) ?? '',
      facultyName: _string(data['facultyName']) ?? _string(data['faculty_name']) ?? '',
      department: _string(data['department']) ?? 'CSE',
    );
  }
}

class AdminRegistrationItem {
  final String id;
  final String studentId;
  final String courseId;
  final String status;
  final DateTime createdAt;

  const AdminRegistrationItem({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.status,
    required this.createdAt,
  });

  factory AdminRegistrationItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final status = (_string(data['status']) ?? 'pending').toLowerCase();
    return AdminRegistrationItem(
      id: doc.id,
      studentId: _string(data['studentId']) ?? '',
      courseId: _string(data['courseId']) ?? '',
      status: status,
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
    );
  }
}

class CourseReportItem {
  final AdminCourseItem course;
  final int totalStudents;
  final double attendancePercent;

  const CourseReportItem({
    required this.course,
    required this.totalStudents,
    required this.attendancePercent,
  });
}

class AdminModuleService {
  AdminModuleService._();
  static final AdminModuleService instance = AdminModuleService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<AdminOverview> fetchOverview() async {
    await _ensureSemesterOneCatalog();
    await ensureFacultyRoster();
    final usersSnap = await _db.collection('users').get();
    final coursesSnap = await _db.collection('courses').get();
    final registrationsSnap = await _db.collection('registrations').get();

    var totalStudents = 0;
    var totalFaculty = 0;
    for (final doc in usersSnap.docs) {
      final role = (doc.data()['role'] as String? ?? '').toLowerCase();
      if (role == 'student') totalStudents += 1;
      if (role == 'faculty') totalFaculty += 1;
    }

    final pendingRegistrations = registrationsSnap.docs
        .where((doc) => (doc.data()['status'] as String? ?? '').toLowerCase() == 'pending')
        .length;

    return AdminOverview(
      totalStudents: totalStudents,
      totalFaculty: totalFaculty,
      totalCourses: coursesSnap.docs.length,
      pendingRegistrations: pendingRegistrations,
    );
  }

  Future<void> ensureCourseCatalog() async {
    await ensureFacultyRoster();
    await _removeGeneratedSemesterFiveCatalog();
    await _ensureSemesterOneCatalog();
    await syncMissingCourseFacultyAssignments();
  }

  Future<List<String>> cleanupEmptySemesterFiveCourses() {
    return _removeEmptySemesterCourses(semester: 5);
  }

  Stream<AdminOverview> watchOverview() {
    final controller = StreamController<AdminOverview>.broadcast();
    final subscriptions = <StreamSubscription<dynamic>>[];
    var closed = false;
    var refreshInFlight = false;
    var refreshQueued = false;
    Timer? debounceTimer;

    Future<void> emitSnapshot() async {
      if (closed || controller.isClosed) return;
      try {
        final data = await fetchOverview();
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

    void startListeners() {
      subscriptions.add(_db.collection('users').snapshots().listen((_) => scheduleEmitSnapshot()));
      subscriptions.add(_db.collection('courses').snapshots().listen((_) => scheduleEmitSnapshot()));
      subscriptions.add(_db.collection('registrations').snapshots().listen((_) => scheduleEmitSnapshot()));
    }

    controller.onListen = () {
      startListeners();
      unawaited(emitSnapshot());
    };

    controller.onCancel = () {
      closed = true;
      for (final sub in subscriptions) {
        unawaited(sub.cancel());
      }
      debounceTimer?.cancel();
      unawaited(controller.close());
    };

    return controller.stream;
  }

  Stream<List<AdminUserItem>> streamUsers({String roleFilter = 'all'}) {
    final role = roleFilter.toLowerCase().trim();
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (role != 'all') {
      query = query.where('role', isEqualTo: role);
    }

    return Stream.fromFuture(ensureFacultyRoster()).asyncExpand((_) {
      return query.snapshots().map((snap) {
        final list = snap.docs.map(AdminUserItem.fromDoc).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });
    });
  }

  Future<List<AdminUserItem>> fetchFacultyUsers() async {
    await ensureFacultyRoster();
    final snap = await _db.collection('users').where('role', isEqualTo: 'faculty').get();
    final users = snap.docs.map(AdminUserItem.fromDoc).toList();
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Stream<List<AdminUserItem>> streamAllUsers() {
    return Stream.fromFuture(ensureFacultyRoster()).asyncExpand((_) {
      return _db.collection('users').snapshots().map((snap) {
        final users = snap.docs.map(AdminUserItem.fromDoc).toList();
        users.sort((a, b) {
          final roleOrder = _roleRank(a.role).compareTo(_roleRank(b.role));
          if (roleOrder != 0) return roleOrder;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return users;
      });
    });
  }

  Future<void> addOrUpdateUser({
    required String name,
    required String email,
    required String role,
    required String department,
    int? semester,
    String? division,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final normalizedEmail = email.toLowerCase().trim();
    final existing = await _db.collection('users').where('email', isEqualTo: normalizedEmail).limit(1).get();

    final docRef = existing.docs.isNotEmpty
        ? _db.collection('users').doc(existing.docs.first.id)
        : _db.collection('users').doc();

    final userId = docRef.id;
    final data = <String, dynamic>{
      'uid': userId,
      'uid_firebase': userId,
      'name': name.trim(),
      'email': normalizedEmail,
      'role': normalizedRole,
      'department': department.trim(),
      if (normalizedRole == 'student') ...{
        'semester': semester ?? 1,
        'division': _normalizeDivision(division),
        'section': _normalizeDivision(division),
      } else if (semester != null) ...{
        'semester': semester,
      },
      'fcm_token': '',
      'created_at': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(docRef, data, SetOptions(merge: true));

    if (normalizedRole == 'student') {
      batch.set(
        _db.collection('students').doc(userId),
        {
          'user_id': userId,
          'enrollment_no': _enrollmentFromEmail(normalizedEmail),
          'department': department.trim(),
          'semester': semester ?? 1,
          'division': _normalizeDivision(division),
          'section': _normalizeDivision(division),
          'classroom_student_id': null,
        },
        SetOptions(merge: true),
      );
    } else if (normalizedRole == 'faculty') {
      batch.set(
        _db.collection('faculty').doc(userId),
        {
          'user_id': userId,
          'employee_id': 'FAC-${userId.substring(0, 6).toUpperCase()}',
          'designation': 'Assistant Professor',
          'department': department.trim(),
          'classroom_teacher_id': null,
        },
        SetOptions(merge: true),
      );
    } else if (normalizedRole == 'admin') {
      batch.set(
        _db.collection('admins').doc(userId),
        {
          'user_id': userId,
          'admin_level': '1',
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> deleteUserData({
    required String userId,
    required String role,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }

    final userDoc = await _db.collection('users').doc(normalizedUserId).get();
    final userData = userDoc.data();
    final email = _string(userData?['email']) ?? '';

    final docsToDelete = <DocumentReference<Map<String, dynamic>>>{};

    Future<void> addDocs(QuerySnapshot<Map<String, dynamic>> snap) async {
      for (final doc in snap.docs) {
        docsToDelete.add(doc.reference);
      }
    }

    // Always remove the direct profile documents first.
    for (final collection in ['users', 'students', 'faculty', 'admins']) {
      final doc = await _db.collection(collection).doc(normalizedUserId).get();
      if (doc.exists) {
        docsToDelete.add(doc.reference);
      }
    }

    // Student-linked academic history.
    for (final collection in [
      'enrollments',
      'upcomingEnrollments',
      'attendance',
      'results',
      'registrations',
      'quiz_submissions',
      'submissions',
    ]) {
      final studentIdFieldQueries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _db.collection(collection).where('studentId', isEqualTo: normalizedUserId).get(),
        _db.collection(collection).where('userId', isEqualTo: normalizedUserId).get(),
        _db.collection(collection).where('user_id', isEqualTo: normalizedUserId).get(),
        _db.collection(collection).where('student_id', isEqualTo: normalizedUserId).get(),
      ];

      for (final snap in await Future.wait(studentIdFieldQueries)) {
        await addDocs(snap);
      }
    }

    final notificationsQueries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _db.collection('notifications').where('userId', isEqualTo: normalizedUserId).get(),
      _db.collection('notifications').where('createdBy', isEqualTo: normalizedUserId).get(),
      _db.collection('notifications').where('targetUserIds', arrayContains: normalizedUserId).get(),
    ];
    for (final snap in await Future.wait(notificationsQueries)) {
      await addDocs(snap);
    }

    // If this is a faculty account, remove every course taught by them and all dependent records.
    if (normalizedRole == 'faculty') {
      final courseSnap = await _db.collection('courses').where('facultyId', isEqualTo: normalizedUserId).get();
      final fallbackCourseSnap = await _db.collection('courses').where('faculty_id', isEqualTo: normalizedUserId).get();
      final courseIds = <String>{
        ...courseSnap.docs.map((doc) => _string(doc.data()['courseId']) ?? doc.id).where((id) => id.isNotEmpty),
        ...fallbackCourseSnap.docs.map((doc) => _string(doc.data()['courseId']) ?? doc.id).where((id) => id.isNotEmpty),
      };
      for (final courseId in courseIds) {
        await deleteCourse(courseId);
      }
      final facultyNotices = await _db.collection('notifications').where('createdBy', isEqualTo: normalizedUserId).get();
      await addDocs(facultyNotices);
    }

    if (docsToDelete.isNotEmpty) {
      await this._deleteRefs(docsToDelete.toList());
    }

    // Keep registration forms clean if they were tied to a deleted faculty-created course.
    if (normalizedRole == 'faculty' && email.isNotEmpty) {
      final formsSnap = await _db.collection('registrationForms').get();
      for (final doc in formsSnap.docs) {
        final data = doc.data();
        final createdBy = _string(data['createdBy']) ?? '';
        if (createdBy == normalizedUserId) {
          await doc.reference.delete();
        }
      }
    }
  }

  Future<String> createFirebaseAuthUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String department,
    int? semester,
    String? division,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final normalizedEmail = email.toLowerCase().trim();
    final normalizedPassword = password.trim();
    final normalizedDepartment = department.trim().isEmpty ? 'CSE' : department.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email is required.');
    }
    if (normalizedPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final existing = await _db.collection('users').where('email', isEqualTo: normalizedEmail).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('A user with this email already exists.');
    }

    final appName = 'admin_create_${DateTime.now().microsecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    UserCredential? credential;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      credential = await auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      final uid = credential.user!.uid;
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), {
        'uid': uid,
        'uid_firebase': uid,
        'name': name.trim(),
        'email': normalizedEmail,
        'role': normalizedRole,
        'department': normalizedDepartment,
        if (normalizedRole == 'student') ...{
          'semester': 1,
          'division': _normalizeDivision(division),
          'section': _normalizeDivision(division),
        } else if (semester != null) ...{
          'semester': semester,
        },
        'fcm_token': '',
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (normalizedRole == 'student') {
        batch.set(_db.collection('students').doc(uid), {
          'user_id': uid,
          'enrollment_no': _enrollmentFromEmail(normalizedEmail),
          'department': normalizedDepartment,
          'semester': 1,
          'division': _normalizeDivision(division),
          'section': _normalizeDivision(division),
          'classroom_student_id': null,
        }, SetOptions(merge: true));
      } else if (normalizedRole == 'faculty') {
        batch.set(_db.collection('faculty').doc(uid), {
          'user_id': uid,
          'employee_id': 'FAC-${uid.substring(0, uid.length > 6 ? 6 : uid.length).toUpperCase()}',
          'designation': 'Assistant Professor',
          'department': department.trim(),
          'classroom_teacher_id': null,
        }, SetOptions(merge: true));
      } else if (normalizedRole == 'admin') {
        batch.set(_db.collection('admins').doc(uid), {
          'user_id': uid,
          'admin_level': '1',
        }, SetOptions(merge: true));
      }

      try {
        await batch.commit();
      } catch (_) {
        await credential.user?.delete();
        rethrow;
      }

      if (normalizedRole == 'student') {
        await seedInitialSemesterEnrollments(
          studentId: uid,
          department: normalizedDepartment,
        );
      }

      return uid;
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'A user with this email already exists in Firebase Auth.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Password is too weak.',
        _ => e.message ?? 'Unable to create Firebase Auth user.',
      };
      throw Exception(message);
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      if (credential?.user != null) {
        // Secondary app handles the sign-in only for creation, so no extra cleanup needed.
      }
    }
  }

  Future<void> seedSemesterEnrollments({
    required String studentId,
    required String department,
    required int semester,
  }) async {
    await _ensureSemesterOneCatalog();
    final snap = await _db
        .collection('courses')
        .where('semester', isEqualTo: semester)
        .get();
    final filtered = snap.docs.where((doc) {
      final data = doc.data();
      final courseDepartment = _string(data['department']) ?? '';
      if (department.trim().isEmpty || courseDepartment.trim().isEmpty) return true;
      return courseDepartment.trim().toLowerCase() == department.trim().toLowerCase();
    }).toList();
    final docs = filtered.isNotEmpty ? filtered : snap.docs;
    if (docs.isEmpty) return;

    final existingSnap = await _db
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .where('semester', isEqualTo: semester)
        .get();
    final existingCourseIds = existingSnap.docs
        .map((doc) => _string(doc.data()['courseId'])?.toLowerCase() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    final batch = _db.batch();
    for (final doc in docs) {
      final courseId = _string(doc.data()['courseId']) ?? doc.id;
      if (courseId.isEmpty) continue;
      if (existingCourseIds.contains(courseId.toLowerCase())) continue;
      batch.set(
        _db.collection('enrollments').doc('enr_${studentId}_$courseId'),
        {
          'studentId': studentId,
          'courseId': courseId,
          'semester': semester,
          'status': 'active',
          'enrolledAt': FieldValue.serverTimestamp(),
          'source': semester == 1 ? 'auto_initial_semester' : 'auto_current_semester',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> seedInitialSemesterEnrollments({
    required String studentId,
    required String department,
  }) async {
    await seedSemesterEnrollments(
      studentId: studentId,
      department: department,
      semester: 1,
    );
  }

  Future<void> _ensureSemesterOneCatalog() async {
    final existingSnap = await _db.collection('courses').get();
    final existingKeys = <String>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      existingKeys.addAll({
        doc.id.trim().toLowerCase(),
        _string(data['courseId'])?.toLowerCase() ?? '',
        _string(data['courseCode'])?.toLowerCase() ?? '',
        _string(data['code'])?.toLowerCase() ?? '',
        _string(data['course_code'])?.toLowerCase() ?? '',
      }.where((value) => value.isNotEmpty));
    }

    Future<void> seedCourses(List<Map<String, dynamic>> courses) async {
      final batch = _db.batch();
      var ops = 0;
      for (final course in courses) {
        final courseId = (course['courseId'] as String).trim().toLowerCase();
        final courseCode = (course['courseCode'] as String).trim().toLowerCase();
        final legacyCode = (course['code'] as String).trim().toLowerCase();
        if (existingKeys.contains(courseId) || existingKeys.contains(courseCode) || existingKeys.contains(legacyCode)) {
          continue;
        }

        batch.set(
          _db.collection('courses').doc(course['courseId'] as String),
          {
            ...course,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        existingKeys.add(courseId);
        existingKeys.add(courseCode);
        existingKeys.add(legacyCode);
        ops += 1;
      }

      if (ops > 0) {
        await batch.commit();
      }
    }

    await seedCourses([
      _catalogCourse('cse101', 'CS101', 'Programming Fundamentals', 4, 'CSE'),
      _catalogCourse('cse102', 'CS102', 'Computer Systems Basics', 4, 'CSE'),
      _catalogCourse('mat101', 'MA101', 'Engineering Mathematics I', 4, 'CSE'),
      _catalogCourse('eng101', 'EN101', 'Technical English', 2, 'CSE'),
      _catalogCourse('phy101', 'PH101', 'Applied Physics', 3, 'CSE'),
      _catalogCourse('cse103', 'CS103', 'Programming Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse201', 'CS201', 'Discrete Mathematics', 4, 'CSE'),
      _catalogCourse('cse202', 'CS202', 'Programming in C', 4, 'CSE'),
      _catalogCourse('mat201', 'MA201', 'Engineering Mathematics II', 4, 'CSE'),
      _catalogCourse('phy201', 'PH201', 'Engineering Physics', 3, 'CSE'),
      _catalogCourse('eng201', 'EN201', 'Communication Skills', 2, 'CSE'),
      _catalogCourse('cse204', 'CS204', 'C Programming Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse301', 'CS301', 'Data Structures & Algorithms', 4, 'CSE'),
      _catalogCourse('cse302', 'CS302', 'Operating Systems', 4, 'CSE'),
      _catalogCourse('cse303', 'CS303', 'Database Management Systems', 4, 'CSE'),
      _catalogCourse('mat301', 'MA301', 'Probability and Statistics', 4, 'CSE'),
      _catalogCourse('eng301', 'EN301', 'Technical Writing', 2, 'CSE'),
      _catalogCourse('cse304', 'CS304', 'Algorithms Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse401', 'CS401', 'Computer Networks', 4, 'CSE'),
      _catalogCourse('cse402', 'CS402', 'Compiler Design', 4, 'CSE'),
      _catalogCourse('cse403', 'CS403', 'Software Engineering', 3, 'CSE'),
      _catalogCourse('cse404', 'CS404', 'Information Security', 4, 'CSE'),
      _catalogCourse('cse405', 'CS405', 'Data Warehousing and Mining', 3, 'CSE'),
      _catalogCourse('cse406', 'CS406', 'Systems Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse501', 'CS501', 'Computer Architecture', 4, 'CSE'),
      _catalogCourse('cse502', 'CS502', 'Design and Analysis of Algorithms', 4, 'CSE'),
      _catalogCourse('cse503', 'CS503', 'Database Systems II', 4, 'CSE'),
      _catalogCourse('cse504', 'CS504', 'Theory of Computation', 3, 'CSE'),
      _catalogCourse('cse505', 'CS505', 'Software Engineering', 3, 'CSE'),
      _catalogCourse('cse506', 'CS506', 'Systems Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse601', 'CS601', 'Computer Networks', 4, 'CSE'),
      _catalogCourse('cse602', 'CS602', 'Compiler Design', 4, 'CSE'),
      _catalogCourse('cse603', 'CS603', 'Software Engineering', 3, 'CSE'),
      _catalogCourse('cse604', 'CS604', 'Information Security', 4, 'CSE'),
      _catalogCourse('cse605', 'CS605', 'Data Warehousing and Mining', 3, 'CSE'),
      _catalogCourse('cse606', 'CS606', 'Cloud Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse701', 'CS701', 'Artificial Intelligence Systems', 4, 'CSE'),
      _catalogCourse('cse702', 'CS702', 'Advanced Cloud Platforms', 4, 'CSE'),
      _catalogCourse('cse703', 'CS703', 'Distributed Systems', 4, 'CSE'),
      _catalogCourse('cse704', 'CS704', 'Cyber Security Operations', 4, 'CSE'),
      _catalogCourse('cse705', 'CS705', 'Project Management', 3, 'CSE'),
      _catalogCourse('cse706', 'CS706', 'Research Lab', 2, 'CSE'),
    ]);

    await seedCourses([
      _catalogCourse('cse801', 'CS801', 'Capstone Project', 6, 'CSE'),
      _catalogCourse('cse802', 'CS802', 'Enterprise Architecture', 4, 'CSE'),
      _catalogCourse('cse803', 'CS803', 'DevOps and Automation', 4, 'CSE'),
      _catalogCourse('cse804', 'CS804', 'Seminar and Research', 2, 'CSE'),
      _catalogCourse('cse805', 'CS805', 'Industry Internship', 4, 'CSE'),
      _catalogCourse('cse806', 'CS806', 'Project Lab', 2, 'CSE'),
    ]);
  }

  Map<String, dynamic> _catalogCourse(String courseId, String courseCode, String courseName, int credits, String department) {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseName': courseName,
      'title': courseName,
      'code': courseCode,
      'course_code': courseCode,
      'course_name': courseName,
      'description': '$courseName course.',
      'credits': credits,
      'facultyId': '',
      'facultyName': '',
      'department': department,
      'semester': _semesterFromCourseId(courseId),
      'semesterLabel': 'Semester ${_semesterFromCourseId(courseId)}',
    };
  }

  int _semesterFromCourseId(String courseId) {
    final match = RegExp(r'(\d{3})').firstMatch(courseId);
    if (match == null) return 1;
    final digits = match.group(1)!;
    final semester = int.tryParse(digits[0]) ?? 1;
    return semester >= 1 && semester <= 8 ? semester : 1;
  }

  Future<void> _removeGeneratedSemesterFiveCatalog() async {
    await _removeEmptySemesterCourses(
      semester: 5,
      keepCourseIds: {
        'cse301',
        'cse302',
        'cse303',
        'ece305',
        'aiml306',
        'aiml307',
      },
    );
  }

  Future<List<String>> _removeEmptySemesterCourses({
    required int semester,
    Set<String> keepCourseIds = const <String>{},
  }) async {
    final coursesSnap = await _db.collection('courses').get();
    final semesterCourses = coursesSnap.docs
        .map(AdminCourseItem.fromDoc)
        .where((course) => course.semesterNumber == semester)
        .where((course) => !keepCourseIds.contains(course.id))
        .toList();

    if (semesterCourses.isEmpty) {
      return const [];
    }

    final courseIds = semesterCourses.map((course) => course.id).toSet().toList();
    final linkedCourseIds = <String>{};

    Future<void> markLinkedCourseIds(String collection, {String field = 'courseId'}) async {
      for (final chunk in _chunk(courseIds, 10)) {
        final snap = await _db.collection(collection).where(field, whereIn: chunk).get();
        if (snap.docs.isEmpty) continue;
        for (final doc in snap.docs) {
          final id = _string(doc.data()[field]) ?? '';
          if (id.isNotEmpty) {
            linkedCourseIds.add(id);
          }
        }
      }
    }

    Future<void> markLinkedCourseIdsFromForms() async {
      final formsSnap = await _db.collection('registrationForms').get();
      for (final doc in formsSnap.docs) {
        final data = doc.data();
        final formCourseIds = <String>[
          ...AdminModuleService._stringList(data['availableCourses']),
          ...AdminModuleService._stringList(data['availableCourseIds']),
          ...AdminModuleService._stringList(data['backlogCourses']),
          ...AdminModuleService._stringList(data['backlogCourseIds']),
        ];
        for (final rawId in formCourseIds) {
          if (courseIds.contains(rawId)) {
            linkedCourseIds.add(rawId);
          }
        }
      }
    }

    await markLinkedCourseIds('enrollments');
    await markLinkedCourseIds('attendance');
    await markLinkedCourseIds('assignments');
    await markLinkedCourseIds('materials');
    await markLinkedCourseIds('results');
    await markLinkedCourseIds('notifications');
    await markLinkedCourseIds('upcomingEnrollments');
    await markLinkedCourseIds('quizzes', field: 'course_id');
    await markLinkedCourseIdsFromForms();

    final removableCourses = semesterCourses
        .where((course) => !linkedCourseIds.contains(course.id))
        .toList();
    if (removableCourses.isEmpty) {
      return const [];
    }

    for (final chunk in _chunk(removableCourses.map((course) => course.id).toList(), 400)) {
      final batch = _db.batch();
      for (final courseId in chunk) {
        batch.delete(_db.collection('courses').doc(courseId));
      }
      await batch.commit();
    }

    return removableCourses.map((course) => course.id).toList();
  }

  Future<void> deleteCourse(String courseId) async {
    final normalizedCourseId = courseId.trim();
    if (normalizedCourseId.isEmpty) {
      throw Exception('Course id is required.');
    }

    final courseDoc = await _db.collection('courses').doc(normalizedCourseId).get();
    if (!courseDoc.exists) {
      throw Exception('Course not found.');
    }

    final relatedCourseIds = {normalizedCourseId};

    Future<void> deleteByCourseField(String collection, {String field = 'courseId'}) async {
      for (final chunk in _chunk(relatedCourseIds.toList(), 10)) {
        final snap = await _db.collection(collection).where(field, whereIn: chunk).get();
        if (snap.docs.isEmpty) continue;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    Future<void> deleteAssignmentSubmissions(List<String> assignmentIds) async {
      for (final chunk in _chunk(assignmentIds, 10)) {
        final snap = await _db.collection('submissions').where('assignment_id', whereIn: chunk).get();
        if (snap.docs.isEmpty) continue;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    Future<void> deleteQuizChildren(List<String> quizIds) async {
      for (final chunk in _chunk(quizIds, 10)) {
        final questionsSnap = await _db.collection('quiz_questions').where('quiz_id', whereIn: chunk).get();
        if (questionsSnap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in questionsSnap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }

        final submissionsSnap = await _db.collection('quiz_submissions').where('quiz_id', whereIn: chunk).get();
        if (submissionsSnap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in submissionsSnap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
    }

    final assignmentsSnap = await _db.collection('assignments').where('courseId', isEqualTo: normalizedCourseId).get();
    final assignmentIds = assignmentsSnap.docs.map((doc) => doc.id).toList();
    if (assignmentIds.isNotEmpty) {
      await deleteAssignmentSubmissions(assignmentIds);
      await this._deleteRefs(assignmentsSnap.docs.map((doc) => doc.reference).toList());
    }

    final quizzesSnap = await _db.collection('quizzes').where('course_id', isEqualTo: normalizedCourseId).get();
    final quizIds = quizzesSnap.docs.map((doc) => doc.id).toList();
    if (quizIds.isNotEmpty) {
      await deleteQuizChildren(quizIds);
      await this._deleteRefs(quizzesSnap.docs.map((doc) => doc.reference).toList());
    }

    await deleteByCourseField('enrollments');
    await deleteByCourseField('attendance');
    await deleteByCourseField('materials');
    await deleteByCourseField('notifications');
    await deleteByCourseField('results');
    await deleteByCourseField('upcomingEnrollments');

    final registrationsToDelete = <DocumentReference<Map<String, dynamic>>>{};
    for (final chunk in _chunk([normalizedCourseId], 10)) {
      final selectedSnap = await _db.collection('registrations').where('selectedCourses', arrayContainsAny: chunk).get();
      final backlogSnap = await _db.collection('registrations').where('backlogCourses', arrayContainsAny: chunk).get();
      for (final doc in [...selectedSnap.docs, ...backlogSnap.docs]) {
        registrationsToDelete.add(doc.reference);
      }
    }
    if (registrationsToDelete.isNotEmpty) {
      await this._deleteRefs(registrationsToDelete.toList());
    }

    final formsSnap = await _db.collection('registrationForms').get();
    for (final doc in formsSnap.docs) {
      final data = doc.data();
      final availableCourses = AdminModuleService._stringList(data['availableCourses']);
      final availableCourseIds = AdminModuleService._stringList(data['availableCourseIds']);
      final backlogCourses = AdminModuleService._stringList(data['backlogCourses']);
      final backlogCourseIds = AdminModuleService._stringList(data['backlogCourseIds']);

      final updatedAvailableCourses = availableCourses.where((id) => id != normalizedCourseId).toList();
      final updatedAvailableCourseIds = availableCourseIds.where((id) => id != normalizedCourseId).toList();
      final updatedBacklogCourses = backlogCourses.where((id) => id != normalizedCourseId).toList();
      final updatedBacklogCourseIds = backlogCourseIds.where((id) => id != normalizedCourseId).toList();

      if (updatedAvailableCourses.length == availableCourses.length &&
          updatedAvailableCourseIds.length == availableCourseIds.length &&
          updatedBacklogCourses.length == backlogCourses.length &&
          updatedBacklogCourseIds.length == backlogCourseIds.length) {
        continue;
      }

      await doc.reference.set(
        {
          'availableCourses': updatedAvailableCourses,
          'availableCourseIds': updatedAvailableCourseIds,
          'backlogCourses': updatedBacklogCourses,
          'backlogCourseIds': updatedBacklogCourseIds,
        },
        SetOptions(merge: true),
      );
    }

    await _db.collection('courses').doc(normalizedCourseId).delete();
  }

  Stream<List<AdminCourseItem>> streamCourses() {
    return Stream.fromFuture(ensureCourseCatalog()).asyncExpand((_) {
      return _db.collection('courses').snapshots().map((snap) {
        final list = snap.docs.map(AdminCourseItem.fromDoc).toList();
        list.sort((a, b) {
          final semesterCompare = a.semesterNumber.compareTo(b.semesterNumber);
          if (semesterCompare != 0) return semesterCompare;
          return a.code.toLowerCase().compareTo(b.code.toLowerCase());
        });
        return list;
      });
    });
  }

  Future<String> createCourse({
    required String courseName,
    required String courseCode,
    required int credits,
    required int semester,
    required String department,
    required String facultyId,
    required String facultyName,
    String description = '',
  }) async {
    final normalizedCourseCode = courseCode.trim().toUpperCase();
    if (normalizedCourseCode.isEmpty) {
      throw Exception('Course code is required.');
    }

    final existingById = await _db.collection('courses').doc(normalizedCourseCode).get();
    final existingByCode = await _db
        .collection('courses')
        .where('courseCode', isEqualTo: normalizedCourseCode)
        .limit(1)
        .get();
    final existingByLegacyCode = await _db
        .collection('courses')
        .where('code', isEqualTo: normalizedCourseCode)
        .limit(1)
        .get();

    if (existingById.exists || existingByCode.docs.isNotEmpty || existingByLegacyCode.docs.isNotEmpty) {
      throw Exception('A course with this code already exists.');
    }

    await _db.collection('courses').doc(normalizedCourseCode).set(
      {
        'courseId': normalizedCourseCode,
        'courseCode': normalizedCourseCode,
        'courseName': courseName.trim(),
        'title': courseName.trim(),
        'code': normalizedCourseCode,
        'course_code': normalizedCourseCode,
        'course_name': courseName.trim(),
        'description': description.trim().isEmpty ? 'Course managed by Admin Module' : description.trim(),
        'credits': credits,
        'semester': semester,
        'semesterLabel': 'Semester $semester',
        'department': department.trim(),
        'facultyId': facultyId,
        'faculty_id': facultyId,
        'facultyName': facultyName,
        'faculty_name': facultyName,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    return normalizedCourseCode;
  }

  Future<void> createOrUpdateCourse({
    required String courseId,
    required String courseName,
    required String code,
    required int credits,
    required String semester,
    required String department,
    required String facultyId,
    required String facultyName,
  }) async {
    final semesterNumber = int.tryParse(semester.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    await createCourse(
      courseName: courseName,
      courseCode: code,
      credits: credits,
      semester: semesterNumber,
      department: department,
      facultyId: facultyId,
      facultyName: facultyName,
    );
  }

  Future<CleanupReport> normalizeUserRecords({
    String defaultDepartment = 'CSE',
    String defaultDivision = 'A',
    int defaultSemester = 1,
  }) async {
    final snap = await _db.collection('users').get();
    if (snap.docs.isEmpty) {
      return const CleanupReport(updated: 0, skipped: 0, flagged: 0);
    }

    var updated = 0;
    var skipped = 0;
    var flagged = 0;
    WriteBatch batch = _db.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final rawRole = (_string(data['role']) ?? '').toLowerCase().trim();
      final role = _isValidRole(rawRole) ? rawRole : 'student';
      final name = _string(data['name']) ?? _displayNameFromEmail(_string(data['email']) ?? doc.id);
      final email = _string(data['email']) ?? '';
      final department = _string(data['department']) ?? defaultDepartment;
      final semester = _int(data['semester']) ?? defaultSemester;
      final division = _normalizeDivision(_string(data['division']) ?? _string(data['section']) ?? defaultDivision);
      final uid = _string(data['uid']) ?? _string(data['uid_firebase']) ?? doc.id;

      final normalized = <String, dynamic>{
        'uid': uid,
        'uid_firebase': uid,
        'name': name,
        'email': email,
        'role': role,
        'department': role == 'student' ? department : (role == 'faculty' ? department : (department.isEmpty ? 'Admin' : department)),
        'fcm_token': _string(data['fcm_token']) ?? '',
        'created_at': data['created_at'] ?? FieldValue.serverTimestamp(),
      };

      if (role == 'student') {
        normalized['semester'] = semester > 0 ? semester : defaultSemester;
        normalized['division'] = division;
        normalized['section'] = division;
      } else if (role == 'faculty') {
        normalized['department'] = department.isEmpty ? defaultDepartment : department;
      }

      final needsUpdate = _needsNormalization(data, normalized);
      if (!needsUpdate) {
        skipped += 1;
        continue;
      }

      if (!_isValidRole(rawRole)) {
        flagged += 1;
      }

      batch.set(doc.reference, normalized, SetOptions(merge: true));
      if (role == 'student') {
        batch.set(
          _db.collection('students').doc(doc.id),
          {
            'user_id': doc.id,
            'enrollment_no': _enrollmentFromEmail(email.isNotEmpty ? email : doc.id),
            'department': normalized['department'],
            'semester': normalized['semester'],
            'division': normalized['division'],
            'section': normalized['section'],
            'classroom_student_id': null,
          },
          SetOptions(merge: true),
        );
      } else if (role == 'faculty') {
        batch.set(
          _db.collection('faculty').doc(doc.id),
          {
            'user_id': doc.id,
            'employee_id': 'FAC-${doc.id.substring(0, doc.id.length > 8 ? 8 : doc.id.length).toUpperCase()}',
            'designation': _string(data['designation']) ?? 'Assistant Professor',
            'department': normalized['department'],
            'classroom_teacher_id': null,
          },
          SetOptions(merge: true),
        );
      } else if (role == 'admin') {
        batch.set(
          _db.collection('admins').doc(doc.id),
          {
            'user_id': doc.id,
            'admin_level': _string(data['admin_level']) ?? '1',
          },
          SetOptions(merge: true),
        );
      }
      ops += 1;
      updated += 1;
      if (ops >= 450) {
        await flush();
      }
    }

    await flush();
    return CleanupReport(updated: updated, skipped: skipped, flagged: flagged);
  }

  Future<void> assignFacultyToCourse({
    required String courseId,
    required String facultyId,
    required String facultyName,
  }) async {
    await _db.collection('courses').doc(courseId).set(
      {
        'facultyId': facultyId,
        'faculty_id': facultyId,
        'facultyName': facultyName,
        'faculty_name': facultyName,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> syncMissingCourseFacultyAssignments() async {
    final facultyRoster = <_FacultyAssignment?>[
      await _resolveFacultyAssignment('faculty1@iiitn.ac.in', 'Dr. Priya Sharma'),
      await _resolveFacultyAssignment('ananya.sharma@iiitn.ac.in', 'Dr. Ananya Sharma'),
      await _resolveFacultyAssignment('rohan.mehta@iiitn.ac.in', 'Dr. Rohan Mehta'),
      await _resolveFacultyAssignment('meera.joshi@iiitn.ac.in', 'Dr. Meera Joshi'),
      await _resolveFacultyAssignment('kunal.verma@iiitn.ac.in', 'Dr. Kunal Verma'),
    ].whereType<_FacultyAssignment>().toList();
    final priyaCourseIds = <String>{
      'cse301',
      'cse302',
      'cse303',
      'cse201',
      'cse202',
      'cse203',
      'cse401',
      'cse402',
      'cse403',
      'cse404',
    };
    final otherFacultyRoster = facultyRoster.length > 1 ? facultyRoster.sublist(1) : facultyRoster;

    if (facultyRoster.isEmpty) return;

    final coursesSnap = await _db.collection('courses').get();
    final cseCourses = coursesSnap.docs.where((doc) {
      final data = doc.data();
      final courseId = (_string(data['courseId']) ?? doc.id).trim().toLowerCase();
      final department = (_string(data['department']) ?? '').trim().toUpperCase();
      final semester = _int(data['semester']) ??
          _int(data['semesterNumber']) ??
          _semesterFromCourseId(courseId);
      return semester >= 1 && semester <= 8 && (department == 'CSE' || courseId.startsWith('cse'));
    }).toList()
      ..sort((a, b) {
        final aSemester = _int(a.data()['semester']) ?? _semesterFromCourseId(_string(a.data()['courseId']) ?? a.id);
        final bSemester = _int(b.data()['semester']) ?? _semesterFromCourseId(_string(b.data()['courseId']) ?? b.id);
        final semesterCompare = aSemester.compareTo(bSemester);
        if (semesterCompare != 0) return semesterCompare;

        final aCode = (_string(a.data()['courseCode']) ?? _string(a.data()['code']) ?? a.id).toLowerCase();
        final bCode = (_string(b.data()['courseCode']) ?? _string(b.data()['code']) ?? b.id).toLowerCase();
        final codeCompare = aCode.compareTo(bCode);
        if (codeCompare != 0) return codeCompare;
        return a.id.compareTo(b.id);
      });

    if (cseCourses.isEmpty) return;

    WriteBatch batch = _db.batch();
    var ops = 0;
    var otherIndex = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (var index = 0; index < cseCourses.length; index++) {
      final doc = cseCourses[index];
      final courseId = (_string(doc.data()['courseId']) ?? doc.id).trim().toLowerCase();
      final assignment = priyaCourseIds.contains(courseId)
          ? facultyRoster.first
          : otherFacultyRoster[otherIndex++ % otherFacultyRoster.length];
      batch.set(
        doc.reference,
        {
          'facultyId': assignment.uid,
          'faculty_id': assignment.uid,
          'facultyName': assignment.name,
          'faculty_name': assignment.name,
        },
        SetOptions(merge: true),
      );
      ops += 1;
      if (ops >= 450) {
        await flush();
      }
    }

    await flush();
  }

  Future<void> ensureFacultyRoster() async {
    final faculty = <Map<String, dynamic>>[
      {
        'id': 'f002',
        'name': 'Dr. Amit Kulkarni',
        'email': 'amit.kulkarni@iiitn.ac.in',
        'department': 'ECE',
        'employeeId': 'FAC-1002',
      },
      {
        'id': 'f003',
        'name': 'Dr. Neha Verma',
        'email': 'neha.verma@iiitn.ac.in',
        'department': 'AI-DS',
        'employeeId': 'FAC-1003',
      },
      {
        'id': 'f004',
        'name': 'Dr. Ananya Sharma',
        'email': 'ananya.sharma@iiitn.ac.in',
        'department': 'CSE',
        'employeeId': 'FAC-1004',
      },
      {
        'id': 'f005',
        'name': 'Dr. Rohan Mehta',
        'email': 'rohan.mehta@iiitn.ac.in',
        'department': 'CSE',
        'employeeId': 'FAC-1005',
      },
      {
        'id': 'f006',
        'name': 'Dr. Meera Joshi',
        'email': 'meera.joshi@iiitn.ac.in',
        'department': 'CSE',
        'employeeId': 'FAC-1006',
      },
      {
        'id': 'f007',
        'name': 'Dr. Kunal Verma',
        'email': 'kunal.verma@iiitn.ac.in',
        'department': 'CSE',
        'employeeId': 'FAC-1007',
      },
      {
        'id': 'f008',
        'name': 'Dr. Asha Nair',
        'email': 'asha.nair@iiitn.ac.in',
        'department': 'ECE',
        'employeeId': 'FAC-1008',
      },
      {
        'id': 'f009',
        'name': 'Dr. Vikram Singh',
        'email': 'vikram.singh@iiitn.ac.in',
        'department': 'AI-DS',
        'employeeId': 'FAC-1009',
      },
    ];

    final batch = _db.batch();
    for (final item in faculty) {
      final docRef = _db.collection('users').doc(item['id'] as String);
      batch.set(
        docRef,
        {
          'uid': item['id'],
          'uid_firebase': item['id'],
          'name': item['name'],
          'email': item['email'],
          'role': 'faculty',
          'department': item['department'],
          'fcm_token': '',
          'created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        _db.collection('faculty').doc(item['id'] as String),
        {
          'user_id': item['id'],
          'employee_id': item['employeeId'],
          'designation': 'Assistant Professor',
          'department': item['department'],
          'classroom_teacher_id': null,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> resetCanonicalDataset({
    required String adminUid,
  }) async {
    final studentUid = await _resolveUidByEmail('student1@iiitn.ac.in');
    final facultyUid = await _resolveUidByEmail('faculty1@iiitn.ac.in');

    if (studentUid == null) {
      throw Exception('Could not find the Firestore record for student1@iiitn.ac.in.');
    }
    if (facultyUid == null) {
      throw Exception('Could not find the Firestore record for faculty1@iiitn.ac.in.');
    }

    await CanonicalFirestoreResetService.resetCanonicalData(
      studentUid: studentUid,
      facultyUid: facultyUid,
      adminUid: adminUid,
    );
  }

  Stream<List<AdminRegistrationItem>> streamPendingRegistrations() {
    return _db.collection('registrations').snapshots().map((snap) {
      final list = snap.docs.map(AdminRegistrationItem.fromDoc).where((item) => item.status == 'pending').toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> approveRegistration({
    required String registrationId,
    required String adminId,
  }) async {
    final regRef = _db.collection('registrations').doc(registrationId);
    final regSnap = await regRef.get();
    if (!regSnap.exists || regSnap.data() == null) {
      throw Exception('Registration request not found.');
    }

    final registrationData = regSnap.data()!;
    if (registrationData['targetSemester'] != null || registrationData['registrationType'] == 'semester_registration') {
      try {
        return await SemesterRegistrationService.instance.reviewRegistration(
          registrationId: registrationId,
          adminId: adminId,
          approve: true,
        );
      } catch (e, stack) {
        debugPrint('approveRegistration failed for $registrationId: $e');
        debugPrintStack(stackTrace: stack);
        rethrow;
      }
    }

    await _db.runTransaction((txn) async {
      final regSnap = await txn.get(regRef);
      if (!regSnap.exists || regSnap.data() == null) {
        throw Exception('Registration request not found.');
      }

      final data = regSnap.data()!;
      final studentId = _string(data['studentId']) ?? '';
      final courseId = _string(data['courseId']) ?? '';
      if (studentId.isEmpty || courseId.isEmpty) {
        throw Exception('Invalid registration request.');
      }

      txn.set(
        regRef,
        {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
        },
        SetOptions(merge: true),
      );

      txn.set(
        _db.collection('enrollments').doc('enr_${courseId}_$studentId'),
        {
          'studentId': studentId,
          'courseId': courseId,
          'status': 'active',
          'enrolledAt': FieldValue.serverTimestamp(),
          'approvedBy': adminId,
        },
        SetOptions(merge: true),
      );

      txn.set(
        _db.collection('notifications').doc(),
        {
          'userId': studentId,
          'courseId': courseId,
          'title': 'Registration Approved',
          'message': 'Your registration for $courseId has been approved.',
          'body': 'Your registration for $courseId has been approved.',
          'type': 'registration',
          'read': false,
          'createdBy': adminId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> rejectRegistration({
    required String registrationId,
    required String adminId,
  }) async {
    final regRef = _db.collection('registrations').doc(registrationId);
    final regSnap = await regRef.get();
    if (!regSnap.exists || regSnap.data() == null) {
      throw Exception('Registration request not found.');
    }

    if (regSnap.data()!['targetSemester'] != null || regSnap.data()!['registrationType'] == 'semester_registration') {
      try {
        return await SemesterRegistrationService.instance.reviewRegistration(
          registrationId: registrationId,
          adminId: adminId,
          approve: false,
          rejectionReason: 'Rejected by admin.',
        );
      } catch (e, stack) {
        debugPrint('rejectRegistration failed for $registrationId: $e');
        debugPrintStack(stackTrace: stack);
        rethrow;
      }
    }

    final studentId = _string(regSnap.data()!['studentId']) ?? '';
    final courseId = _string(regSnap.data()!['courseId']) ?? '';

    final batch = _db.batch();
    batch.set(
      regRef,
      {
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
      },
      SetOptions(merge: true),
    );
    if (studentId.isNotEmpty) {
      batch.set(
        _db.collection('notifications').doc(),
        {
          'userId': studentId,
          if (courseId.isNotEmpty) 'courseId': courseId,
          'title': 'Registration Rejected',
          'message': 'Your registration request has been rejected.',
          'body': 'Your registration request has been rejected.',
          'type': 'registration',
          'read': false,
          'createdBy': adminId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  Future<List<CourseReportItem>> fetchCourseReports() async {
    final coursesSnap = await _db.collection('courses').get();
    final courses = coursesSnap.docs.map(AdminCourseItem.fromDoc).toList();
    if (courses.isEmpty) return [];

    final courseIds = courses.map((course) => course.id).toList();
    final enrollmentCountByCourse = <String, int>{};
    final attendanceTotalByCourse = <String, int>{};
    final attendancePresentByCourse = <String, int>{};

    for (final chunk in _chunk(courseIds, 10)) {
      final enrollSnap = await _db.collection('enrollments').where('courseId', whereIn: chunk).get();
      for (final doc in enrollSnap.docs) {
        final courseId = _string(doc.data()['courseId']) ?? '';
        if (courseId.isEmpty) continue;
        enrollmentCountByCourse[courseId] = (enrollmentCountByCourse[courseId] ?? 0) + 1;
      }

      final attendanceSnap = await _db.collection('attendance').where('courseId', whereIn: chunk).get();
      for (final doc in attendanceSnap.docs) {
        final data = doc.data();
        final courseId = _string(data['courseId']) ?? '';
        if (courseId.isEmpty) continue;
        final present = data['present'] == true || (_string(data['status']) ?? '').toLowerCase() == 'present';
        attendanceTotalByCourse[courseId] = (attendanceTotalByCourse[courseId] ?? 0) + 1;
        if (present) {
          attendancePresentByCourse[courseId] = (attendancePresentByCourse[courseId] ?? 0) + 1;
        }
      }
    }

    final reports = <CourseReportItem>[];
    for (final course in courses) {
      final totalStudents = enrollmentCountByCourse[course.id] ?? 0;
      final attendanceTotal = attendanceTotalByCourse[course.id] ?? 0;
      final attendancePresent = attendancePresentByCourse[course.id] ?? 0;
      final attendancePercent = attendanceTotal == 0 ? 0.0 : (attendancePresent * 100) / attendanceTotal;

      reports.add(
        CourseReportItem(
          course: course,
          totalStudents: totalStudents,
          attendancePercent: attendancePercent,
        ),
      );
    }

    reports.sort((a, b) => b.totalStudents.compareTo(a.totalStudents));
    return reports;
  }

  Stream<List<CourseReportItem>> watchCourseReports() {
    final controller = StreamController<List<CourseReportItem>>.broadcast();
    final subscriptions = <StreamSubscription<dynamic>>[];
    var closed = false;
    var refreshInFlight = false;
    var refreshQueued = false;
    Timer? debounceTimer;

    Future<void> emitSnapshot() async {
      if (closed || controller.isClosed) return;
      try {
        final data = await fetchCourseReports();
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

    void startListeners() {
      subscriptions.add(_db.collection('courses').snapshots().listen((_) => scheduleEmitSnapshot()));
      subscriptions.add(_db.collection('enrollments').snapshots().listen((_) => scheduleEmitSnapshot()));
      subscriptions.add(_db.collection('attendance').snapshots().listen((_) => scheduleEmitSnapshot()));
    }

    controller.onListen = () {
      startListeners();
      unawaited(emitSnapshot());
    };

    controller.onCancel = () {
      closed = true;
      for (final sub in subscriptions) {
        unawaited(sub.cancel());
      }
      debounceTimer?.cancel();
      unawaited(controller.close());
    };

    return controller.stream;
  }

  Future<Map<String, String>> fetchUserNamesById(Iterable<String> userIds) async {
    final uniqueIds = userIds.where((id) => id.trim().isNotEmpty).map((id) => id.trim()).toSet().toList();
    final result = <String, String>{};
    for (final chunk in _chunk(uniqueIds, 10)) {
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        result[doc.id] = _string(doc.data()['name']) ?? doc.id;
      }
    }
    return result;
  }

  Future<String?> _resolveUidByEmail(String email) async {
    final snap = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  static String _enrollmentFromEmail(String email) {
    final local = email.split('@').first.toUpperCase().replaceAll('.', '');
    return 'BT${local.substring(0, local.length > 8 ? 8 : local.length)}';
  }

  static String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    if (_isValidRole(value)) return value;
    return 'student';
  }

  static bool _isValidRole(String role) {
    return role == 'student' || role == 'faculty' || role == 'admin';
  }

  static int _roleRank(String role) {
    switch (role) {
      case 'student':
        return 0;
      case 'faculty':
        return 1;
      case 'admin':
        return 2;
      default:
        return 3;
    }
  }

  static String _normalizeDivision(String? value) {
    final division = (value ?? '').trim().toUpperCase();
    if (division.isEmpty) return 'A';
    return division.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool _needsNormalization(Map<String, dynamic> original, Map<String, dynamic> normalized) {
    for (final entry in normalized.entries) {
      final current = original[entry.key];
      final expected = entry.value;
      if (expected is String) {
        if ((current ?? '').toString().trim() != expected.trim()) return true;
      } else if (expected is int) {
        if (_int(current) != expected) return true;
      } else {
        if (current != expected) return true;
      }
    }
    return false;
  }

  static String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    if (localPart.isEmpty) return 'User';
    return localPart
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<dynamic>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<void> _deleteRefs(List<DocumentReference<Map<String, dynamic>>> refs) async {
    if (refs.isEmpty) return;

    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      final end = i + 400 > refs.length ? refs.length : i + 400;
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      chunks.add(values.sublist(i, i + size > values.length ? values.length : i + size));
    }
    return chunks;
  }

  Future<_FacultyAssignment?> _resolveFacultyAssignment(String email, String name) async {
    final uid = await _resolveUidByEmail(email);
    if (uid == null || uid.trim().isEmpty) return null;
    return _FacultyAssignment(uid, name);
  }
}

class _FacultyAssignment {
  final String uid;
  final String name;

  const _FacultyAssignment(this.uid, this.name);
}

class CleanupReport {
  final int updated;
  final int skipped;
  final int flagged;

  const CleanupReport({
    required this.updated,
    required this.skipped,
    required this.flagged,
  });
}
