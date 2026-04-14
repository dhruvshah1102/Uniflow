import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_result.dart';

class TranscriptService {
  TranscriptService._();
  static final TranscriptService instance = TranscriptService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<StudentAcademicRecord> watchComprehensiveTranscript({
    required String studentId,
    required int currentSemester,
  }) {
    final controller = StreamController<StudentAcademicRecord>.broadcast();
    StreamSubscription? transcriptsSub;
    StreamSubscription? resultsSub;
    var closed = false;

    // We will hold both datasets
    List<AcademicResultItem> pastSemesters = [];
    List<AcademicResultItem> currentSemResults = [];

    void emit() {
      if (closed || controller.isClosed) return;
      final allResults = [...pastSemesters, ...currentSemResults];
      controller.add(buildAcademicRecord(results: allResults, currentSemester: currentSemester));
    }

    controller.onListen = () {
      // 1. Fetch past transcripts (Sem 1-4)
      transcriptsSub = _db.collection('transcripts')
          .where('studentId', isEqualTo: studentId)
          .snapshots().listen((snap) async {
        
        bool needsReseed = snap.docs.isEmpty;
        if (!needsReseed) {
           final firstDoc = snap.docs.first.data();
           final courses = firstDoc['courses'] as List<dynamic>? ?? [];
           if (courses.isNotEmpty && (courses[0]['marks'] == null || courses[0]['marks'] == 0)) {
               needsReseed = true;
           }
        }

        if (needsReseed) {
           await _seedMockTranscripts(studentId, currentSemester);
           return;
        }

        pastSemesters.clear();
        for (var doc in snap.docs) {
          final data = doc.data();
          final sem = data['semester'] as int? ?? 0;
          final courses = data['courses'] as List<dynamic>? ?? [];
          for (var c in courses) {
             final cm = c as Map<String, dynamic>;
             pastSemesters.add(AcademicResultItem(
               id: doc.id + '_' + (cm['courseCode'] ?? ''),
               studentId: studentId,
               courseId: cm['courseCode'] ?? '',
               courseCode: cm['courseCode'] ?? '',
               courseName: cm['courseName'] ?? '',
               semester: sem,
               credits: cm['credits'] ?? 0,
               marks: cm['marks'] ?? 0,
               grade: cm['grade'] ?? 'F',
               gradePoint: gradePointForGrade(cm['grade'] ?? 'F'),
             ));
          }
        }
        emit();
      });

      // 2. Fetch current semester from results (Sem 5)
      resultsSub = _db.collection('results')
          .where('studentId', isEqualTo: studentId)
          .snapshots().listen((snap) {
        
        currentSemResults = snap.docs
            .map((doc) => AcademicResultItem.fromMap(doc.data(), doc.id))
            .where((item) => item.semester == currentSemester) // Ensure only current semester
            .toList();
        emit();
      });
    };

    controller.onCancel = () async {
      closed = true;
      await transcriptsSub?.cancel();
      await resultsSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> _seedMockTranscripts(String studentId, int currentSemester) async {
    final existing = await _db.collection('transcripts').where('studentId', isEqualTo: studentId).get();
    final batch = _db.batch();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }
    
    for (int sem = 1; sem < currentSemester; sem++) {
       final grades = sem % 2 == 0 
           ? ['AA', 'AB', 'AA', 'BB', 'BC', 'CC']
           : ['AB', 'BB', 'AA', 'AB', 'AA', 'BC'];
       final marksList = sem % 2 == 0 
           ? [91, 85, 96, 75, 68, 55] 
           : [86, 78, 92, 85, 90, 65];

      final docRef = _db.collection('transcripts').doc('${studentId}_sem_$sem');
      final courses = [
        {'courseCode': 'CS${sem}01', 'courseName': 'Core Programming $sem.1', 'credits': 4, 'grade': grades[0], 'marks': marksList[0]},
        {'courseCode': 'CS${sem}02', 'courseName': 'Data Structures $sem.2', 'credits': 4, 'grade': grades[1], 'marks': marksList[1]},
        {'courseCode': 'CS${sem}03', 'courseName': 'Theory of Computing $sem.3', 'credits': 3, 'grade': grades[2], 'marks': marksList[2]},
        {'courseCode': 'CS${sem}04', 'courseName': 'Lab Application $sem.1', 'credits': 2, 'grade': grades[3], 'marks': marksList[3]},
        {'courseCode': 'ES${sem}01', 'courseName': 'Electronics $sem.1', 'credits': 3, 'grade': grades[4], 'marks': marksList[4]},
        {'courseCode': 'HS${sem}01', 'courseName': 'Humanities $sem.1', 'credits': 2, 'grade': grades[5], 'marks': marksList[5]},
      ];
      batch.set(docRef, {
        'studentId': studentId,
        'semester': sem,
        'courses': courses,
      });
    }
    await batch.commit();
  }
}
