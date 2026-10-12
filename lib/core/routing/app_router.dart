import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/ads/ad_service.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mynamaz_scheduler/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:mynamaz_scheduler/features/settings/presentation/screens/settings_screen.dart';
import 'package:mynamaz_scheduler/shared/widgets/main_shell_screen.dart';

class AdNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null && route.settings.name != '/splash') {
      AdService.instance.registerNavigationAndMaybeShowInterstitial();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      AdService.instance.registerNavigationAndMaybeShowInterstitial();
    }
  }
}

class AppRouter {
  static Future<GoRouter> createRouter() async {
    return GoRouter(
      initialLocation: '/splash',
      observers: [AdNavigationObserver()],
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
