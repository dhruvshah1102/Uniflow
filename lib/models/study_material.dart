import 'package:cloud_firestore/cloud_firestore.dart';

class StudyMaterialModel {
  final String id;
  final String courseId;
  final String fileName;
  final String fileUrl;
  final String uploadedBy;
  final Timestamp uploadedAt;

  const StudyMaterialModel({
    required this.id,
    required this.courseId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  factory StudyMaterialModel.fromMap(Map<String, dynamic> data, String id) {
    return StudyMaterialModel(
      id: id,
      courseId: (data['courseId'] ?? '').toString(),
      fileName: (data['fileName'] ?? data['title'] ?? 'Study Material').toString(),
      fileUrl: (data['fileUrl'] ?? '').toString(),
      uploadedBy: (data['uploadedBy'] ?? '').toString(),
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
    };
  }
}
