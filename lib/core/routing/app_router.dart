import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:mynamaz_scheduler/features/settings/presentation/screens/settings_screen.dart';
import 'package:mynamaz_scheduler/shared/widgets/main_shell_screen.dart';

class AppRouter {
  static Future<GoRouter> createRouter() async {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const MainShellScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
