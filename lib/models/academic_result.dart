import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicResultItem {
  final String id;
  final String studentId;
  final String courseId;
  final String courseCode;
  final String courseName;
  final int semester;
  final int credits;
  final int marks;
  final String grade;
  final int gradePoint;
  final String? uploadedBy;
  final Timestamp? updatedAt;

  const AcademicResultItem({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.semester,
    required this.credits,
    required this.marks,
    required this.grade,
    required this.gradePoint,
    this.uploadedBy,
    this.updatedAt,
  });

  factory AcademicResultItem.fromMap(Map<String, dynamic> map, String id) {
    final marks = _int(map['marks'] ?? map['total'] ?? map['score']) ?? 0;
    final grade = _string(map['grade']) ?? gradeFromMarks(marks);
    return AcademicResultItem(
      id: id,
      studentId: _string(map['studentId'] ?? map['student_id']) ?? '',
      courseId: _string(map['courseId'] ?? map['course_id']) ?? '',
      courseCode: _string(map['courseCode'] ?? map['course_code']) ?? '',
      courseName: _string(map['courseName'] ?? map['course_name']) ?? '',
      semester: _int(map['semester']) ?? 0,
      credits: _int(map['credits']) ?? 0,
      marks: marks,
      grade: grade,
      gradePoint: gradePointForGrade(grade),
      uploadedBy: _string(map['uploadedBy'] ?? map['uploaded_by']),
      updatedAt: _timestamp(map['updatedAt'] ?? map['uploaded_at']),
    );
  }

  double get weightedScore => gradePoint * credits.toDouble();

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseName': courseName,
      'semester': semester,
      'credits': credits,
      'marks': marks,
      'grade': grade,
      'gradePoint': gradePoint,
      if (uploadedBy != null) 'uploadedBy': uploadedBy,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class SemesterAcademicSummary {
  final int semester;
  final List<AcademicResultItem> results;
  final double sgpa;

  const SemesterAcademicSummary({
    required this.semester,
    required this.results,
    required this.sgpa,
  });
}

class StudentAcademicRecord {
  final List<AcademicResultItem> currentSemesterResults;
  final List<SemesterAcademicSummary> transcript;
  final double cgpa;
  final int completedCredits;

  const StudentAcademicRecord({
    required this.currentSemesterResults,
    required this.transcript,
    required this.cgpa,
    required this.completedCredits,
  });
}

String gradeFromMarks(int marks) {
  if (marks >= 90) return 'AA';
  if (marks >= 80) return 'AB';
  if (marks >= 70) return 'BB';
  if (marks >= 60) return 'BC';
  if (marks >= 50) return 'CC';
  if (marks >= 45) return 'CD';
  if (marks >= 40) return 'DD';
  return 'FF';
}

int gradePointForGrade(String grade) {
  switch (grade.trim().toUpperCase()) {
    case 'AA':
    case 'O':
      return 10;
    case 'AB':
    case 'A+':
      return 9;
    case 'BB':
    case 'A':
      return 8;
    case 'BC':
    case 'B+':
      return 7;
    case 'CC':
    case 'B':
      return 6;
    case 'CD':
    case 'C':
      return 5;
    case 'DD':
    case 'D':
      return 4;
    case 'FF':
    case 'F':
      return 0;
    default:
      return 0;
  }
}

double calculateSgpa(List<AcademicResultItem> results) {
  if (results.isEmpty) return 0;
  final totalCredits = results.fold<int>(0, (sum, item) => sum + item.credits);
  if (totalCredits == 0) return 0;
  final weighted = results.fold<double>(0, (sum, item) => sum + item.weightedScore);
  return weighted / totalCredits;
}

double calculateCgpa(List<AcademicResultItem> results) {
  if (results.isEmpty) return 0;
  final totalCredits = results.fold<int>(0, (sum, item) => sum + item.credits);
  if (totalCredits == 0) return 0;
  final weighted = results.fold<double>(0, (sum, item) => sum + item.weightedScore);
  return weighted / totalCredits;
}

StudentAcademicRecord buildAcademicRecord({
  required List<AcademicResultItem> results,
  required int currentSemester,
}) {
  final sorted = [...results]..sort((a, b) {
      final semesterCompare = a.semester.compareTo(b.semester);
      if (semesterCompare != 0) return semesterCompare;
      return a.courseCode.compareTo(b.courseCode);
    });

  final currentSemesterResults = sorted.where((item) => item.semester == currentSemester).toList();

  final grouped = <int, List<AcademicResultItem>>{};
  for (final item in sorted) {
    grouped.putIfAbsent(item.semester, () => []).add(item);
  }

  final transcript = grouped.entries
      .map(
        (entry) => SemesterAcademicSummary(
          semester: entry.key,
          results: entry.value,
          sgpa: calculateSgpa(entry.value),
        ),
      )
      .toList()
    ..sort((a, b) => a.semester.compareTo(b.semester));

  final completedCredits = sorted.fold<int>(0, (sum, item) => sum + item.credits);
  final cgpa = calculateCgpa(sorted);

  return StudentAcademicRecord(
    currentSemesterResults: currentSemesterResults,
    transcript: transcript,
    cgpa: cgpa,
    completedCredits: completedCredits,
  );
}

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

Timestamp? _timestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  return null;
}
