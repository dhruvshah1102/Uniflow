import 'dart:async';

import 'package:flutter/material.dart';
import '../models/admin_model.dart';
import '../models/faculty_model.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? currentUser;
  StudentModel? studentProfile;
  FacultyModel? facultyProfile;
  AdminModel? adminProfile;

  bool isLoading = true;
  String? error;
  bool _skipNextAuthStateFetch = false;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      error = null;
      if (user != null) {
        if (_skipNextAuthStateFetch) {
          _skipNextAuthStateFetch = false;
          return;
        }
        await _fetchUserData(user.uid);
      } else {
        _clearUser();
      }
    });
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      currentUser = null;
      studentProfile = null;
      facultyProfile = null;
      adminProfile = null;

      final userModel = await _authService.getUserData(uid);
      if (userModel != null) {
        currentUser = userModel;
        final profileUserId = userModel.uidFirebase.trim().isNotEmpty
            ? userModel.uidFirebase.trim()
            : userModel.id;
        var profileData = await _authService.getRoleProfile(
          userModel.role,
          profileUserId,
        );

        if (profileData == null &&
            userModel.role.trim().toLowerCase() == 'student') {
          await _authService.ensureUserRecord(
            uid: profileUserId,
            email: userModel.email,
            role: userModel.role,
          );
          profileData = await _authService.getRoleProfile(
            userModel.role,
            profileUserId,
          );
        }

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
      _skipNextAuthStateFetch = true;
      await _authService.login(email, password);
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        _skipNextAuthStateFetch = false;
        throw Exception('Signed in user not found');
      }

      final normalizedEmail = email.trim().toLowerCase();

      if (email.trim().toLowerCase() == 'user@iiitn.ac.in') {
        await _authService.purgeMistakenStudentAccount(uid: uid, email: email);
        await _authService.logout();
        throw Exception(
          'The test account user@iiitn.ac.in has been removed. Please use student1@iiitn.ac.in.',
        );
      }

      if (roleHint != null &&
          (currentUser == null || currentUser!.role.trim().isEmpty)) {
        await _authService.ensureUserRecord(
          uid: uid,
          email: email,
          role: roleHint,
        );
        await _fetchUserData(uid);
      }

      final normalizedRole = (currentUser?.role ?? roleHint ?? '')
          .trim()
          .toLowerCase();
      if (normalizedRole == 'student' || normalizedRole == 'faculty') {
        await _authService.cleanupLegacyDemoData(
          uid: uid,
          role: normalizedRole,
        );
        await _fetchUserData(uid);
      }

      if (normalizedEmail == 'student1@iiitn.ac.in') {
        await _authService.ensureDemoStudentSemesterFive(
          uid: uid,
          email: email,
        );
        await _fetchUserData(uid);
      }

      if (normalizedRole == 'faculty' &&
          normalizedEmail == 'faculty1@iiitn.ac.in') {
        await _authService.ensureFacultyDemoData(uid: uid, email: email);
        await _fetchUserData(uid);
      }

      await _fetchUserData(uid);
      return currentUser;
    } catch (e) {
      error = 'Invalid email or password';
      notifyListeners();
      rethrow;
    } finally {
      _skipNextAuthStateFetch = false;
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
