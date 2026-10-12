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
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (NotificationService.instance.isAdhanPlaying) {
      NotificationService.instance.stopAdhanPreview();
      return true;
    }
    return false;
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
                valueListenable: NotificationService.instance.isAdhanPlayingNotifier,
                builder: (context, isPlaying, _) {
                  if (!isPlaying) return const SizedBox.shrink();
                  return Card(
                    elevation: 12,
                    color: const Color(0xFF0C3B2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, color: AppTheme.goldAccent, size: 26),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.stop_circle_rounded, size: 20),
                            label: const Text(
                              'STOP',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            const BannerAdWidget(),
            NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                if (currentIndex != index) {
                  ref.read(currentTabProvider.notifier).state = index;
                  AdService.instance.registerNavigationAndMaybeShowInterstitial();
                }
              },
              indicatorColor: AppTheme.emeraldPrimary.withValues(alpha: 0.15),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppTheme.emeraldPrimary),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.access_time_outlined),
                  selectedIcon: Icon(Icons.access_time_filled, color: AppTheme.emeraldPrimary),
                  label: 'Namaz',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book, color: AppTheme.emeraldPrimary),
                  label: 'Quran',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore, color: AppTheme.emeraldPrimary),
                  label: 'Qibla',
                ),
                NavigationDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt, color: AppTheme.emeraldPrimary),
                  label: 'Tasks',
                ),
              ],
            ),
          ],
        ),
      );
  }
}
