import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalCacheService {
  LocalCacheService._();

  static final LocalCacheService instance = LocalCacheService._();

  Future<Directory?> _baseDirectory() async {
    if (kIsWeb) return null;
    final directory = await getApplicationSupportDirectory();
    final cacheDir = Directory('${directory.path}${Platform.pathSeparator}uniflow_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File?> _fileForKey(String key) async {
    final base = await _baseDirectory();
    if (base == null) return null;
    final encoded = base64Url.encode(utf8.encode(key));
    return File('${base.path}${Platform.pathSeparator}$encoded.json');
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final file = await _fileForKey(key);
    if (file == null || !await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    final file = await _fileForKey(key);
    if (file == null) return;
    final encoded = jsonEncode(_jsonSafe(value));
    await file.writeAsString(encoded, flush: true);
  }

  Future<void> delete(String key) async {
    final file = await _fileForKey(key);
    if (file == null || !await file.exists()) return;
    await file.delete();
  }

  Future<bool> exists(String key) async {
    final file = await _fileForKey(key);
    if (file == null) return false;
    return file.exists();
  }

  Map<String, dynamic> _jsonSafe(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key, _jsonValue(value)));
  }

  Object? _jsonValue(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry(key.toString(), _jsonValue(entryValue)));
    }
    if (value is Iterable) {
      return value.map(_jsonValue).toList();
    }
    return value.toString();
  }
}
