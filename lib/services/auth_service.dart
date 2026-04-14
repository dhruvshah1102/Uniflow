import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/academic_result.dart';
import '../models/user_model.dart';
import '../data/seed/seed_data.dart';
import 'admin_module_service.dart';

// ROLE TESTING — seed these 3 users manually in Firebase Console
// or use the admin panel once built.
//
// In Firebase Console → Authentication → Add user:
//   student@iiitn.ac.in  / Test@1234
//   faculty@iiitn.ac.in  / Test@1234
//   admin@iiitn.ac.in    / Test@1234
//
// In Firestore Console → users collection, add 3 docs:
//   { uid_firebase: "<uid from auth>", name: "Test Student",
//     email: "student@iiitn.ac.in", role: "student",
//     fcm_token: "", created_at: <now> }
//   { uid_firebase: "<uid from auth>", name: "Test Faculty",
//     email: "faculty@iiitn.ac.in", role: "faculty", ... }
//   { uid_firebase: "<uid from auth>", name: "Test Admin",
//     email: "admin@iiitn.ac.in", role: "admin", ... }
//
// Then add matching docs in students/, faculty/, admins/ collections
// pointing user_id to the corresponding users doc id.
//
// Logging in with each email should land on a different dashboard.

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserModel.fromMap(docSnapshot.data()!, docSnapshot.id);
      }

      final snapshot = await _firestore
          .collection('users')
          .where('uid_firebase', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }

      final fallbackSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (fallbackSnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(
          fallbackSnapshot.docs.first.data(),
          fallbackSnapshot.docs.first.id,
        );
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      rethrow;
    }
    return null;
  }

  Future<void> ensureUserRecord({
    required String uid,
    required String email,
    required String role,
  }) async {
    final displayName = _displayNameFromEmail(email);

    await _firestore.collection('users').doc(uid).set({
      'name': displayName,
      'email': email,
      'role': role,
      'uid_firebase': uid,
      'fcm_token': '',
      'created_at': FieldValue.serverTimestamp(),
      if (role == 'student') 'department': 'CSE',
      if (role == 'student') 'semester': 1,
      if (role == 'student') 'division': 'A',
      if (role == 'student') 'section': 'A',
      if (role == 'faculty') 'department': 'CSE',
    }, SetOptions(merge: true));

    if (role == 'student') {
      await _firestore.collection('students').doc(uid).set({
        'user_id': uid,
        'enrollment_no': email.split('@').first.toUpperCase(),
        'department': 'CSE',
        'semester': 1,
        'division': 'A',
        'section': 'A',
        'classroom_student_id': null,
      }, SetOptions(merge: true));
    } else if (role == 'faculty') {
      await _firestore.collection('faculty').doc(uid).set({
        'user_id': uid,
        'employee_id': uid.substring(0, uid.length > 8 ? 8 : uid.length).toUpperCase(),
        'designation': 'Faculty',
        'department': 'CSE',
        'classroom_teacher_id': null,
      }, SetOptions(merge: true));
    } else if (role == 'admin') {
      await _firestore.collection('admins').doc(uid).set({
        'user_id': uid,
        'admin_level': '1',
      }, SetOptions(merge: true));
    }
  }

  Future<void> ensureStudentDemoData({
    required String uid,
    required String email,
  }) async {
    final studentName = 'Aarav Agarwal';
    final facultyName = 'Dr. Priya Sharma';
    final enrollmentNo = 'BT21CSE001';
    final now = Timestamp.now();

    final batch = _firestore.batch();

    batch.set(_firestore.collection('users').doc(uid), {
      'name': studentName,
      'email': email,
      'role': 'student',
      'uid_firebase': uid,
      'fcm_token': '',
      'created_at': FieldValue.serverTimestamp(),
      'department': 'CSE',
      'semester': 1,
      'division': 'A',
      'section': 'A',
    }, SetOptions(merge: true));

    batch.set(_firestore.collection('students').doc(uid), {
      'user_id': uid,
      'enrollment_no': enrollmentNo,
      'department': 'CSE',
      'semester': 1,
      'division': 'A',
      'section': 'A',
      'classroom_student_id': null,
    }, SetOptions(merge: true));

    final courses = [
      {
        'courseId': 'cse101',
        'title': 'Programming Fundamentals',
        'code': 'CS101',
        'description': 'Introductory programming and problem solving.',
        'credits': 4,
        'facultyId': 'faculty1',
        'facultyName': facultyName,
        'semester': 1,
      },
      {
        'courseId': 'cse102',
        'title': 'Computer Systems Basics',
        'code': 'CS102',
        'description': 'Computer organization and system architecture basics.',
        'credits': 4,
        'facultyId': 'faculty1',
        'facultyName': facultyName,
        'semester': 1,
      },
      {
        'courseId': 'mat101',
        'title': 'Engineering Mathematics I',
        'code': 'MA101',
        'description': 'Calculus, matrices and linear algebra foundations.',
        'credits': 4,
        'facultyId': 'faculty1',
        'facultyName': facultyName,
        'semester': 1,
      },
      {
        'courseId': 'eng101',
        'title': 'Technical English',
        'code': 'EN101',
        'description': 'Communication and technical writing skills.',
        'credits': 2,
        'facultyId': 'f002',
        'facultyName': 'Dr. Amit Kulkarni',
        'semester': 1,
      },
      {
        'courseId': 'phy101',
        'title': 'Applied Physics',
        'code': 'PH101',
        'description': 'Mechanics, waves and laboratory foundations.',
        'credits': 3,
        'facultyId': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'semester': 1,
      },
      {
        'courseId': 'cse103',
        'title': 'Programming Lab',
        'code': 'CS103',
        'description': 'Hands-on programming laboratory.',
        'credits': 2,
        'facultyId': 'faculty1',
        'facultyName': facultyName,
        'semester': 1,
      },
    ];

    for (final course in courses) {
      batch.set(
        _firestore.collection('courses').doc(course['courseId'] as String),
        {
          ...course,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final enrolledCourseIds = ['cse101', 'cse102', 'mat101', 'eng101', 'phy101', 'cse103'];
    for (var i = 0; i < enrolledCourseIds.length; i++) {
      batch.set(
        _firestore.collection('enrollments').doc('demo_enr_${uid}_${i + 1}'),
        {
          'studentId': uid,
          'courseId': enrolledCourseIds[i],
          'enrolledAt': FieldValue.serverTimestamp(),
          'status': 'active',
        },
        SetOptions(merge: true),
      );
    }

    final attendanceEntries = [
      {'id': 'demo_att_${uid}_1', 'courseId': 'cse101', 'present': true, 'daysAgo': 0},
      {'id': 'demo_att_${uid}_2', 'courseId': 'cse101', 'present': true, 'daysAgo': 2},
      {'id': 'demo_att_${uid}_3', 'courseId': 'cse102', 'present': true, 'daysAgo': 1},
      {'id': 'demo_att_${uid}_4', 'courseId': 'cse102', 'present': false, 'daysAgo': 0},
      {'id': 'demo_att_${uid}_5', 'courseId': 'mat101', 'present': true, 'daysAgo': 3},
      {'id': 'demo_att_${uid}_6', 'courseId': 'eng101', 'present': false, 'daysAgo': 0},
      {'id': 'demo_att_${uid}_7', 'courseId': 'phy101', 'present': true, 'daysAgo': 1},
    ];
    for (final entry in attendanceEntries) {
      batch.set(
        _firestore.collection('attendance').doc(entry['id'] as String),
        {
          'studentId': uid,
          'courseId': entry['courseId'],
          'date': now.toDate().subtract(Duration(days: entry['daysAgo'] as int)),
          'present': entry['present'],
          'status': (entry['present'] as bool) ? 'present' : 'absent',
        },
        SetOptions(merge: true),
      );
    }

    final assignments = [
      {
        'assignmentId': 'demo_asg_1',
        'courseId': 'cse101',
        'title': 'Graph Algorithms Quiz',
        'description': 'BFS, DFS and shortest path concepts.',
        'dueDate': now.toDate().add(const Duration(days: 7)),
      },
      {
        'assignmentId': 'demo_asg_2',
        'courseId': 'cse102',
        'title': 'Process Scheduling Assignment',
        'description': 'Implement RR and SJF scheduler logic.',
        'dueDate': now.toDate().add(const Duration(days: 3)),
      },
      {
        'assignmentId': 'demo_asg_3',
        'courseId': 'mat101',
        'title': 'SQL Lab 4',
        'description': 'Joins, nested queries and view creation.',
        'dueDate': now.toDate().add(const Duration(days: 5)),
      },
      {
        'assignmentId': 'demo_asg_4',
        'courseId': 'eng101',
        'title': 'FFT Mini Project',
        'description': 'Signal denoising using FFT pipeline.',
        'dueDate': now.toDate().add(const Duration(days: 10)),
      },
      {
        'assignmentId': 'demo_asg_5',
        'courseId': 'phy101',
        'title': 'Regression Model Report',
        'description': 'Compare linear, ridge, lasso on dataset.',
        'dueDate': now.toDate().add(const Duration(days: 12)),
      },
    ];
    for (final assignment in assignments) {
      batch.set(
        _firestore.collection('assignments').doc(assignment['assignmentId'] as String),
        {
          ...assignment,
          'createdBy': 'faculty1',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final notifications = [

      {
        'notificationId': 'demo_notif_${uid}_2',
        'userId': uid,
        'title': 'Assignment Due',
        'body': 'Programming Fundamentals Quiz is due in 5 days.',
        'type': 'assignment',
      },
      {
        'notificationId': 'demo_notif_${uid}_3',
        'userId': uid,
        'title': 'Attendance Reminder',
        'body': 'Your attendance in CS102 was marked absent today.',
        'type': 'attendance',
      },
      {
        'notificationId': 'demo_notif_${uid}_4',
        'userId': uid,
        'title': 'New Quiz Published',
        'body': 'A new quiz has been added for Programming Fundamentals.',
        'type': 'assignment',
      },
    ];
    for (final notification in notifications) {
      batch.set(
        _firestore.collection('notifications').doc(notification['notificationId'] as String),
        {
          ...notification,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final demoResultMarks = <String, int>{
      'cse101': 88,
      'cse102': 91,
      'mat101': 79,
      'eng101': 67,
      'phy101': 73,
      'cse103': 84,
    };
    for (final course in courses) {
      final courseId = course['courseId'] as String;
      final marks = demoResultMarks[courseId];
      if (marks == null) continue;
      final grade = gradeFromMarks(marks);
      batch.set(
        _firestore.collection('results').doc('${courseId}_$uid'),
        {
          'studentId': uid,
          'courseId': courseId,
          'courseCode': course['code'],
          'courseName': course['title'],
          'semester': course['semester'],
          'credits': course['credits'],
          'marks': marks,
          'grade': grade,
          'gradePoint': gradePointForGrade(grade),
          'uploadedBy': course['facultyId'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Keep the student's visible semester aligned with the canonical data set.
  }

  Future<void> cleanupLegacyDemoData({
    required String uid,
    required String role,
  }) async {
    final batch = _firestore.batch();
    final demoCourseIds = <String>{
      'cse101',
      'cse102',
      'mat101',
      'eng101',
      'phy101',
      'cse103',
    };

    final courseSnap = await _firestore.collection('courses').get();
    for (final doc in courseSnap.docs) {
      final data = doc.data();
      final courseId = (data['courseId'] ?? doc.id).toString();
      final facultyId = (data['facultyId'] ?? data['faculty_id'] ?? '').toString();
      final createdBy = (data['createdBy'] ?? '').toString();
      final code = (data['code'] ?? data['courseCode'] ?? data['course_code'] ?? '').toString();

      if (facultyId == 'faculty_demo' ||
          demoCourseIds.contains(courseId) ||
          demoCourseIds.contains(code) ||
          courseId.startsWith('fac_') ||
          createdBy == 'faculty_demo') {
        batch.delete(doc.reference);
      }
    }

    final enrollmentSnap = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: uid)
        .get();
    for (final doc in enrollmentSnap.docs) {
      final courseId = (doc.data()['courseId'] ?? '').toString();
      if (demoCourseIds.contains(courseId) || courseId.startsWith('fac_') || doc.id.startsWith('demo_') || doc.id.startsWith('bridge_')) {
        batch.delete(doc.reference);
      }
    }

    final attendanceSnap = await _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: uid)
        .get();
    for (final doc in attendanceSnap.docs) {
      final courseId = (doc.data()['courseId'] ?? '').toString();
      if (demoCourseIds.contains(courseId) || courseId.startsWith('fac_') || doc.id.startsWith('demo_')) {
        batch.delete(doc.reference);
      }
    }

    final notificationSnap = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in notificationSnap.docs) {
      final data = doc.data();
      final courseId = (data['courseId'] ?? '').toString();
      final createdBy = (data['createdBy'] ?? '').toString();
      if (demoCourseIds.contains(courseId) || courseId.startsWith('fac_') || createdBy == 'faculty_demo' || doc.id.startsWith('demo_')) {
        batch.delete(doc.reference);
      }
    }

    final resultsSnap = await _firestore
        .collection('results')
        .where('studentId', isEqualTo: uid)
        .get();
    for (final doc in resultsSnap.docs) {
      final data = doc.data();
      final courseId = (data['courseId'] ?? '').toString();
      if (demoCourseIds.contains(courseId) || courseId.startsWith('fac_') || doc.id.startsWith('demo_') || doc.id.startsWith('res_')) {
        batch.delete(doc.reference);
      }
    }

    for (var i = 1; i <= 5; i++) {
      batch.delete(_firestore.collection('enrollments').doc('demo_enr_${uid}_$i'));
    }
    for (var i = 1; i <= 7; i++) {
      batch.delete(_firestore.collection('attendance').doc('demo_att_${uid}_$i'));
    }
    for (var i = 1; i <= 4; i++) {
      batch.delete(_firestore.collection('notifications').doc('demo_notif_${uid}_$i'));
    }

    final assignmentSnap = await _firestore
        .collection('assignments')
        .where('createdBy', isEqualTo: 'faculty_demo')
        .get();
    for (final doc in assignmentSnap.docs) {
      batch.delete(doc.reference);
    }

    if (role == 'faculty') {
      final facultyAssignmentSnap = await _firestore
          .collection('assignments')
          .where('createdBy', isEqualTo: uid)
          .get();
      for (final doc in facultyAssignmentSnap.docs) {
        final courseId = (doc.data()['courseId'] ?? '').toString();
        if (courseId.startsWith('fac_')) {
          batch.delete(doc.reference);
        }
      }
    }

    await batch.commit();

    if (role == 'student') {
      final remainingEnrollments = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();
      final remainingCourseIds = remainingEnrollments.docs
          .map((doc) => (doc.data()['courseId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final semesterSet = <int>{};
      for (final courseId in remainingCourseIds) {
        final courseDoc = await _firestore.collection('courses').doc(courseId).get();
        if (!courseDoc.exists || courseDoc.data() == null) continue;
        final semester = _semesterNumber(courseDoc.data()!['semester']);
        if (semester != null) {
          semesterSet.add(semester);
        }
      }

      if (semesterSet.length == 1) {
        final semester = semesterSet.first;
        final userRef = _firestore.collection('users').doc(uid);
        final studentRef = _firestore.collection('students').doc(uid);
        await userRef.set({'semester': semester}, SetOptions(merge: true));
        await studentRef.set({'semester': semester}, SetOptions(merge: true));
      }
    }
  }

  Future<void> ensureDemoStudentSemesterFive({
    required String uid,
    required String email,
  }) async {
    await cleanupLegacyDemoData(uid: uid, role: 'student');
    await _firestore.collection('users').doc(uid).set(
      {
        'name': 'Aarav Agarwal',
        'email': email,
        'role': 'student',
        'uid_firebase': uid,
        'fcm_token': '',
        'created_at': FieldValue.serverTimestamp(),
        'department': 'CSE',
        'semester': 5,
        'division': 'A',
        'section': 'A',
      },
      SetOptions(merge: true),
    );
    await _firestore.collection('students').doc(uid).set(
      {
        'user_id': uid,
        'enrollment_no': 'BT21CSE001',
        'department': 'CSE',
        'semester': 5,
        'division': 'A',
        'section': 'A',
        'classroom_student_id': null,
      },
      SetOptions(merge: true),
    );
    await AdminModuleService.instance.seedSemesterEnrollments(
      studentId: uid,
      department: 'CSE',
      semester: 5,
    );
  }

  Future<void> purgeMistakenStudentAccount({
    required String uid,
    required String email,
  }) async {
    final batch = _firestore.batch();

    final collections = <String>[
      'users',
      'students',
      'enrollments',
      'upcomingEnrollments',
      'attendance',
      'notifications',
      'results',
      'registrations',
      'quiz_submissions',
      'submissions',
    ];

    for (final collection in collections) {
      final field = collection == 'submissions' ? 'student_id' : 'studentId';
      final snap = await _firestore.collection(collection).where(field, isEqualTo: uid).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    for (final collection in ['users', 'students']) {
      final doc = await _firestore.collection(collection).doc(uid).get();
      if (doc.exists) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        await currentUser.delete();
      } catch (_) {
        // Ignore auth deletion failures here; Firestore cleanup already ran.
      }
    }
  }

  Future<void> ensureFacultyDemoData({
    required String uid,
    required String email,
  }) async {
    final now = Timestamp.now();
    final name = 'Dr. Priya Sharma';

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'name': name,
      'email': email,
      'role': 'faculty',
      'uid_firebase': uid,
      'fcm_token': '',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_firestore.collection('faculty').doc(uid), {
      'user_id': uid,
      'employee_id': uid.substring(0, uid.length > 8 ? 8 : uid.length).toUpperCase(),
      'designation': 'Assistant Professor',
      'department': 'CSE',
      'classroom_teacher_id': null,
    }, SetOptions(merge: true));

    final courses = [
      {
        'courseId': 'cse301',
        'title': 'Data Structures & Algorithms',
        'code': 'CS301',
        'description': 'Advanced algorithms, complexity analysis and graph theory.',
        'credits': 4,
        'facultyId': uid,
        'facultyName': name,
        'semester': 5,
        'department': 'CSE',
      },
      {
        'courseId': 'cse302',
        'title': 'Operating Systems',
        'code': 'CS302',
        'description': 'Process management, memory allocation and kernel architecture.',
        'credits': 4,
        'facultyId': uid,
        'facultyName': name,
        'semester': 5,
        'department': 'CSE',
      },
      {
        'courseId': 'cse303',
        'title': 'Database Management Systems',
        'code': 'CS303',
        'description': 'Relational model, transactions, indexing and optimization.',
        'credits': 4,
        'facultyId': uid,
        'facultyName': name,
        'semester': 5,
        'department': 'CSE',
      },
      {
        'courseId': 'ece305',
        'title': 'Digital Signal Processing',
        'code': 'EC305',
        'description': 'Signal filtering, spectrum analysis and transform methods.',
        'credits': 4,
        'facultyId': 'f002',
        'facultyName': 'Dr. Amit Kulkarni',
        'semester': 5,
        'department': 'ECE',
      },
      {
        'courseId': 'aiml306',
        'title': 'Machine Learning',
        'code': 'AI306',
        'description': 'Supervised learning, model evaluation and deployment basics.',
        'credits': 4,
        'facultyId': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'semester': 5,
        'department': 'AI-DS',
      },
      {
        'courseId': 'aiml307',
        'title': 'Artificial Intelligence',
        'code': 'AI307',
        'description': 'Search strategies, reasoning and intelligent agents.',
        'credits': 3,
        'facultyId': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'semester': 5,
        'department': 'AI-DS',
      },
    ];

    for (final course in courses) {
      batch.set(
        _firestore.collection('courses').doc(course['courseId'] as String),
        {
          ...course,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final studentQuery = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    final studentIds = studentQuery.docs
        .where((doc) {
          final data = doc.data();
          final department = (data['department'] ?? '').toString().trim().toUpperCase();
          final semester = (data['semester'] as num?)?.toInt() ?? int.tryParse(data['semester']?.toString() ?? '') ?? 0;
          return department == 'CSE' && semester == 5;
        })
        .map((doc) => doc.id)
        .where((id) => id.trim().isNotEmpty)
        .toList();

    for (final course in courses.where((course) => course['facultyId'] == uid)) {
      for (final studentId in studentIds) {
        batch.set(
          _firestore.collection('enrollments').doc('enr_${course['courseId']}_$studentId'),
          {
            'studentId': studentId,
            'courseId': course['courseId'],
            'status': 'active',
            'enrolledAt': now.toDate(),
          },
          SetOptions(merge: true),
        );
      }
    }

    final demoResultMarks = <String, int>{
      'cse301': 88,
      'cse302': 91,
      'cse303': 79,
      'ece305': 67,
      'aiml306': 73,
      'aiml307': 84,
    };
    for (final course in courses.where((course) => course['facultyId'] != uid)) {
      final courseId = course['courseId'] as String;
      final marks = demoResultMarks[courseId];
      if (marks == null) continue;
      final grade = gradeFromMarks(marks);
      for (final studentId in studentIds) {
        batch.set(
          _firestore.collection('results').doc('${courseId}_$studentId'),
          {
            'studentId': studentId,
            'courseId': courseId,
            'courseCode': course['code'],
            'courseName': course['title'],
            'semester': course['semester'],
            'credits': course['credits'],
            'marks': marks,
            'grade': grade,
            'gradePoint': gradePointForGrade(grade),
            'uploadedBy': course['facultyId'],
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    // Seed realistic attendance samples for faculty view.
    for (final course in courses.where((course) => course['facultyId'] == uid)) {
      for (var i = 0; i < studentIds.length; i++) {
        final studentId = studentIds[i];
        final present = i % 4 != 0;
        final attId = 'att_${course['courseId']}_${studentId}_$i';
        batch.set(
          _firestore.collection('attendance').doc(attId),
          {
            'studentId': studentId,
            'courseId': course['courseId'],
            'date': now.toDate().subtract(Duration(days: i % 3)),
            'present': present,
            'status': present ? 'present' : 'absent',
            'markedBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    batch.set(
      _firestore.collection('assignments').doc('asg_${courses.first['courseId']}_1'),
      {
        'courseId': courses.first['courseId'],
        'title': 'Graph Algorithms Quiz',
        'description': 'BFS, DFS and shortest path concepts.',
        'dueDate': now.toDate().add(const Duration(days: 6)),
        'createdBy': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    if (localPart.isEmpty) return 'User';
    return localPart
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  int? _semesterNumber(dynamic value) {
    if (value == null) return null;
    if (value is int) return value >= 1 && value <= 12 ? value : null;
    if (value is num) {
      final n = value.toInt();
      return n >= 1 && n <= 12 ? n : null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final exact = int.tryParse(text);
    if (exact != null && exact >= 1 && exact <= 12) return exact;
    final digits = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits != null && digits >= 1 && digits <= 12) return digits;
    return null;
  }

  Future<Map<String, dynamic>?> getRoleProfile(String role, String userId) async {
    try {
      String collectionPath;
      switch (role) {
        case 'student':
          collectionPath = 'students';
          break;
        case 'faculty':
          collectionPath = 'faculty';
          break;
        case 'admin':
          collectionPath = 'admins';
          break;
        default:
          return null;
      }

      final docSnapshot = await _firestore
          .collection(collectionPath)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return {'id': docSnapshot.id, ...docSnapshot.data()!};
      }

      final snapshot = await _firestore
          .collection(collectionPath)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.docs.isNotEmpty) {
        return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
      }
    } catch (e) {
      debugPrint('Error fetching role profile: $e');
      rethrow;
    }
    return null;
  }

  Future<void> seedDatabase() async {
    await SeedData.populate();
  }
}
