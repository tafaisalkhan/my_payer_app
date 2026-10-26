import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/screens/home_dashboard_screen.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/screens/namaz_tracking_screen.dart';
import 'package:mynamaz_scheduler/features/qibla/presentation/screens/qibla_compass_screen.dart';
import 'package:mynamaz_scheduler/features/quran/presentation/screens/quran_scheduler_screen.dart';
import 'package:mynamaz_scheduler/features/tasks/presentation/screens/task_scheduler_screen.dart';
import 'package:mynamaz_scheduler/core/ads/ad_service.dart';
import 'package:mynamaz_scheduler/shared/widgets/banner_ad_widget.dart';

final currentTabProvider = StateProvider<int>((ref) => 0);

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  Timer? _alarmStatusTimer;
  bool _nativeAlarmRinging = false;
  final List<Widget> _screens = const [
    HomeDashboardScreen(),
    NamazTrackingScreen(),
    QuranSchedulerScreen(),
    QiblaCompassScreen(),
    TaskSchedulerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _refreshAlarmStatus();
    _alarmStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshAlarmStatus(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AdService.instance.onDashboardVisible();
    });
  }

  @override
  void dispose() {
    _alarmStatusTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        (NotificationService.instance.isAdhanPlaying || _nativeAlarmRinging)) {
      NotificationService.instance.stopAdhanPreview();
      return true;
    }
    return false;
  }

  Future<void> _refreshAlarmStatus() async {
    final ringing = await NotificationService.instance.isAlarmRinging();
    if (mounted && ringing != _nativeAlarmRinging) {
      setState(() => _nativeAlarmRinging = ringing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ValueListenableBuilder<bool>(
              valueListenable:
                  NotificationService.instance.isAdhanPlayingNotifier,
              builder: (context, isPlaying, _) {
                  if (!isPlaying && !_nativeAlarmRinging) {
                    return const SizedBox.shrink();
                  }
                return Card(
                  elevation: 12,
                  color: const Color(0xFF0C3B2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                        color: AppTheme.goldAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_rounded,
                            color: AppTheme.goldAccent, size: 26),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🕌 Adhan Playing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap STOP button to silence',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.stop_circle_rounded, size: 20),
                          label: const Text(
                            'STOP',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            NotificationService.instance.stopAdhanPreview();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AdService.instance.isInitializedNotifier,
            builder: (context, isInitialized, _) => isInitialized
                ? const BannerAdWidget()
                : const SizedBox.shrink(),
          ),
          NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              if (currentIndex != index) {
                ref.read(currentTabProvider.notifier).state = index;
                AdService.instance.registerNavigationAndMaybeShowInterstitial();
              }
            },
            indicatorColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Namaz',
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Quran',
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Qibla',
              ),
              NavigationDestination(
                icon: const Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Tasks',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
