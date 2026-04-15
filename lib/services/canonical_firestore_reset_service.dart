import 'package:cloud_firestore/cloud_firestore.dart';

class CanonicalFirestoreResetService {
  CanonicalFirestoreResetService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> resetCanonicalData({
    required String studentUid,
    required String facultyUid,
    required String adminUid,
  }) async {
    final now = DateTime.now();
    final writer = _BatchWriter(_db);

    await _clearCollections([
      'attendance',
      'assignments',
      'admins',
      'courses',
      'enrollments',
      'faculty',
      'notifications',
      'results',
      'registrations',
      'upcomingEnrollments',
      'students',
      'users',
    ]);

    _upsertUser(
      writer,
      id: studentUid,
      name: 'Aarav Agarwal',
      email: 'student1@iiitn.ac.in',
      role: 'student',
      department: 'CSE',
      semester: 5,
      division: 'A',
    );
    _upsertUser(
      writer,
      id: facultyUid,
      name: 'Dr. Priya Sharma',
      email: 'faculty1@iiitn.ac.in',
      role: 'faculty',
      department: 'CSE',
    );
    _upsertUser(
      writer,
      id: adminUid,
      name: 'Admin User',
      email: 'admin@iiitn.ac.in',
      role: 'admin',
      department: 'Admin',
    );

    writer.set(
      _db.collection('students').doc(studentUid),
      {
        'user_id': studentUid,
        'enrollment_no': 'BT21CSE001',
        'department': 'CSE',
        'semester': 5,
        'division': 'A',
        'section': 'A',
        'classroom_student_id': null,
      },
      merge: true,
    );

    writer.set(
      _db.collection('faculty').doc(facultyUid),
      {
        'user_id': facultyUid,
        'employee_id': 'FAC-1001',
        'designation': 'Associate Professor',
        'department': 'CSE',
        'classroom_teacher_id': null,
      },
      merge: true,
    );

    writer.set(
      _db.collection('admins').doc(adminUid),
      {'user_id': adminUid, 'admin_level': '1'},
      merge: true,
    );
    await writer.commit();

    final extraFaculty = <Map<String, dynamic>>[
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

    for (final faculty in extraFaculty) {
      _upsertUser(
        writer,
        id: faculty['id'] as String,
        name: faculty['name'] as String,
        email: faculty['email'] as String,
        role: 'faculty',
        department: faculty['department'] as String,
      );
      writer.set(
        _db.collection('faculty').doc(faculty['id'] as String),
        {
          'user_id': faculty['id'],
          'employee_id': faculty['employeeId'],
          'designation': 'Assistant Professor',
          'department': faculty['department'],
          'classroom_teacher_id': null,
        },
        merge: true,
      );
    }
    await writer.commit();

    final studentNames = <String>[
      'Ishita Mishra',
      'Kabir Khan',
      'Priya Patel',
      'Rahul Sharma',
      'Aditya Joshi',
      'Sneha Nair',
      'Yash Thakur',
      'Meera Iyer',
      'Rohan Deshmukh',
      'Ananya Roy',
      'Arjun Mehta',
      'Kriti Singh',
      'Nikhil Bansal',
      'Pooja Yadav',
      'Harsh Vardhan',
      'Devanshi Jain',
      'Vivek Choudhary',
      'Tanvi Gokhale',
      'Manav Sinha',
      'Ritika Dubey',
      'Kunal Pawar',
      'Shreya Nanda',
      'Samarjeet Das',
      'Nandini Rao',
      'Aman Tripathi',
      'Bhavya Arora',
      'Rudra Kulshreshtha',
      'Diya Khandelwal',
      'Omkar Patil',
    ];

    final departments = <String>[
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'CSE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'ECE',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
      'AI-DS',
    ];

    final allStudentIds = <String>[studentUid];
    for (var i = 0; i < studentNames.length; i++) {
      final id = 's${(i + 2).toString().padLeft(3, '0')}';
      final name = studentNames[i];
      final emailLocal = name.toLowerCase().replaceAll(' ', '.');
      final dept = departments[i];
      final division = i % 2 == 0 ? 'A' : 'B';
      allStudentIds.add(id);

      _upsertUser(
        writer,
        id: id,
        name: name,
        email: '$emailLocal@iiitn.ac.in',
        role: 'student',
        department: dept,
        semester: 5,
        division: division,
      );
      writer.set(
        _db.collection('students').doc(id),
        {
          'user_id': id,
          'enrollment_no': 'BT21${dept.replaceAll('-', '')}${(i + 2).toString().padLeft(3, '0')}',
          'department': dept,
          'semester': 5,
          'division': division,
          'section': division,
          'classroom_student_id': null,
        },
        merge: true,
      );
    }
    await writer.commit();

    final courses = <Map<String, dynamic>>[
      {
        'courseId': 'cse301',
        'courseCode': 'CS301',
        'courseName': 'Data Structures & Algorithms',
        'title': 'Data Structures & Algorithms',
        'code': 'CS301',
        'course_code': 'CS301',
        'course_name': 'Data Structures & Algorithms',
        'description': 'Advanced algorithms, complexity analysis and graph theory.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'CSE',
      },
      {
        'courseId': 'cse302',
        'courseCode': 'CS302',
        'courseName': 'Operating Systems',
        'title': 'Operating Systems',
        'code': 'CS302',
        'course_code': 'CS302',
        'course_name': 'Operating Systems',
        'description': 'Process management, memory allocation and kernel architecture.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'CSE',
      },
      {
        'courseId': 'cse303',
        'courseCode': 'CS303',
        'courseName': 'Database Management Systems',
        'title': 'Database Management Systems',
        'code': 'CS303',
        'course_code': 'CS303',
        'course_name': 'Database Management Systems',
        'description': 'Relational model, transactions, indexing and optimization.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'CSE',
      },
      {
        'courseId': 'ece305',
        'courseCode': 'EC305',
        'courseName': 'Digital Signal Processing',
        'title': 'Digital Signal Processing',
        'code': 'EC305',
        'course_code': 'EC305',
        'course_name': 'Digital Signal Processing',
        'description': 'Signal filtering, spectrum analysis and transform methods.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'ECE',
      },
      {
        'courseId': 'aiml306',
        'courseCode': 'AI306',
        'courseName': 'Machine Learning',
        'title': 'Machine Learning',
        'code': 'AI306',
        'course_code': 'AI306',
        'course_name': 'Machine Learning',
        'description': 'Supervised learning, model evaluation and deployment basics.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'AI-DS',
      },
      {
        'courseId': 'aiml307',
        'courseCode': 'AI307',
        'courseName': 'Artificial Intelligence',
        'title': 'Artificial Intelligence',
        'code': 'AI307',
        'course_code': 'AI307',
        'course_name': 'Artificial Intelligence',
        'description': 'Search strategies, reasoning and intelligent agents.',
        'credits': 3,
        'facultyId': 'f003',
        'faculty_id': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'faculty_name': 'Dr. Neha Verma',
        'semester': 5,
        'semesterLabel': 'Semester 5',
        'department': 'AI-DS',
      },
      {
        'courseId': 'cse201',
        'courseCode': 'CS201',
        'courseName': 'Discrete Mathematics',
        'title': 'Discrete Mathematics',
        'code': 'CS201',
        'course_code': 'CS201',
        'course_name': 'Discrete Mathematics',
        'description': 'Logic, recurrence relations, combinatorics and graph foundations.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 4,
        'semesterLabel': 'Semester 4',
        'department': 'CSE',
      },
      {
        'courseId': 'cse202',
        'courseCode': 'CS202',
        'courseName': 'Computer Organization',
        'title': 'Computer Organization',
        'code': 'CS202',
        'course_code': 'CS202',
        'course_name': 'Computer Organization',
        'description': 'Instruction sets, pipelining, memory hierarchy and I/O organization.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 4,
        'semesterLabel': 'Semester 4',
        'department': 'CSE',
      },
      {
        'courseId': 'cse203',
        'courseCode': 'CS203',
        'courseName': 'Design and Analysis of Algorithms',
        'title': 'Design and Analysis of Algorithms',
        'code': 'CS203',
        'course_code': 'CS203',
        'course_name': 'Design and Analysis of Algorithms',
        'description': 'Greedy methods, dynamic programming, divide and conquer and NP completeness.',
        'credits': 3,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 4,
        'semesterLabel': 'Semester 4',
        'department': 'CSE',
      },
      {
        'courseId': 'cse401',
        'courseCode': 'CS401',
        'courseName': 'Computer Networks',
        'title': 'Computer Networks',
        'code': 'CS401',
        'course_code': 'CS401',
        'course_name': 'Computer Networks',
        'description': 'Routing, congestion control and transport layer architecture.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse402',
        'courseCode': 'CS402',
        'courseName': 'Compiler Design',
        'title': 'Compiler Design',
        'code': 'CS402',
        'course_code': 'CS402',
        'course_name': 'Compiler Design',
        'description': 'Lexical analysis, parsing and code generation pipelines.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse403',
        'courseCode': 'CS403',
        'courseName': 'Software Engineering',
        'title': 'Software Engineering',
        'code': 'CS403',
        'course_code': 'CS403',
        'course_name': 'Software Engineering',
        'description': 'Requirements, estimation, testing and release management.',
        'credits': 3,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse404',
        'courseCode': 'CS404',
        'courseName': 'Information Security',
        'title': 'Information Security',
        'code': 'CS404',
        'course_code': 'CS404',
        'course_name': 'Information Security',
        'description': 'Cryptography, secure communication, authentication and access control.',
        'credits': 4,
        'facultyId': facultyUid,
        'faculty_id': facultyUid,
        'facultyName': 'Dr. Priya Sharma',
        'faculty_name': 'Dr. Priya Sharma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse405',
        'courseCode': 'CS405',
        'courseName': 'Data Warehousing and Mining',
        'title': 'Data Warehousing and Mining',
        'code': 'CS405',
        'course_code': 'CS405',
        'course_name': 'Data Warehousing and Mining',
        'description': 'Warehousing concepts, OLAP, classification, clustering and association mining.',
        'credits': 3,
        'facultyId': 'f004',
        'faculty_id': 'f004',
        'facultyName': 'Dr. Ananya Sharma',
        'faculty_name': 'Dr. Ananya Sharma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse406',
        'courseCode': 'CS406',
        'courseName': 'Mobile Application Development',
        'title': 'Mobile Application Development',
        'code': 'CS406',
        'course_code': 'CS406',
        'course_name': 'Mobile Application Development',
        'description': 'Cross-platform app design, state management, API integration and deployment.',
        'credits': 3,
        'facultyId': 'f005',
        'faculty_id': 'f005',
        'facultyName': 'Dr. Rohan Mehta',
        'faculty_name': 'Dr. Rohan Mehta',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'cse407',
        'courseCode': 'CS407',
        'courseName': 'Cloud Computing',
        'title': 'Cloud Computing',
        'code': 'CS407',
        'course_code': 'CS407',
        'course_name': 'Cloud Computing',
        'description': 'Virtualization, cloud service models, orchestration and distributed infrastructure.',
        'credits': 3,
        'facultyId': 'f006',
        'faculty_id': 'f006',
        'facultyName': 'Dr. Meera Joshi',
        'faculty_name': 'Dr. Meera Joshi',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'CSE',
      },
      {
        'courseId': 'ece401',
        'courseCode': 'EC401',
        'courseName': 'VLSI Design',
        'title': 'VLSI Design',
        'code': 'EC401',
        'course_code': 'EC401',
        'course_name': 'VLSI Design',
        'description': 'CMOS design principles, fabrication flow and timing analysis.',
        'credits': 4,
        'facultyId': 'f002',
        'faculty_id': 'f002',
        'facultyName': 'Dr. Amit Kulkarni',
        'faculty_name': 'Dr. Amit Kulkarni',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'ECE',
      },
      {
        'courseId': 'ece402',
        'courseCode': 'EC402',
        'courseName': 'Wireless Communication',
        'title': 'Wireless Communication',
        'code': 'EC402',
        'course_code': 'EC402',
        'course_name': 'Wireless Communication',
        'description': 'Cellular concepts, fading channels and wireless standards.',
        'credits': 3,
        'facultyId': 'f002',
        'faculty_id': 'f002',
        'facultyName': 'Dr. Amit Kulkarni',
        'faculty_name': 'Dr. Amit Kulkarni',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'ECE',
      },
      {
        'courseId': 'aiml401',
        'courseCode': 'AI401',
        'courseName': 'Deep Learning',
        'title': 'Deep Learning',
        'code': 'AI401',
        'course_code': 'AI401',
        'course_name': 'Deep Learning',
        'description': 'Neural networks, backpropagation and modern deep architectures.',
        'credits': 4,
        'facultyId': 'f003',
        'faculty_id': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'faculty_name': 'Dr. Neha Verma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'AI-DS',
      },
      {
        'courseId': 'aiml402',
        'courseCode': 'AI402',
        'courseName': 'Data Mining',
        'title': 'Data Mining',
        'code': 'AI402',
        'course_code': 'AI402',
        'course_name': 'Data Mining',
        'description': 'Pattern discovery, clustering, association rules and analytics.',
        'credits': 3,
        'facultyId': 'f003',
        'faculty_id': 'f003',
        'facultyName': 'Dr. Neha Verma',
        'faculty_name': 'Dr. Neha Verma',
        'semester': 6,
        'semesterLabel': 'Semester 6',
        'department': 'AI-DS',
      },
    ];

    for (final course in courses) {
      writer.set(
        _db.collection('courses').doc(course['courseId'] as String),
        {
          ...course,
          'createdAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
    }
    await writer.commit();

    final courseMap = {for (final course in courses) course['courseId'] as String: course};
    final resultSeeds = <Map<String, dynamic>>[
      {'courseId': 'cse201', 'semester': 4, 'marks': 78},
      {'courseId': 'cse202', 'semester': 4, 'marks': 85},
      {'courseId': 'cse203', 'semester': 4, 'marks': 72},
      {'courseId': 'cse301', 'semester': 5, 'marks': 88},
      {'courseId': 'cse302', 'semester': 5, 'marks': 91},
      {'courseId': 'cse303', 'semester': 5, 'marks': 79},
      {'courseId': 'ece305', 'semester': 5, 'marks': 67},
      {'courseId': 'aiml306', 'semester': 5, 'marks': 73},
      {'courseId': 'aiml307', 'semester': 5, 'marks': 84},
    ];

    for (final item in resultSeeds) {
      final courseId = item['courseId'] as String;
      final course = courseMap[courseId];
      if (course == null) continue;
      final marks = item['marks'] as int;
      final grade = _gradeFromMarks(marks);
      writer.set(
        _db.collection('results').doc('${courseId}_$studentUid'),
        {
          'studentId': studentUid,
          'courseId': courseId,
          'courseCode': course['courseCode'],
          'courseName': course['courseName'],
          'semester': item['semester'],
          'credits': course['credits'],
          'marks': marks,
          'grade': grade,
          'gradePoint': _gradePoint(grade),
          'uploadedBy': facultyUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
    }
    await writer.commit();

    final enrollmentMap = <String, List<String>>{
      'cse301': allStudentIds.take(16).toList(),
      'cse302': [allStudentIds.first, ...allStudentIds.skip(6).take(15)],
      'cse303': [allStudentIds.first, ...allStudentIds.skip(10).take(15)],
      'ece305': [allStudentIds.first, ...allStudentIds.skip(9).take(14)],
      'aiml306': [allStudentIds.first, ...allStudentIds.skip(18).take(12), ...allStudentIds.skip(7).take(2)],
      'aiml307': [allStudentIds.first, ...allStudentIds.skip(19).take(12), ...allStudentIds.skip(11).take(2)],
    };

    for (final entry in enrollmentMap.entries) {
      final courseId = entry.key;
      for (final studentId in entry.value.toSet()) {
        writer.set(
          _db.collection('enrollments').doc('enr_${courseId}_$studentId'),
          {
            'studentId': studentId,
            'courseId': courseId,
            'status': 'active',
            'enrolledAt': FieldValue.serverTimestamp(),
          },
          merge: true,
        );

        for (var d = 0; d < 4; d++) {
          final seed = '${studentId}_${courseId}_$d'.hashCode.abs();
          final present = seed % 100 >= 18;
          writer.set(
            _db.collection('attendance').doc('att_${courseId}_${studentId}_$d'),
            {
              'studentId': studentId,
              'courseId': courseId,
              'date': now.subtract(Duration(days: d * 2)),
              'present': present,
              'status': present ? 'present' : 'absent',
              'createdAt': FieldValue.serverTimestamp(),
            },
            merge: true,
          );
        }
      }
    }
    await writer.commit();

    final assignmentsByCourse = <String, List<Map<String, dynamic>>>{
      'cse301': [
        {'title': 'Graph Algorithms Quiz', 'description': 'BFS, DFS and shortest path concepts.', 'dueInDays': 5},
        {'title': 'Dynamic Programming Sheet', 'description': 'Solve 10 medium difficulty DP problems.', 'dueInDays': 11},
      ],
      'cse302': [
        {'title': 'Process Scheduling Assignment', 'description': 'Implement RR and SJF scheduler logic.', 'dueInDays': 6},
        {'title': 'Synchronization Case Study', 'description': 'Deadlock prevention and semaphore notes.', 'dueInDays': 12},
      ],
      'cse303': [
        {'title': 'SQL Lab 4', 'description': 'Joins, nested queries and view creation.', 'dueInDays': 4},
        {'title': 'Normalization Exercise', 'description': 'Normalize given schema up to 3NF.', 'dueInDays': 10},
      ],
      'ece305': [
        {'title': 'FFT Mini Project', 'description': 'Signal denoising using FFT pipeline.', 'dueInDays': 7},
        {'title': 'Filter Design Worksheet', 'description': 'Design LPF and HPF using constraints.', 'dueInDays': 13},
      ],
      'aiml306': [
        {'title': 'Regression Model Report', 'description': 'Compare linear, ridge, lasso on dataset.', 'dueInDays': 8},
        {'title': 'Classification Lab', 'description': 'Train and evaluate SVM and random forest.', 'dueInDays': 14},
      ],
      'aiml307': [
        {'title': 'Search Algorithms Quiz', 'description': 'A*, minimax and alpha-beta pruning.', 'dueInDays': 6},
        {'title': 'Knowledge Representation Note', 'description': 'Build ontology and inference flow.', 'dueInDays': 12},
      ],
    };

    assignmentsByCourse.forEach((courseId, list) {
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        final course = courses.firstWhere((c) => c['courseId'] == courseId);
        writer.set(
          _db.collection('assignments').doc('asg_${courseId}_${i + 1}'),
          {
            'courseId': courseId,
            'title': item['title'],
            'description': item['description'],
            'dueDate': now.add(Duration(days: item['dueInDays'] as int)),
            'createdBy': course['facultyId'],
            'status': 'published',
            'createdAt': FieldValue.serverTimestamp(),
          },
          merge: true,
        );
      }
    });
    await writer.commit();

    final announcements = <Map<String, dynamic>>[
      {'courseId': 'cse301', 'title': 'Tutorial Session Added', 'message': 'Extra tutorial on graph algorithms on Friday 4 PM.', 'type': 'academic'},
      {'courseId': 'cse302', 'title': 'Lab Rescheduled', 'message': 'OS lab shifted to Thursday due to maintenance.', 'type': 'schedule'},
      {'courseId': 'cse303', 'title': 'Assignment Reminder', 'message': 'SQL Lab 4 due in 2 days.', 'type': 'assignment'},
      {'courseId': 'ece305', 'title': 'Classroom Update', 'message': 'DSP lecture moved to Room B-204.', 'type': 'general'},
      {'courseId': 'aiml306', 'title': 'Model Evaluation Workshop', 'message': 'Hands-on workshop this Saturday.', 'type': 'event'},
      {'courseId': 'aiml307', 'title': 'Quiz Window Open', 'message': 'AI quiz attempt window: 6 PM to 8 PM.', 'type': 'quiz'},
    ];

    for (var i = 0; i < announcements.length; i++) {
      final ann = announcements[i];
      final courseId = ann['courseId'] as String;
      final targets = enrollmentMap[courseId] ?? <String>[];

      for (final studentId in targets) {
        writer.set(
          _db.collection('notifications').doc('not_${courseId}_${i}_$studentId'),
          {
            'userId': studentId,
            'courseId': courseId,
            'title': ann['title'],
            'message': ann['message'],
            'body': ann['message'],
            'type': ann['type'],
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
          merge: true,
        );
      }
    }

    await writer.commit();
  }

  static Future<void> _clearCollections(List<String> collections) async {
    for (final name in collections) {
      final snap = await _db.collection(name).get();
      WriteBatch batch = _db.batch();
      var ops = 0;
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops += 1;
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) {
        await batch.commit();
      }
    }
  }

  static void _upsertUser(
    _BatchWriter writer, {
    required String id,
    required String name,
    required String email,
    required String role,
    required String department,
    int? semester,
    String? division,
  }) {
    writer.set(
      _db.collection('users').doc(id),
      {
        'uid': id,
        'uid_firebase': id,
        'name': name,
        'email': email,
        'role': role,
        'department': department,
        if (semester != null) 'semester': semester,
        if (division != null) 'division': division,
        if (division != null) 'section': division,
        'fcm_token': '',
        'created_at': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  static String _gradeFromMarks(int marks) {
    if (marks >= 90) return 'AA';
    if (marks >= 80) return 'AB';
    if (marks >= 70) return 'BB';
    if (marks >= 60) return 'BC';
    if (marks >= 50) return 'CC';
    if (marks >= 45) return 'CD';
    if (marks >= 40) return 'DD';
    return 'FF';
  }

  static int _gradePoint(String grade) {
    switch (grade) {
      case 'AA':
        return 10;
      case 'AB':
        return 9;
      case 'BB':
        return 8;
      case 'BC':
        return 7;
      case 'CC':
        return 6;
      case 'CD':
        return 5;
      case 'DD':
        return 4;
      case 'FF':
        return 0;
      default:
        return 0;
    }
  }
}

class _BatchWriter {
  final FirebaseFirestore _db;
  WriteBatch _batch;
  int _ops = 0;

  _BatchWriter(this._db) : _batch = _db.batch();

  void set(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data, {bool merge = false}) {
    _batch.set(ref, data, SetOptions(merge: merge));
    _ops += 1;
    if (_ops >= 490) {
      throw StateError('Batch limit reached. Call commit() periodically.');
    }
  }

  Future<void> commit() async {
    if (_ops == 0) return;
    await _batch.commit();
    _batch = _db.batch();
    _ops = 0;
  }
}
