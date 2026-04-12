import 'dart:typed_data';

import 'package:dio/dio.dart';

class SupabaseStorageConfig {
  final String url;
  final String anonKey;
  final String bucketName;

  const SupabaseStorageConfig({
    required this.url,
    required this.anonKey,
    required this.bucketName,
  });

  bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && bucketName.isNotEmpty;

  factory SupabaseStorageConfig.fromEnvironment({
    String bucketName = 'study-materials',
  }) {
    return SupabaseStorageConfig(
      url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      ),
      bucketName: bucketName,
    );
  }
}

class StudyMaterialUploadResult {
  final String fileName;
  final String storagePath;
  final String publicUrl;
  final String contentType;
  final int fileSize;

  const StudyMaterialUploadResult({
    required this.fileName,
    required this.storagePath,
    required this.publicUrl,
    required this.contentType,
    required this.fileSize,
  });
}

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  SupabaseStorageConfig get _config => SupabaseStorageConfig.fromEnvironment();

  Future<StudyMaterialUploadResult> uploadStudyMaterial({
    required Uint8List bytes,
    required String fileName,
    required String courseId,
    required String facultyId,
    String? contentType,
  }) async {
    final config = _config;
    if (!config.isConfigured) {
      throw Exception(
        'Supabase storage is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY before uploading files.',
      );
    }

    final safeFileName = _sanitizeFileName(fileName);
    final objectPath =
        '${_sanitizeSegment(facultyId)}/${_sanitizeSegment(courseId)}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final uploadUrl =
        '${config.url}/storage/v1/object/${config.bucketName}/$objectPath';
    final mimeType = (contentType != null && contentType.trim().isNotEmpty)
        ? contentType.trim()
        : _mimeTypeFromFileName(fileName);

    final response = await _dio.put<dynamic>(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.anonKey}',
          'apikey': config.anonKey,
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        responseType: ResponseType.json,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Supabase upload failed with status $statusCode.');
    }

    final publicUrl =
        '${config.url}/storage/v1/object/public/${config.bucketName}/$objectPath';
    return StudyMaterialUploadResult(
      fileName: fileName,
      storagePath: objectPath,
      publicUrl: publicUrl,
      contentType: mimeType,
      fileSize: bytes.lengthInBytes,
    );
  }

  String _sanitizeFileName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'study_material';
    return trimmed
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _sanitizeSegment(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'unknown';
    return trimmed
        .replaceAll(RegExp(r'[^\w\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _mimeTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
