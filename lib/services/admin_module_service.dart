import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

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

  Stream<AdminOverview> watchOverview() {
    final controller = StreamController<AdminOverview>.broadcast();
    final subscriptions = <StreamSubscription<dynamic>>[];
    var closed = false;

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

    void startListeners() {
      subscriptions.add(_db.collection('users').snapshots().listen((_) => emitSnapshot()));
      subscriptions.add(_db.collection('courses').snapshots().listen((_) => emitSnapshot()));
      subscriptions.add(_db.collection('registrations').snapshots().listen((_) => emitSnapshot()));
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

    return query.snapshots().map((snap) {
      final list = snap.docs.map(AdminUserItem.fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<AdminUserItem>> fetchFacultyUsers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'faculty').get();
    final users = snap.docs.map(AdminUserItem.fromDoc).toList();
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Stream<List<AdminUserItem>> streamAllUsers() {
    return _db.collection('users').snapshots().map((snap) {
      final users = snap.docs.map(AdminUserItem.fromDoc).toList();
      users.sort((a, b) {
        final roleOrder = _roleRank(a.role).compareTo(_roleRank(b.role));
        if (roleOrder != 0) return roleOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return users;
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

  Stream<List<AdminCourseItem>> streamCourses() {
    return _db.collection('courses').snapshots().map((snap) {
      final list = snap.docs.map(AdminCourseItem.fromDoc).toList();
      list.sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      return list;
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
      return SemesterRegistrationService.instance.reviewRegistration(
        registrationId: registrationId,
        adminId: adminId,
        approve: true,
      );
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
      return SemesterRegistrationService.instance.reviewRegistration(
        registrationId: registrationId,
        adminId: adminId,
        approve: false,
        rejectionReason: 'Rejected by admin.',
      );
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

    void startListeners() {
      subscriptions.add(_db.collection('courses').snapshots().listen((_) => emitSnapshot()));
      subscriptions.add(_db.collection('enrollments').snapshots().listen((_) => emitSnapshot()));
      subscriptions.add(_db.collection('attendance').snapshots().listen((_) => emitSnapshot()));
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

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      chunks.add(values.sublist(i, i + size > values.length ? values.length : i + size));
    }
    return chunks;
  }
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
