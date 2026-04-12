import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/faculty_model.dart';
import '../models/admin_model.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? currentUser;
  StudentModel? studentProfile;
  FacultyModel? facultyProfile;
  AdminModel? adminProfile;

  bool isLoading = true;
  String? error;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      error = null;
      if (user != null) {
        await _fetchUserData(user.uid);
      } else {
        _clearUser();
      }
    });
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final userModel = await _authService.getUserData(uid);
      if (userModel != null) {
        currentUser = userModel;
        final profileData = await _authService.getRoleProfile(userModel.role, userModel.id);
        
        if (profileData != null) {
          final profileId = profileData['id'] as String;
          switch (userModel.role) {
            case 'student':
              studentProfile = StudentModel.fromMap(profileData, profileId);
              break;
            case 'faculty':
              facultyProfile = FacultyModel.fromMap(profileData, profileId);
              break;
            case 'admin':
              adminProfile = AdminModel.fromMap(profileData, profileId);
              break;
          }
        }
        await PushNotificationService.instance.bindUser(currentUser!);
      } else {
        _clearUser();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _clearUser() {
    unawaited(PushNotificationService.instance.clearBinding());
    currentUser = null;
    studentProfile = null;
    facultyProfile = null;
    adminProfile = null;
    isLoading = false;
    notifyListeners();
  }

  Future<UserModel?> login(
    String email,
    String password, {
    String? roleHint,
  }) async {
    try {
      error = null;
      notifyListeners();
      await _authService.login(email, password);
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        throw Exception('Signed in user not found');
      }

      await _fetchUserData(uid);

      if (roleHint != null &&
          (currentUser == null || currentUser!.role.trim().isEmpty)) {
        await _authService.ensureUserRecord(
          uid: uid,
          email: email,
          role: roleHint,
        );
        await _fetchUserData(uid);
      }

      final normalizedRole = (currentUser?.role ?? roleHint ?? '').trim().toLowerCase();
      if (normalizedRole == 'student' || normalizedRole == 'faculty') {
        await _authService.cleanupLegacyDemoData(uid: uid, role: normalizedRole);
        if (normalizedRole == 'student') {
          await _authService.ensureStudentDemoData(
            uid: uid,
            email: email,
          );
        } else if (normalizedRole == 'faculty') {
          await _authService.ensureFacultyDemoData(
            uid: uid,
            email: email,
          );
        }
        await _fetchUserData(uid);
      }

      return currentUser;
    } catch (e) {
      error = 'Invalid email or password';
      notifyListeners();
      throw e;
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.instance.clearBinding();
      await _authService.logout();
      // _init listener will trigger _clearUser
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> seedDatabase() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _authService.seedDatabase();
    } catch (e) {
      error = 'Failed to seed database';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
