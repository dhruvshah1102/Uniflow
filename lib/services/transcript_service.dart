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
        pastSemesters.clear();
        for (var doc in snap.docs) {
          final data = doc.data();
          final sem = data['semester'] as int? ?? 0;
          if (sem >= currentSemester) continue;
          final courses = data['courses'] as List<dynamic>? ?? [];
          for (var c in courses) {
             final cm = c as Map<String, dynamic>;
             pastSemesters.add(AcademicResultItem(
               id: '${doc.id}_${cm['courseCode'] ?? ''}',
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
            .where(
              (item) =>
                  item.semester == currentSemester &&
                  item.status == 'published' &&
                  !item.isDemoSeed,
            )
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
}
