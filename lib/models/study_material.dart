import 'package:cloud_firestore/cloud_firestore.dart';

class StudyMaterialModel {
  final String id;
  final String courseId;
  final String fileName;
  final String fileUrl;
  final String uploadedBy;
  final Timestamp uploadedAt;
  final String storagePath;
  final String contentType;
  final int fileSize;

  const StudyMaterialModel({
    required this.id,
    required this.courseId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    this.storagePath = '',
    this.contentType = '',
    this.fileSize = 0,
  });

  factory StudyMaterialModel.fromMap(Map<String, dynamic> data, String id) {
    return StudyMaterialModel(
      id: id,
      courseId: (data['courseId'] ?? '').toString(),
      fileName: (data['fileName'] ?? data['title'] ?? 'Study Material')
          .toString(),
      fileUrl: (data['fileUrl'] ?? '').toString(),
      uploadedBy: (data['uploadedBy'] ?? '').toString(),
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
      storagePath: (data['storagePath'] ?? '').toString(),
      contentType: (data['contentType'] ?? '').toString(),
      fileSize:
          (data['fileSize'] as num?)?.toInt() ??
          int.tryParse((data['fileSize'] ?? '').toString()) ??
          0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
      if (storagePath.isNotEmpty) 'storagePath': storagePath,
      if (contentType.isNotEmpty) 'contentType': contentType,
      if (fileSize > 0) 'fileSize': fileSize,
    };
  }
}
