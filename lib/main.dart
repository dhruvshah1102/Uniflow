import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'data/seed/seed_data.dart';
import 'core/theme/app_theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  // Keep startup fast by default. Seed data is opt-in so the emulator
  // does not spend several seconds writing Firestore data on every launch.
  const shouldSeedDemoData = bool.fromEnvironment('SEED_DEMO_DATA', defaultValue: false);
  if (kDebugMode && shouldSeedDemoData) {
    try {
      await SeedData.populate();
    } catch (e) {
      debugPrint('Seed data failed: $e');
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack ?? StackTrace.current);
  };

  runZonedGuarded(() {
    runApp(const UniflowApp());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.instance.flushPendingNavigation());
    });
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class UniflowApp extends StatefulWidget {
  const UniflowApp({super.key});

  @override
  State<UniflowApp> createState() => _UniflowAppState();
}

class _UniflowAppState extends State<UniflowApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = AppRouter.createRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, themeProvider, child) {
          if (auth.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: const SplashLoadingScreen(),
            );
          }
          return MaterialApp.router(
            title: 'Uniflow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
