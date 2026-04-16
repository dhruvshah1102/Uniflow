import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_result.dart';

class AcademicResultsService {
  AcademicResultsService._();

  static final AcademicResultsService instance = AcademicResultsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AcademicResultItem>> watchStudentResults(String studentId) {
    final normalized = studentId.trim();
    if (normalized.isEmpty) {
      return Stream.value(const <AcademicResultItem>[]);
    }

    return _db.collection('results').where('studentId', isEqualTo: normalized).snapshots().map(
      (snapshot) {
        final results = snapshot.docs
            .map((doc) => AcademicResultItem.fromMap(doc.data(), doc.id))
            .where((item) => !item.isDemoSeed)
            .toList()
          ..sort((a, b) {
            final semesterCompare = a.semester.compareTo(b.semester);
            if (semesterCompare != 0) return semesterCompare;
            return a.courseCode.compareTo(b.courseCode);
          });
        return results;
      },
    );
  }

  Stream<StudentAcademicRecord> watchStudentAcademicRecord({
    required String studentId,
    required int currentSemester,
  }) {
    final controller = StreamController<StudentAcademicRecord>.broadcast();
    StreamSubscription<List<AcademicResultItem>>? subscription;
    var closed = false;

    void emit(List<AcademicResultItem> results) {
      if (closed || controller.isClosed) return;
      controller.add(buildAcademicRecord(results: results, currentSemester: currentSemester));
    }

    controller.onListen = () {
      subscription = watchStudentResults(studentId).listen(
        emit,
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      closed = true;
      await subscription?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<List<AcademicResultItem>> fetchStudentResults(String studentId) async {
    final snap = await _db.collection('results').where('studentId', isEqualTo: studentId.trim()).get();
    return snap.docs.map((doc) => AcademicResultItem.fromMap(doc.data(), doc.id)).toList();
  }
}
