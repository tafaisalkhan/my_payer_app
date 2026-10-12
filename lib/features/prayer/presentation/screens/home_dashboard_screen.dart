import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/core/utils/date_formatter.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:mynamaz_scheduler/features/quran/presentation/providers/quran_providers.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';
import 'package:mynamaz_scheduler/features/tasks/presentation/providers/task_providers.dart';
import 'package:mynamaz_scheduler/shared/widgets/main_shell_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  Timer? _countdownTimer;

  String _selectedPeriod = 'daily';

  DateTime? _screenInitTime;

  @override
  void initState() {
    super.initState();
    _screenInitTime = DateTime.now();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkAndAutoPlayAdhan();
        setState(() {});
      }
    });
  }

  Future<void> _checkAndAutoPlayAdhan() async {
    final timings = ref.read(prayerTimingsProvider);
    final now = DateTime.now();

    for (final p in timings) {
      final diffSeconds = now.difference(p.time).inSeconds;
      final key = 'adhan_played_${p.name}_${now.year}_${now.month}_${now.day}';

      final prefs = await SharedPreferences.getInstance();
      final bool alreadyPlayed = prefs.getBool(key) ?? false;

      // Do NOT play retroactively if prayer time passed before the app was started
      if (_screenInitTime != null && p.time.isBefore(_screenInitTime!)) {
        if (!alreadyPlayed) {
          await prefs.setBool(key, true);
        }
        continue;
      }

      // Play Adhan ONLY when prayer time arrives in real time (within 3 seconds of entry)
      if (diffSeconds >= 0 && diffSeconds <= 3 && !alreadyPlayed) {
        await prefs.setBool(key, true);
        final isAlreadyRinging = await NotificationService.instance.isAlarmRinging();
        if (!isAlreadyRinging) {
          await NotificationService.instance.playPrayerAdhan();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🕌 Prayer time for ${p.name} has entered! Allahu Akbar, Allahu Akbar!'),
              backgroundColor: AppTheme.emeraldPrimary,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationDataProvider);
    final prayerTimings = ref.watch(prayerTimingsProvider);
    final todayRecords = ref.watch(todayPrayerRecordsProvider);
    final quranSchedules = ref.watch(quranSchedulesProvider);
    final todayTasks = ref.watch(todayTasksProvider);

    final now = DateTime.now();
    final location = locationAsync.valueOrNull;

    PrayerTiming? nextPrayer = ref.watch(nextPrayerProvider);
    if (nextPrayer == null) {
      for (var p in prayerTimings) {
        if (p.isNext) {
          nextPrayer = p;
          break;
        }
      }
      nextPrayer ??= prayerTimings.isNotEmpty ? prayerTimings.first : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location != null ? '${location.city}, ${location.country}' : 'My Namaz Scheduler',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${DateFormatter.formatGregorian(now)} • ${DateFormatter.formatHijri(now)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(locationDataProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Next Prayer Hero Card
              if (nextPrayer != null) ...[
                _buildNextPrayerHeroCard(nextPrayer),
                const SizedBox(height: 20),
              ],

              // 2. Namaz Completion Progress (Daily, Weekly, Monthly, Yearly)
              _buildNamazProgressSection(),
              const SizedBox(height: 20),

              // 3. Five Daily Namaz Timings Schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Namaz Timings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NotificationService.instance.isAdhanPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return TextButton.icon(
                        icon: Icon(
                          isPlaying ? Icons.stop_circle : Icons.volume_up,
                          size: 18,
                          color: isPlaying ? Colors.redAccent : AppTheme.emeraldPrimary,
                        ),
                        label: Text(
                          isPlaying ? 'Stop Adhan' : 'Play Adhan',
                          style: TextStyle(
                            color: isPlaying ? Colors.redAccent : AppTheme.emeraldPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            NotificationService.instance.stopAdhanPreview();
                          } else {
                            NotificationService.instance.playAdhanPreview();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPrayerScheduleList(prayerTimings, todayRecords),
              const SizedBox(height: 20),

              // 4. Quran Recitation Reminder Card
              _buildQuranCard(quranSchedules),
              const SizedBox(height: 20),

              // 5. Today's Tasks Summary Card
              _buildTasksCard(todayTasks),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerHeroCard(PrayerTiming nextPrayer) {
    final now = DateTime.now();
    var prayerTime = nextPrayer.time;
    if (prayerTime.isBefore(now)) {
      prayerTime = prayerTime.add(const Duration(days: 1));
    }
    final remaining = prayerTime.difference(now);
    final displayRemaining = remaining.isNegative ? Duration.zero : remaining;
    final isTomorrow = prayerTime.day != now.day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/mosque_hero.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Color(0xCC064E3B),
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emeraldPrimary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  'NEXT PRAYER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(Icons.mosque, color: Colors.white70, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nextPrayer.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scheduled at ${DateFormatter.formatTime(prayerTime)}${isTomorrow ? " (Tomorrow)" : ""}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.goldLight, size: 20),
              const SizedBox(width: 8),
              Text(
                'Countdown: ${DateFormatter.formatDuration(displayRemaining)}',
                style: const TextStyle(
                  color: AppTheme.goldLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNamazProgressSection() {
    final statsAsync = ref.watch(namazProgressStatsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Namaz Progress',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedPeriod.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.emeraldPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodTab('daily', 'Daily (5)'),
                  const SizedBox(width: 8),
                  _buildPeriodTab('weekly', 'Weekly (35)'),
                  const SizedBox(width: 8),
                  _buildPeriodTab('monthly', 'Monthly (150)'),
                  const SizedBox(width: 8),
                  _buildPeriodTab('yearly', 'Yearly'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Progress unavailable: $err'),
              data: (stats) {
                final PeriodProgress period = switch (_selectedPeriod) {
                  'weekly' => stats.weekly,
                  'monthly' => stats.monthly,
                  'yearly' => stats.yearly,
                  _ => stats.daily,
                };

                final pct = period.percentage;
                final pctText = '${(pct * 100).toInt()}%';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${period.completed} / ${period.total} Namaz Completed',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.emeraldPrimary,
                          ),
                        ),
                        Text(
                          pctText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.goldAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: AppTheme.emeraldPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusBadge('On Time', period.onTimeCount, Colors.green),
                        _buildStatusBadge('Qada', period.qadaCount, Colors.orange),
                        _buildStatusBadge('Missed', period.missedCount, Colors.redAccent),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String key, String label) {
    final bool isSelected = _selectedPeriod == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.emeraldPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _selectedPeriod = key;
        });
      },
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerScheduleList(
    List<PrayerTiming> timings,
    Map<String, PrayerRecord> todayRecords,
  ) {
    if (timings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final now = DateTime.now();
    return Column(
      children: timings.map((t) {
        final record = todayRecords[t.name.toUpperCase()];
        final isDone = record?.status == PrayerStatus.onTime || record?.status == PrayerStatus.qada;
        final isNextToday = t.isNext && t.time.isAfter(now);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isNextToday ? AppTheme.emeraldPrimary.withValues(alpha: 0.08) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDone
                  ? Colors.green.shade100
                  : (isNextToday
                      ? AppTheme.emeraldPrimary
                      : Theme.of(context).colorScheme.surfaceContainerHighest),
              child: Icon(
                isDone ? Icons.check : Icons.access_time,
                size: 20,
                color: isDone ? Colors.green.shade800 : (isNextToday ? Colors.white : Colors.grey.shade700),
              ),
            ),
            title: Text(
              t.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isNextToday ? AppTheme.emeraldPrimary : null,
              ),
            ),
            subtitle: Text(
              record != null ? 'Status: ${record.status.label}${record.takbirEUla ? " (Takbir-e-Ula)" : ""}' : 'Pending',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              DateFormatter.formatTime(t.time),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onTap: () => ref.read(currentTabProvider.notifier).state = 1,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuranCard(List<dynamic> quranSchedules) {
    final active = quranSchedules.isNotEmpty ? quranSchedules.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, color: AppTheme.emeraldPrimary),
                    SizedBox(width: 8),
                    Text(
                      'Quran Recitation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(currentTabProvider.notifier).state = 2,
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (active != null) ...[
              Text(
                'Schedule: ${active.displayTitle}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Recitation Time: ${active.recitationTime} • Frequency: ${active.frequency}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else
              Text(
                'No active Quran recitation schedule. Tap Manage to schedule.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksCard(List<dynamic> tasks) {
    final pendingTasks = tasks.where((t) => t.status != TaskStatus.completed).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.task_alt, color: AppTheme.goldAccent),
                    SizedBox(width: 8),
                    Text(
                      'Today\'s Tasks',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(currentTabProvider.notifier).state = 4,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pendingTasks.isNotEmpty) ...[
              Text(
                '${pendingTasks.length} task(s) remaining for today',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Next: ${pendingTasks.first.title} (${pendingTasks.first.startTime})',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else
              Text(
                'No pending tasks for today.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
