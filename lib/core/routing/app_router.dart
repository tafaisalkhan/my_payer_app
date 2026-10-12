import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mynamaz_scheduler/features/settings/presentation/screens/settings_screen.dart';
import 'package:mynamaz_scheduler/shared/widgets/main_shell_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRouter {
  static Future<GoRouter> createRouter() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    return GoRouter(
      initialLocation: onboardingCompleted ? '/' : '/onboarding',
      routes: [
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
