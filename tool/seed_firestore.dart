import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

Future<void> main() async {
  // Prompt to avoid accidental reseeding
  stdout.writeln('This will seed the Firestore database with sample data for the Uniflow prototype.');
  stdout.write('Proceed? (y/N): ');
  String? answer = stdin.readLineSync();
  if (answer == null || answer.toLowerCase() != 'y') {
    stdout.writeln('Seeding aborted.');
    return;
  }

  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ---------- Users ----------
  final adminId = 'uid_admin001';
  final facultyId = 'uid_faculty001';
  final studentId = 'uid_student001';

  await db.collection('users').doc(adminId).set({
    'uid': adminId,
    'name': 'Admin User',
    'email': 'admin@iiitn.ac.in',
    'role': 'admin',
    'createdAt': Timestamp.now(),
  });

  await db.collection('users').doc(facultyId).set({
    'uid': facultyId,
    'name': 'Dr. Aditi Sharma',
    'email': 'aditi.sharma@iiitn.ac.in',
    'role': 'faculty',
    'createdAt': Timestamp.now(),
  });

  await db.collection('users').doc(studentId).set({
    'uid': studentId,
    'name': 'Rohit Kumar',
    'email': 'rohit.kumar@iiitn.ac.in',
    'role': 'student',
    'createdAt': Timestamp.now(),
  });

  // ---------- Courses ----------
  final course1Id = 'course_ENG101';
  final course2Id = 'course_CSE201';

  await db.collection('courses').doc(course1Id).set({
    'title': 'Engineering Mathematics I',
    'code': 'ENG101',
    'description': 'Calculus, Linear Algebra, Differential Equations',
    'credits': 4,
    'facultyId': facultyId,
    'semester': 'Fall 2026',
    'createdAt': Timestamp.now(),
  });

  await db.collection('courses').doc(course2Id).set({
    'title': 'Data Structures',
    'code': 'CSE201',
    'description': 'Lists, Trees, Graphs, Algorithms',
    'credits': 3,
    'facultyId': facultyId,
    'semester': 'Fall 2026',
    'createdAt': Timestamp.now(),
  });

  // ---------- Enrollments ----------
  final enroll1Id = 'enroll_${studentId}_$course1Id';
  final enroll2Id = 'enroll_${studentId}_$course2Id';

  await db.collection('enrollments').doc(enroll1Id).set({
    'studentId': studentId,
    'courseId': course1Id,
    'enrolledAt': Timestamp.now(),
    'status': 'active',
  });

  await db.collection('enrollments').doc(enroll2Id).set({
    'studentId': studentId,
    'courseId': course2Id,
    'enrolledAt': Timestamp.now(),
    'status': 'active',
  });

  // ---------- Attendance (sample for current month) ----------
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  for (int i = 0; i < 10; i++) {
    final date = Timestamp.fromDate(startOfMonth.add(Duration(days: i * 2)));
    await db.collection('attendance').add({
      'studentId': studentId,
      'courseId': course1Id,
      'date': date,
      'present': i % 3 != 0, // some absences
    });
    await db.collection('attendance').add({
      'studentId': studentId,
      'courseId': course2Id,
      'date': date,
      'present': true,
    });
  }

  // ---------- Assignments ----------
  final assign1Id = 'assign_${course1Id}_1';
  final assign2Id = 'assign_${course1Id}_2';
  final assign3Id = 'assign_${course2Id}_1';
  final assign4Id = 'assign_${course2Id}_2';

  await db.collection('assignments').doc(assign1Id).set({
    'courseId': course1Id,
    'title': 'Homework 1',
    'description': 'Solve problems 1‑10 from chapter 2',
    'dueDate': Timestamp.fromDate(now.add(Duration(days: 7))),
    'createdBy': facultyId,
    'createdAt': Timestamp.now(),
  });

  await db.collection('assignments').doc(assign2Id).set({
    'courseId': course1Id,
    'title': 'Quiz 1',
    'description': 'In‑class quiz covering chapters 1‑2',
    'dueDate': Timestamp.fromDate(now.add(Duration(days: 14))),
    'createdBy': facultyId,
    'createdAt': Timestamp.now(),
  });

  await db.collection('assignments').doc(assign3Id).set({
    'courseId': course2Id,
    'title': 'Project Proposal',
    'description': 'Submit a one‑page proposal for the semester project',
    'dueDate': Timestamp.fromDate(now.add(Duration(days: 10))),
    'createdBy': facultyId,
    'createdAt': Timestamp.now(),
  });

  await db.collection('assignments').doc(assign4Id).set({
    'courseId': course2Id,
    'title': 'Lab Exercise 1',
    'description': 'Implement a linked list in Dart',
    'dueDate': Timestamp.fromDate(now.add(Duration(days: 12))),
    'createdBy': facultyId,
    'createdAt': Timestamp.now(),
  });

  // ---------- Notifications ----------
  await db.collection('notifications').add({
    'userId': studentId,
    'title': 'Welcome to Uniflow',
    'body': 'Your account has been created. Explore your dashboard!',
    'type': 'general',
    'read': false,
    'createdAt': Timestamp.now(),
  });

  stdout.writeln('Seeding completed successfully.');
}
