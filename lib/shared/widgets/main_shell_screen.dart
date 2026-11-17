import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/screens/home_dashboard_screen.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/screens/namaz_tracking_screen.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/prayer_check_in_service.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/prayer_time_change_service.dart';
import 'package:mynamaz_scheduler/features/qibla/presentation/screens/qibla_compass_screen.dart';
import 'package:mynamaz_scheduler/features/quran/presentation/screens/quran_scheduler_screen.dart';
import 'package:mynamaz_scheduler/features/tasks/presentation/screens/task_scheduler_screen.dart';
import 'package:mynamaz_scheduler/core/ads/ad_service.dart';
import 'package:mynamaz_scheduler/core/services/support_service.dart';
import 'package:mynamaz_scheduler/shared/widgets/banner_ad_widget.dart';

final currentTabProvider = StateProvider<int>((ref) => 0);

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  Timer? _alarmStatusTimer;
  bool _checkInOpen = false;
  bool _wasBackgrounded = false;
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
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _refreshAlarmStatus();
    _alarmStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshAlarmStatus(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AdService.instance.onDashboardVisible();
        SupportService.instance.checkForAppUpdate(context);
        _openPendingRecords();
      }
    });
  }

  Future<void> _openPendingRecords() async {
    if (_checkInOpen) return;
    _checkInOpen = true;
    try {
      await ref.read(todayPrayerRecordsProvider.notifier).loadTodayRecords();
      await ref.read(prayerSettingsProvider.notifier).ready;
      final location = await ref.read(locationDataProvider.future);
      if (!mounted) return;
      await PrayerTimeChangeService.check(ref.read(prayerTimingsProvider));
      final pending = await PrayerCheckInService.load(
        repository: ref.read(prayerRepositoryProvider),
        latitude: location.latitude,
        longitude: location.longitude,
        settings: ref.read(prayerSettingsProvider),
      );
      if (!mounted) return;
      if (pending.isEmpty) return;
      await context.push<void>('/prayer-records');
    } catch (error) {
      debugPrint('Could not open prayer check-in: $error');
    } finally {
      _checkInOpen = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _openPendingRecords();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                if (index == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      AdService.instance.showNoAdsPopupIfNeeded(context);
                    }
                  });
                }
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
