import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/core/utils/date_formatter.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_adhan_provider.dart';
import 'package:mynamaz_scheduler/shared/widgets/banner_ad_widget.dart';

class NamazTrackingScreen extends ConsumerWidget {
  const NamazTrackingScreen({super.key});

  void _showCheckIn(BuildContext context, String prayer) =>
      context.push('/prayer-records?view=day&prayer=$prayer');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRecords = ref.watch(todayPrayerRecordsProvider);
    final timings = ref.watch(prayerTimingsProvider);
    final voluntaryTimings = ref.watch(voluntaryPrayerTimingsProvider);
    final adhanLengths = ref.watch(prayerAdhanProvider);
    final adhanLeadMinutes = ref.watch(prayerAdhanLeadProvider);

    final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    int onTimeCount = 0;
    int qadaCount = 0;
    int takbirCount = 0;
    int mosqueCount = 0;
    int homeCount = 0;
    int jamaatRakats = 0;

    for (final r in todayRecords.values) {
      if (r.status == PrayerStatus.onTime) onTimeCount++;
      if (r.status == PrayerStatus.qada) qadaCount++;
      if (r.takbirEUla) takbirCount++;
      if (r.place == PrayerPlace.mosque) mosqueCount++;
      if (r.place == PrayerPlace.home) homeCount++;
      jamaatRakats += r.joinedRakats ?? 0;
    }

