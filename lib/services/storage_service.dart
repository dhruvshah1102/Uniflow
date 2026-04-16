import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

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
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://eudymloxhsvvabxakwfg.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1ZHltbG94aHN2dmFieGFrd2ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwMDgxMTksImV4cCI6MjA5MTU4NDExOX0.U4OzvRlZsn5NTYk8x_PJDqc0lRaZobGIpFEMiUEGa4s',
      ),
      bucketName: bucketName,
    );
  }

  factory SupabaseStorageConfig.fromJson(Map<String, dynamic> json, {
    String bucketName = 'study-materials',
  }) {
    return SupabaseStorageConfig(
      url: (json['SUPABASE_URL'] ?? '').toString().trim(),
      anonKey: (json['SUPABASE_ANON_KEY'] ?? '').toString().trim(),
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
  SupabaseStorageConfig? _cachedConfig;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  Future<SupabaseStorageConfig> get _config async {
    final cached = _cachedConfig;
    if (cached != null) return cached;

    final envConfig = SupabaseStorageConfig.fromEnvironment();
    if (envConfig.isConfigured) {
      _cachedConfig = envConfig;
      return envConfig;
    }

    try {
      final raw = await rootBundle.loadString('env.json');
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        final jsonConfig = SupabaseStorageConfig.fromJson(parsed);
        if (jsonConfig.isConfigured) {
          _cachedConfig = jsonConfig;
          return jsonConfig;
        }
      }
    } catch (_) {
      // Fall through to the error below.
    }

    return envConfig;
  }

  Future<StudyMaterialUploadResult> uploadStudyMaterial({
    required Uint8List bytes,
    required String fileName,
    required String courseId,
    required String facultyId,
    String? contentType,
  }) async {
    final config = await _config;
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
