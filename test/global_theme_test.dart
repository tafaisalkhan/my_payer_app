import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/features/settings/presentation/screens/settings_screen.dart';
import 'package:mynamaz_scheduler/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Changing theme updates the entire routed app', (tester) async {
    SharedPreferences.setMockInitialValues({'pref_theme_mode': 'light'});
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('Theme probe'))),
    ]);

    await tester.pumpWidget(ProviderScope(child: MyNamazSchedulerApp(router: router)));
    await tester.pumpAndSettle();
    final element = tester.element(find.text('Theme probe'));
    expect(Theme.of(element).brightness, Brightness.light);

    final container = ProviderScope.containerOf(element);
    await container.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Theme probe'))).brightness,
        Brightness.dark);

    router.dispose();
  });
}