    final totalCompleted = onTimeCount + qadaCount;
    final onTimePct = totalCompleted > 0
        ? (onTimeCount / totalCompleted * 100).toStringAsFixed(0)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Namaz Completion Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Prayer records and calendar',
            onPressed: () => context.push('/prayer-records'),
          ),
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
            _buildStatsOverview(totalCompleted, onTimePct, qadaCount,
                takbirCount, mosqueCount, homeCount, jamaatRakats),
            const SizedBox(height: 20),
            _buildHistoryChart(context, ref),
            const SizedBox(height: 20),

            if (voluntaryTimings.isNotEmpty) ...[
              const Text('Optional Prayer Times',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Suggested times • No adhan',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              for (final timing in voluntaryTimings)
                Card(
                  child: ListTile(
                    title: Text(timing.name),
                    subtitle: Text(timing.description),
                    trailing: Text(DateFormatter.formatTime(timing.time)),
                  ),
                ),
              const SizedBox(height: 20),
            ],

            // 2. Today's Prayer Tracking Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Prayer Records',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable:
                      NotificationService.instance.isAdhanPlayingNotifier,
                  builder: (context, isPlaying, _) {
                    return TextButton.icon(
                      icon: Icon(
                        isPlaying ? Icons.stop_circle : Icons.volume_up,
                        size: 18,
                        color: isPlaying
                            ? Colors.redAccent
                            : AppTheme.emeraldPrimary,
                      ),
                      label: Text(
                        isPlaying ? 'Stop Adhan' : 'Play Adhan',
                        style: TextStyle(
                          color: isPlaying
                              ? Colors.redAccent
                              : AppTheme.emeraldPrimary,
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

                final timing = timings.firstWhere(
                  (t) => t.name.toLowerCase() == pName.toLowerCase(),
                  orElse: () {
                    final pType = PrayerType.values.firstWhere(
                      (e) => e.name.toLowerCase() == pName.toLowerCase(),
                      orElse: () => PrayerType.fajr,
                    );
                    return PrayerTiming(
                        type: pType, name: pName, time: DateTime.now());
                  },
                );

                final bool isTimeStarted =
                    DateTime.now().isAfter(timing.time) ||
                        DateTime.now().isAtSameMomentAs(timing.time);
                final String formattedTime =
                    DateFormatter.formatTime(timing.time);

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
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '($formattedTime)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isTimeStarted
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(currentStatus)
                                    .withValues(alpha: 0.15),
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
                              Icon(Icons.lock_clock,
                                  size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Time not reached yet — unlocks at $formattedTime',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500),
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
                              avatar: !isTimeStarted
                                  ? Icon(Icons.lock,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)
                                  : null,
                              label: Text(isTimeStarted ? 'On Time' : 'Locked'),
                              selected: currentStatus == PrayerStatus.onTime,
                              selectedColor: Colors.green.shade100,
                              checkmarkColor: Colors.green.shade900,
                              labelStyle: TextStyle(
                                color: currentStatus == PrayerStatus.onTime
                                    ? Colors.green.shade900
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              onSelected: (_) {
                                if (!isTimeStarted) {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '$pName prayer time ($formattedTime) has not started yet! You cannot mark it as completed early.'),
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                  return;
                                }
                                _showCheckIn(context, pName);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Qada'),
                              selected: currentStatus == PrayerStatus.qada,
                              selectedColor: Colors.orange.shade100,
                              checkmarkColor: Colors.orange.shade900,
                              labelStyle: TextStyle(
                                color: currentStatus == PrayerStatus.qada
                                    ? Colors.orange.shade900
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              onSelected: (_) {
                                if (!isTimeStarted) {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '$pName prayer time ($formattedTime) has not started yet!'),
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                  return;
                                }
                                _showCheckIn(context, pName);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Not Prayed'),
                              selected: currentStatus == PrayerStatus.notPrayed,
                              selectedColor: Colors.red.shade100,
                              checkmarkColor: Colors.red.shade900,
                              labelStyle: TextStyle(
                                color: currentStatus == PrayerStatus.notPrayed
                                    ? Colors.red.shade900
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              onSelected: (_) {
                                if (!isTimeStarted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '$pName prayer time ($formattedTime) has not started yet!')),
                                  );
                                  return;
                                }
                                _showCheckIn(context, pName);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Divider(),

                        Row(
                          children: [
                            const Expanded(child: Text('Adhan sound')),
                            DropdownButton<AdhanLength>(
                              value: adhanLengths[pName] ?? AdhanLength.short,
                              items: const [
                                DropdownMenuItem(
                                  value: AdhanLength.short,
                                  child: Text('Short Adhan'),
                                ),
                                DropdownMenuItem(
                                  value: AdhanLength.long,
                                  child: Text('Long Adhan (repeat)'),
                                ),
                              ],
                              onChanged: (length) {
                                if (length != null) {
                                  ref
                                      .read(prayerAdhanProvider.notifier)
                                      .setLength(pName, length);
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Expanded(child: Text('Play Adhan before')),
                            DropdownButton<int>(
                              value: adhanLeadMinutes[pName] ?? 0,
                              items: [
                                for (var minutes = 0; minutes <= 120; minutes++)
                                  DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes min'),
                                  ),
                              ],
                              onChanged: (minutes) {
                                if (minutes != null) {
                                  ref
                                      .read(prayerAdhanLeadProvider.notifier)
                                      .setMinutes(pName, minutes);
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(),

                        if (currentStatus != PrayerStatus.pending)
                          TextButton.icon(
                            onPressed: () => _showCheckIn(context, pName),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit check-in'),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // In-Screen Banner Ad
            const BannerAdWidget(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(int total, String onTimePct, int qada, int takbir,
      int mosque, int home, int jamaatRakats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.emeraldPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.emeraldPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Completed', '$total/5', Colors.green),
              _buildStatColumn(
                  'On Time', '$onTimePct%', AppTheme.emeraldPrimary),
              _buildStatColumn('Qada', '$qada', Colors.orange.shade800),
              _buildStatColumn('Takbir-e-Ula', '$takbir', AppTheme.goldAccent),
            ],
          ),
          const Divider(height: 24),
          Text('Mosque: $mosque  •  Home: $home  •  '
              'Rakats joined with Jamaat: $jamaatRakats'),
        ],
      ),
    );
  }

  Widget _buildHistoryChart(BuildContext context, WidgetRef ref) {
    final selectedDays = ref.watch(prayerHistoryPeriodProvider);
    final history = ref.watch(prayerHistoryProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prayer history',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('On Time, Mosque, and Takbir-e-Ula by prayer',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final option in const [7, 30, 0])
                ChoiceChip(
                  label: Text(option == 0 ? 'All time' : '$option days'),
                  selected: selectedDays == option,
                  selectedColor: AppTheme.emeraldPrimary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selectedDays == option ? Colors.white : onSurface,
                  ),
                  onSelected: (_) => ref
                      .read(prayerHistoryPeriodProvider.notifier)
                      .state = option,
                ),
            ]),
            const SizedBox(height: 12),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Prayer history is unavailable.'),
              data: (counts) {
                final highest = counts.values.fold<int>(
                    0, (max, value) => value.onTime > max ? value.onTime : max);
                final scale = highest == 0 ? 1 : highest;
                final leaders = counts.entries
                    .where((entry) => entry.value.onTime == highest)
                    .map((entry) => entry.key)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in counts.entries) ...[
                      Text(entry.key,
                          style: TextStyle(
                            color: onSurface,
                            fontWeight:
                                entry.value.onTime == highest && highest > 0
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                          )),
                      const SizedBox(height: 4),
                      _historyBar(context, 'On Time', entry.value.onTime, scale,
                          Colors.green.shade600),
                      _historyBar(context, 'Mosque', entry.value.mosqueOnTime,
                          scale, Colors.blue.shade500),
                      _historyBar(context, 'Takbir', entry.value.takbirOnTime,
                          scale, Colors.amber.shade700),
                      const SizedBox(height: 10),
                    ],
                    if (highest > 0)
                      Text('Most On Time: ${leaders.join(', ')} ($highest)',
                          style: TextStyle(
                              color: onSurface, fontWeight: FontWeight.w600)),
                    if (highest == 0)
                      const Text('No On Time prayers in this period yet.'),
                    const SizedBox(height: 6),
                    Text('Mosque and Takbir count only On Time prayers.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyBar(
      BuildContext context, String label, int count, int scale, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(
          width: 68,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          return Container(
            height: 14,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Container(
              width: constraints.maxWidth * count / scale,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        })),
        SizedBox(
          width: 35,
          child: Text('$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildStatColumn(String title, String val, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
