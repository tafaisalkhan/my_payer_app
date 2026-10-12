import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/core/utils/date_formatter.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';

class NamazTrackingScreen extends ConsumerWidget {
  const NamazTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRecords = ref.watch(todayPrayerRecordsProvider);
    final timings = ref.watch(prayerTimingsProvider);

    final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    int onTimeCount = 0;
    int qadaCount = 0;
    int takbirCount = 0;

    for (final r in todayRecords.values) {
      if (r.status == PrayerStatus.onTime) onTimeCount++;
      if (r.status == PrayerStatus.qada) qadaCount++;
      if (r.takbirEUla) takbirCount++;
    }

    final totalCompleted = onTimeCount + qadaCount;
    final onTimePct = totalCompleted > 0 ? (onTimeCount / totalCompleted * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Namaz Completion Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Statistics Summary Cards
            _buildStatsOverview(totalCompleted, onTimePct, qadaCount, takbirCount),
            const SizedBox(height: 20),

            // 2. Today's Prayer Tracking Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Prayer Records',
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
            const SizedBox(height: 12),

            Column(
              children: prayers.map((pName) {
                final pKey = pName.toUpperCase();
                final record = todayRecords[pKey];
                final currentStatus = record?.status ?? PrayerStatus.pending;
                final isTakbir = record?.takbirEUla ?? false;

                final timing = timings.firstWhere(
                  (t) => t.name.toLowerCase() == pName.toLowerCase(),
                  orElse: () {
                    final pType = PrayerType.values.firstWhere(
                      (e) => e.name.toLowerCase() == pName.toLowerCase(),
                      orElse: () => PrayerType.fajr,
                    );
                    return PrayerTiming(type: pType, name: pName, time: DateTime.now());
                  },
                );

                final bool isTimeStarted = DateTime.now().isAfter(timing.time) || DateTime.now().isAtSameMomentAs(timing.time);
                final String formattedTime = DateFormatter.formatTime(timing.time);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '($formattedTime)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isTimeStarted ? Colors.grey.shade700 : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(currentStatus).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                currentStatus.label,
                                style: TextStyle(
                                  color: _getStatusColor(currentStatus),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isTimeStarted) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.lock_clock, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Time not reached yet — unlocks at $formattedTime',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Status Selection Chips
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              avatar: !isTimeStarted ? Icon(Icons.lock, size: 14, color: Colors.grey.shade600) : null,
                              label: Text(isTimeStarted ? 'On Time' : 'Locked'),
                              selected: currentStatus == PrayerStatus.onTime,
                              selectedColor: Colors.green.shade100,
                              onSelected: (_) {
                                if (!isTimeStarted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$pName prayer time ($formattedTime) has not started yet! You cannot mark it as completed early.'),
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                  return;
                                }
                                ref.read(todayPrayerRecordsProvider.notifier).updateRecord(
                                      prayerName: pName,
                                      status: PrayerStatus.onTime,
                                      takbirEUla: isTakbir,
                                    );
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Qada'),
                              selected: currentStatus == PrayerStatus.qada,
                              selectedColor: Colors.orange.shade100,
                              onSelected: (_) {
                                if (!isTimeStarted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$pName prayer time ($formattedTime) has not started yet!'),
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                  return;
                                }
                                ref.read(todayPrayerRecordsProvider.notifier).updateRecord(
                                      prayerName: pName,
                                      status: PrayerStatus.qada,
                                      takbirEUla: isTakbir,
                                    );
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Not Prayed'),
                              selected: currentStatus == PrayerStatus.notPrayed,
                              selectedColor: Colors.red.shade100,
                              onSelected: (_) {
                                ref.read(todayPrayerRecordsProvider.notifier).updateRecord(
                                      prayerName: pName,
                                      status: PrayerStatus.notPrayed,
                                      takbirEUla: false,
                                    );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Divider(),

                        // Independent Takbir-e-Ula Checkbox
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Joined with Takbir-e-Ula',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Joined congregational prayer from initial takbir',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: isTakbir,
                          activeColor: AppTheme.emeraldPrimary,
                          onChanged: !isTimeStarted
                              ? null
                              : (val) {
                                  ref.read(todayPrayerRecordsProvider.notifier).updateRecord(
                                        prayerName: pName,
                                        status: currentStatus,
                                        takbirEUla: val ?? false,
                                      );
                                },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(int total, String onTimePct, int qada, int takbir) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.emeraldPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emeraldPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Completed', '$total/5', Colors.green),
          _buildStatColumn('On Time', '$onTimePct%', AppTheme.emeraldPrimary),
          _buildStatColumn('Qada', '$qada', Colors.orange.shade800),
          _buildStatColumn('Takbir-e-Ula', '$takbir', AppTheme.goldAccent),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Color _getStatusColor(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.onTime:
        return Colors.green.shade700;
      case PrayerStatus.qada:
        return Colors.orange.shade800;
      case PrayerStatus.notPrayed:
        return Colors.red.shade700;
      case PrayerStatus.pending:
        return Colors.grey.shade600;
    }
  }
}
