import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/routing/app_router.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/settings/presentation/screens/settings_screen.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global FlutterError: ${details.exceptionAsString()}');
  };

  // Global platform/asynchronous error handling (prevents OS termination)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Global PlatformDispatcher unhandled error caught: $error');
    return true; // Return true to mark error as handled and avoid crashing process
  };

  // Graceful Widget Rendering Error fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 36, color: AppTheme.emeraldPrimary),
              const SizedBox(height: 8),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Safe initialize notifications & timezone
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Main: NotificationService init error: $e');
  }

  // Create router instance with onboarding check (with fallback)
  GoRouter router;
  try {
    router = await AppRouter.createRouter();
  } catch (e) {
    debugPrint('Main: Router creation error: $e');
    router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
      ],
    );
  }

  runApp(
    ProviderScope(
      child: MyNamazSchedulerApp(router: router),
    ),
  );
}

class MyNamazSchedulerApp extends ConsumerWidget {
  final GoRouter router;

  const MyNamazSchedulerApp({
    super.key,
    required this.router,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'My Namaz Scheduler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
