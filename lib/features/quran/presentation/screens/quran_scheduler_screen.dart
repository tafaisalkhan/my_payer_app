import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/core/utils/prayer_time_helper.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_schedule.dart';
import 'package:mynamaz_scheduler/features/quran/presentation/providers/quran_providers.dart';

class QuranSchedulerScreen extends ConsumerWidget {
  const QuranSchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(quranSchedulesProvider);
    final history = ref.watch(quranHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Recitation Scheduler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Schedule',
            onPressed: () => _showAddScheduleDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Schedules Header Card
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Recitation Schedules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddScheduleDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (schedules.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.menu_book, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No Quran recitation schedules set.'),
                        const SizedBox(height: 4),
                        Text(
                          'Schedule daily, weekly, or monthly Surah or Part (Juz) recitation reminders with alarm.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: schedules.map((sch) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sch.displayTitle,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.emeraldPrimary, size: 20),
                                    tooltip: 'Edit Schedule',
                                    onPressed: () => _showAddScheduleDialog(context, ref, sch),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'Delete Schedule',
                                    onPressed: () {
                                      ref.read(quranSchedulesProvider.notifier).deleteSchedule(sch.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${DateFormat('EEE, MMM d, yyyy').format(sch.createdAt)} • Start: ${sch.recitationTime} (${sch.durationMinutes} mins) • Frequency: ${sch.frequency}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          if (sch.notes?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text('Notes: ${sch.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Recitation Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ref.read(quranHistoryProvider.notifier).markCompleted(
                                          scheduleId: sch.id,
                                          surahName: sch.surahName,
                                          startAyah: sch.startAyah,
                                          endAyah: sch.endAyah,
                                          status: 'SKIPPED',
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Skipped today\'s recitation.')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.skip_next, size: 16),
                                        SizedBox(width: 4),
                                        Text('Skip Today'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    ref.read(quranHistoryProvider.notifier).markCompleted(
                                          scheduleId: sch.id,
                                          surahName: sch.surahName,
                                          startAyah: sch.startAyah,
                                          endAyah: sch.endAyah,
                                          status: 'COMPLETED',
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Recitation marked as Completed!')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emeraldPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, size: 16),
                                        SizedBox(width: 4),
                                        Text('Mark Completed'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            const Text(
              'Recitation History Log',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Text('No completion history logged yet.', style: TextStyle(color: Colors.grey.shade600))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = history[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: item.status == 'COMPLETED' ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Icon(
                        item.status == 'COMPLETED' ? Icons.check : Icons.close,
                        color: item.status == 'COMPLETED' ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                    title: Text(
                      item.displayTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item.date} • ${item.status}'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context, WidgetRef ref, [QuranSchedule? scheduleToEdit]) {
    String normalizeFrequency(String? f) {
      if (f == null) return 'Every Day';
      if (f == 'DAILY') return 'Every Day';
      if (f == 'WEEKLY') return 'Weekly';
      if (f == 'MONTHLY') return 'Monthly';
      return f;
    }

    String selectionType = scheduleToEdit?.selectionType ?? 'SURAH'; // SURAH or PART
    String frequency = normalizeFrequency(scheduleToEdit?.frequency); // Every Day, Every 2 Days, Every 3 Days, Weekly, Monthly
    DateTime selectedDate = scheduleToEdit?.createdAt ?? DateTime.now();

    final parsedTime = PrayerTimeHelper.parseScheduleTimeString(scheduleToEdit?.recitationTime);
    String timeMode = parsedTime.isPrayerRelative ? 'PRAYER_RELATIVE' : 'CLOCK';
    String selectedPrayer = parsedTime.prayerName;
    String prayerRef = parsedTime.referencePoint;
    int offsetMinutes = parsedTime.offsetMinutes;
    final offsetController = TextEditingController(text: '$offsetMinutes');
    TimeOfDay selectedTime = parsedTime.clockTime;
    int durationMinutes = scheduleToEdit?.durationMinutes ?? 30;

    Map<String, dynamic> selectedSurah = scheduleToEdit != null && scheduleToEdit.selectionType == 'SURAH'
        ? AppConstants.surahs.firstWhere((s) => s['id'] == scheduleToEdit.surahId, orElse: () => AppConstants.surahs.first)
        : AppConstants.surahs.first;
    Map<String, dynamic> selectedPart = scheduleToEdit != null && scheduleToEdit.selectionType == 'PART'
        ? AppConstants.quranParts.firstWhere((p) => p['id'] == scheduleToEdit.juz, orElse: () => AppConstants.quranParts.first)
        : AppConstants.quranParts.first;
    int startAyah = scheduleToEdit != null && scheduleToEdit.startAyah > 0 ? scheduleToEdit.startAyah : 1;
    int endAyah = scheduleToEdit != null && scheduleToEdit.endAyah > 0 ? scheduleToEdit.endAyah : 20;
    final notesController = TextEditingController(text: scheduleToEdit?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final prayerTimings = ref.watch(prayerTimingsProvider);
            final prayerSettings = ref.watch(prayerSettingsProvider);
            final formattedTimeStr = PrayerTimeHelper.formatScheduleTimeString(
              isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
              clockTime: selectedTime,
              prayerName: selectedPrayer,
              referencePoint: prayerRef,
              offsetMinutes: offsetMinutes,
              prayerTimings: prayerTimings,
              settings: prayerSettings,
            );

            return AlertDialog(
              title: Text(scheduleToEdit == null ? 'Schedule Recitation' : 'Edit Quran Schedule'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selection Type Segmented Dropdown (By Surah vs By Part)
                      DropdownButtonFormField<String>(
                        value: selectionType,
                        decoration: const InputDecoration(
                          labelText: 'Recitation Target Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'SURAH', child: Text('By Surah')),
                          DropdownMenuItem(value: 'PART', child: Text('By Part (Juz / Para)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectionType = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      if (selectionType == 'SURAH') ...[
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedSurah,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Surah'),
                          items: AppConstants.surahs.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                '${s['id']}. ${s['name']} (${s['arabic']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedSurah = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: '$startAyah',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Start Ayah'),
                                onChanged: (val) => startAyah = int.tryParse(val) ?? 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: '$endAyah',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'End Ayah'),
                                onChanged: (val) => endAyah = int.tryParse(val) ?? 20,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // By Part (Juz) - NO Ayah fields required!
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedPart,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Part (Juz / Para)',
                            helperText: 'Entire Part will be scheduled (No Ayah range required)',
                          ),
                          items: AppConstants.quranParts.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                p['name'] as String,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedPart = val);
                          },
                        ),
                      ],

                      const SizedBox(height: 16),
                      // Scheduled Date Selector
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, color: AppTheme.emeraldPrimary),
                        title: const Text('Scheduled Date', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        trailing: OutlinedButton(
                          child: const Text('Change'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Automatic Timing Section
                      const Text(
                        'Recitation Timing (Automatic by Prayer Time or Clock)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),

                      // Quick Day-Part Period Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            avatar: const Text('🌅', style: TextStyle(fontSize: 13)),
                            label: const Text('Morning (Fajr)', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'PRAYER_RELATIVE' && selectedPrayer == 'Fajr',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'PRAYER_RELATIVE';
                                selectedPrayer = 'Fajr';
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Text('☀️', style: TextStyle(fontSize: 13)),
                            label: const Text('Noon (Dhuhr)', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'PRAYER_RELATIVE' && selectedPrayer == 'Dhuhr',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'PRAYER_RELATIVE';
                                selectedPrayer = 'Dhuhr';
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Text('🌤️', style: TextStyle(fontSize: 13)),
                            label: const Text('Afternoon (Asr)', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'PRAYER_RELATIVE' && selectedPrayer == 'Asr',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'PRAYER_RELATIVE';
                                selectedPrayer = 'Asr';
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Text('🌇', style: TextStyle(fontSize: 13)),
                            label: const Text('Evening (Maghrib)', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'PRAYER_RELATIVE' && selectedPrayer == 'Maghrib',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'PRAYER_RELATIVE';
                                selectedPrayer = 'Maghrib';
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Text('🌙', style: TextStyle(fontSize: 13)),
                            label: const Text('Night (Isha)', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'PRAYER_RELATIVE' && selectedPrayer == 'Isha',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'PRAYER_RELATIVE';
                                selectedPrayer = 'Isha';
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Text('⏰', style: TextStyle(fontSize: 13)),
                            label: const Text('Exact Clock Time', style: TextStyle(fontSize: 12)),
                            selected: timeMode == 'CLOCK',
                            onSelected: (_) {
                              setState(() {
                                timeMode = 'CLOCK';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (timeMode == 'PRAYER_RELATIVE') ...[
                        // Single full-width Prayer selection dropdown with Day Periods
                        DropdownButtonFormField<String>(
                          value: selectedPrayer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Auto-Linked Prayer Time',
                            prefixIcon: Icon(Icons.mosque_outlined),
                          ),
                          items: PrayerTimeHelper.prayerPeriods
                              .map((p) => DropdownMenuItem(value: p.prayer, child: Text('${p.emoji} ${p.label}')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedPrayer = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: offsetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minutes After Prayer',
                            suffixText: 'mins',
                            prefixIcon: Icon(Icons.more_time),
                            helperText: 'Delay after prayer (e.g. 15, 30, 45, 60 mins)',
                          ),
                          onChanged: (val) {
                            final num = int.tryParse(val);
                            if (num != null && num >= 0) {
                              setState(() => offsetMinutes = num);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [15, 30, 45, 60, 75, 90, 120, 150].map((m) {
                            final isSel = offsetMinutes == m;
                            return ChoiceChip(
                              label: Text('+$m mins', style: const TextStyle(fontSize: 11)),
                              selected: isSel,
                              onSelected: (_) {
                                setState(() {
                                  offsetMinutes = m;
                                  offsetController.text = '$m';
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        // Fixed Clock Time Picker
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time_outlined, color: AppTheme.emeraldPrimary),
                          title: const Text('Start Time', style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          trailing: OutlinedButton(
                            child: const Text('Change'),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emeraldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.alarm_on, color: AppTheme.emeraldPrimary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Recitation Alarm: $formattedTimeStr',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emeraldPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (timeMode == 'PRAYER_RELATIVE') ...[
                              const SizedBox(height: 4),
                              Text(
                                '⚡ Automatically adjusts every day to ${PrayerTimeHelper.getPeriodInfo(selectedPrayer).label}!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Duration Selector
                      Builder(builder: (context) {
                        final availableDurations = {15, 30, 45, 60, 90, 120, durationMinutes}.toList()..sort();
                        return DropdownButtonFormField<int>(
                          value: durationMinutes,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Recitation Duration',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          items: availableDurations.map((d) {
                            final label = d >= 60
                                ? (d % 60 == 0 ? '${d ~/ 60} Hour${d >= 120 ? 's' : ''}' : '${d ~/ 60} hr ${d % 60} min')
                                : '$d Minutes';
                            return DropdownMenuItem(value: d, child: Text(label));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => durationMinutes = val);
                          },
                        );
                      }),
                      const SizedBox(height: 12),

                      // Frequency Dropdown
                      DropdownButtonFormField<String>(
                        value: frequency,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.repeat_outlined),
                        ),
                        items: ['Every Day', 'Every 2 Days', 'Every 3 Days', 'Weekly', 'Monthly']
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => frequency = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final bool isPart = selectionType == 'PART';

                    final calculatedTarget = PrayerTimeHelper.calculateTargetTime(
                      isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
                      clockTime: selectedTime,
                      prayerName: selectedPrayer,
                      referencePoint: prayerRef,
                      offsetMinutes: offsetMinutes,
                      prayerTimings: prayerTimings,
                      settings: prayerSettings,
                    );

                    var targetTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      calculatedTarget.hour,
                      calculatedTarget.minute,
                    );

                    // If scheduled time has already passed today, advance to tomorrow so alarm always fires
                    if (targetTime.isBefore(DateTime.now())) {
                      targetTime = targetTime.add(const Duration(days: 1));
                    }

                    final savedTimeString = PrayerTimeHelper.formatScheduleTimeString(
                      isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
                      clockTime: selectedTime,
                      prayerName: selectedPrayer,
                      referencePoint: prayerRef,
                      offsetMinutes: offsetMinutes,
                      prayerTimings: prayerTimings,
                      settings: prayerSettings,
                    );

                    final sch = QuranSchedule(
                      id: scheduleToEdit?.id ?? '${DateTime.now().millisecondsSinceEpoch}',
                      frequency: frequency,
                      recitationTime: savedTimeString,
                      durationMinutes: durationMinutes,
                      surahId: isPart ? 0 : (selectedSurah['id'] as int),
                      surahName: isPart ? (selectedPart['name'] as String) : (selectedSurah['name'] as String),
                      startAyah: isPart ? 0 : startAyah,
                      endAyah: isPart ? 0 : endAyah,
                      juz: isPart ? (selectedPart['id'] as int) : null,
                      selectionType: selectionType,
                      notes: notesController.text,
                      createdAt: selectedDate,
                    );

                    if (scheduleToEdit == null) {
                      ref.read(quranSchedulesProvider.notifier).addSchedule(sch);
                    } else {
                      ref.read(quranSchedulesProvider.notifier).updateSchedule(sch);
                    }

                    // Schedule Clock Alarm Notification for scheduled recitation time
                    if (targetTime.isAfter(DateTime.now())) {
                      await NotificationService.instance.scheduleNotification(
                        id: targetTime.millisecondsSinceEpoch ~/ 1000,
                        title: '📖 Quran Recitation Time: ${sch.displayTitle}',
                        body: 'It is time for your $durationMinutes-minute scheduled Quran recitation ($savedTimeString).',
                        scheduledDate: targetTime,
                        channelId: AppConstants.quranChannelId,
                        channelName: AppConstants.quranChannelName,
                      );
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(scheduleToEdit == null
                              ? 'Schedule saved: ${sch.displayTitle}'
                              : 'Schedule updated: ${sch.displayTitle}'),
                        ),
                      );
                    }
                  },
                  child: Text(scheduleToEdit == null ? 'Save & Schedule Alarm' : 'Update Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
