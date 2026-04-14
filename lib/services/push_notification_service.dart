import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../firebase_options.dart';
import '../models/user_model.dart';
import '../core/router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _currentUserId;
  String? _currentRole;
  String? _currentToken;
  Map<String, dynamic>? _pendingNavigation;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        try {
          final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
          _pendingNavigation = payload;
          unawaited(flushPendingNavigation());
        } catch (_) {}
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'uniflow_campus_alerts',
      'Campus Alerts',
      description: 'Assignments, announcements and registration updates',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  Future<bool> bindUser(UserModel user) async {
    _currentUserId = user.id;
    _currentRole = user.role;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _persistToken(user, token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      await _persistToken(user, newToken);
    });

    await flushPendingNavigation();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> clearBinding() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final userId = _currentUserId;
    final token = _currentToken;
    if (userId != null && token != null && token.isNotEmpty) {
      final userRef = _db.collection('users').doc(userId);
      await userRef.collection('device_tokens').doc(token).delete().catchError((_) {});
      final snap = await userRef.get();
      final data = snap.data();
      if (data != null && data['fcm_token'] == token) {
        await userRef.set(
          {
            'fcm_token': '',
            'fcm_token_updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    _currentUserId = null;
    _currentRole = null;
    _currentToken = null;
  }

  Future<void> flushPendingNavigation() async {
    final payload = _pendingNavigation;
    if (payload == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final route = _routeForPayload(payload);
    if (route == null || route.isEmpty) return;

    _pendingNavigation = null;
    GoRouter.of(context).go(route);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final payload = _payloadFromMessage(message);
    final title = payload['title']?.toString() ?? message.notification?.title ?? 'Uniflow';
    final body = payload['body']?.toString() ?? message.notification?.body ?? '';
    _showLocalNotification(title: title, body: body, payload: payload);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = _payloadFromMessage(message);
    _pendingNavigation = payload;
    unawaited(flushPendingNavigation());
  }

  Future<void> _persistToken(UserModel user, String token) async {
    _currentToken = token;
    final userRef = _db.collection('users').doc(user.id);
    await userRef.set(
      {
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await userRef.collection('device_tokens').doc(token).set(
      {
        'token': token,
        'platform': defaultTargetPlatform.name,
        'role': user.role,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'uniflow_campus_alerts',
      'Campus Alerts',
      channelDescription: 'Assignments, announcements and registration updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: jsonEncode(payload),
    );
  }

  Map<String, dynamic> _payloadFromMessage(RemoteMessage message) {
    final data = <String, dynamic>{...message.data};
    final notification = message.notification;
    if (notification != null) {
      data.putIfAbsent('title', () => notification.title ?? '');
      data.putIfAbsent('body', () => notification.body ?? '');
    }
    return data;
  }

  String? _routeForPayload(Map<String, dynamic> data) {
    final explicitRoute = data['route']?.toString().trim();
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final role = (_currentRole ?? data['targetRole']?.toString() ?? '').trim().toLowerCase();
    final type = (data['type']?.toString() ?? '').trim().toLowerCase();

    if (role == 'faculty') {
      if (type == 'assignment') return '/faculty/dashboard?tab=assignments';
      if (type == 'announcement' || type == 'notice' || type == 'registration') {
        return '/faculty/dashboard?tab=notifications';
      }
      return '/faculty/dashboard';
    }

    if (role == 'admin') {
      if (type == 'registration') return '/admin/dashboard';
      return '/admin/dashboard';
    }

    if (role == 'student' || role.isEmpty) {
      final courseId = data['courseId']?.toString().trim();
      final sourceId = data['sourceId']?.toString().trim();
      final assignmentId = data['assignmentId']?.toString().trim();
      final quizId = data['quizId']?.toString().trim();
      final sourceCollection = data['sourceCollection']?.toString().trim().toLowerCase();
      if (courseId != null && courseId.isNotEmpty) {
        final resolvedAssignmentId = (assignmentId != null && assignmentId.isNotEmpty) ? assignmentId : sourceId;
        final resolvedQuizId = (quizId != null && quizId.isNotEmpty) ? quizId : sourceId;
        if ((sourceCollection == 'assignments' || type == 'assignment') &&
            resolvedAssignmentId != null &&
            resolvedAssignmentId.isNotEmpty) {
          return '/student/course/$courseId?tab=assignments&assignmentId=$resolvedAssignmentId';
        }
        if ((sourceCollection == 'quizzes' || type == 'quiz') &&
            resolvedQuizId != null &&
            resolvedQuizId.isNotEmpty) {
          return '/student/course/$courseId?tab=quizzes&quizId=$resolvedQuizId';
        }
      }
      if (type == 'assignment') return '/student/dashboard?tab=tasks';
      if (type == 'quiz') return '/student/dashboard?tab=tasks';
      if (type == 'registration') return '/student/dashboard?tab=notifications';
      return '/student/dashboard?tab=notifications';
    }

    return null;
  }
}
