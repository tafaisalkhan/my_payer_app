import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/core/utils/prayer_time_helper.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';
import 'package:mynamaz_scheduler/features/tasks/presentation/providers/task_providers.dart';

class TaskSchedulerScreen extends ConsumerStatefulWidget {
  const TaskSchedulerScreen({super.key});

  @override
  ConsumerState<TaskSchedulerScreen> createState() => _TaskSchedulerScreenState();
}

class _TaskSchedulerScreenState extends ConsumerState<TaskSchedulerScreen> {
  Timer? _sessionTimer;
  final Map<String, DateTime> _activeSessions = {};

  @override
  void initState() {
    super.initState();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeSessions.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(todayTasksProvider);
    final selectedDateIso = ref.watch(todayTasksProvider.notifier).selectedDateIso;
    final selectedDate = DateTime.tryParse(selectedDateIso) ?? DateTime.now();
    final isToday = selectedDateIso == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tasks & Work Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Task',
            onPressed: () => _showAddTaskDialog(context, ref),
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
            // Date Switcher Header
            Card(
              elevation: 0,
              color: AppTheme.emeraldPrimary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppTheme.emeraldPrimary),
                      tooltip: 'Previous Day',
                      onPressed: () {
                        final prev = selectedDate.subtract(const Duration(days: 1));
                        ref.read(todayTasksProvider.notifier).loadTasks(DateFormat('yyyy-MM-dd').format(prev));
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.emeraldPrimary),
                      label: Text(
                        isToday ? 'Today (${DateFormat('MMM d').format(selectedDate)})' : DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.emeraldPrimary),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          ref.read(todayTasksProvider.notifier).loadTasks(DateFormat('yyyy-MM-dd').format(picked));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppTheme.emeraldPrimary),
                      tooltip: 'Next Day',
                      onPressed: () {
                        final next = selectedDate.add(const Duration(days: 1));
                        ref.read(todayTasksProvider.notifier).loadTasks(DateFormat('yyyy-MM-dd').format(next));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isToday ? 'Today\'s Scheduled Tasks' : 'Tasks for ${DateFormat('MMM d').format(selectedDate)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddTaskDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Task'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (tasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.task_alt, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No work tasks scheduled for today.'),
                        const SizedBox(height: 4),
                        Text(
                          'Add daily work activities and track active working time.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: tasks.map((task) {
                  final isStarted = _activeSessions.containsKey(task.id);
                  final startTime = _activeSessions[task.id];
                  final elapsedSeconds = isStarted && startTime != null
                      ? DateTime.now().difference(startTime).inSeconds
                      : 0;

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
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(task.priority).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  task.priority.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _getPriorityColor(task.priority),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (task.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(task.description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                task.scheduledDate,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.status.name.toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.endTime != null
                                      ? '${task.startTime} - ${task.endTime}'
                                      : task.startTime,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),

                          if (isStarted) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Active Timer:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    _formatSeconds(elapsedSeconds),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.emeraldPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 4),

                          // Workflow Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.emeraldPrimary, size: 20),
                                    tooltip: 'Edit Task',
                                    onPressed: () => _showAddTaskDialog(context, ref, task),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'Delete Task',
                                    onPressed: () {
                                      ref.read(todayTasksProvider.notifier).deleteTask(task.id);
                                    },
                                  ),
                                ],
                              ),
                              if (task.status != TaskStatus.completed)
                                Row(
                                  children: [
                                    if (!isStarted)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldPrimary),
                                        onPressed: () async {
                                          final now = DateTime.now();
                                          setState(() => _activeSessions[task.id] = now);
                                          await ref.read(todayTasksProvider.notifier).updateTaskStatus(task.id, TaskStatus.inProgress);

                                          // Schedule immediate work session timeout alarm
                                          final endTarget = now.add(Duration(minutes: task.durationMinutes));
                                          final alarmId = (endTarget.millisecondsSinceEpoch ~/ 1000) + (task.id.hashCode.abs() % 1000);
                                          await NotificationService.instance.scheduleNotification(
                                            id: alarmId,
                                            title: '⏰ Task Timeout Alarm: ${task.title}',
                                            body: 'Time is up! Your ${task.durationMinutes}-minute work session for "${task.title}" has completed.',
                                            scheduledDate: endTarget,
                                            channelId: AppConstants.taskChannelId,
                                            channelName: AppConstants.taskChannelName,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Working session started! Alarm set for ${DateFormat('hh:mm a').format(endTarget)} (${task.durationMinutes} mins).')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.play_arrow, size: 18),
                                        label: const Text('Start Work'),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                                        onPressed: () {
                                          setState(() => _activeSessions.remove(task.id));
                                          ref.read(todayTasksProvider.notifier).updateTaskStatus(task.id, TaskStatus.completed);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Task "${task.title}" completed! Active duration: ${_formatSeconds(elapsedSeconds)}')),
                                          );
                                        },
                                        icon: const Icon(Icons.stop, size: 18),
                                        label: const Text('End Work'),
                                      ),
                                  ],
                                )
                              else
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: 4),
                                    Text('Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                            ],
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

  void _showAddTaskDialog(BuildContext context, WidgetRef ref, [WorkTask? taskToEdit]) {
    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    final descController = TextEditingController(text: taskToEdit?.description ?? '');
    DateTime selectedDate = taskToEdit != null
        ? (DateTime.tryParse(taskToEdit.scheduledDate) ?? DateTime.now())
        : DateTime.now();
    final parsedTime = PrayerTimeHelper.parseScheduleTimeString(taskToEdit?.startTime);
    String timeMode = parsedTime.isPrayerRelative ? 'PRAYER_RELATIVE' : 'CLOCK';
    String selectedPrayer = parsedTime.prayerName;
    String prayerRef = parsedTime.referencePoint;
    int offsetMinutes = parsedTime.offsetMinutes;
    final offsetController = TextEditingController(text: '$offsetMinutes');
    TimeOfDay startTime = parsedTime.clockTime;
    int durationMinutes = taskToEdit?.durationMinutes ?? 60;
    TaskPriority priority = taskToEdit?.priority ?? TaskPriority.medium;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final prayerTimings = ref.watch(prayerTimingsProvider);
            final prayerSettings = ref.watch(prayerSettingsProvider);

            final formattedTimeStr = PrayerTimeHelper.formatScheduleTimeString(
              isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
              clockTime: startTime,
              prayerName: selectedPrayer,
              referencePoint: prayerRef,
              offsetMinutes: offsetMinutes,
              prayerTimings: prayerTimings,
              settings: prayerSettings,
            );

            return AlertDialog(
              title: Text(taskToEdit == null ? 'Schedule Work Task' : 'Edit Work Task'),
              actionsOverflowButtonSpacing: 8,
              actionsOverflowDirection: VerticalDirection.down,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title *',
                        prefixIcon: Icon(Icons.task),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event, color: AppTheme.emeraldPrimary),
                      title: const Text('Scheduled Date', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      trailing: TextButton(
                        child: const Text('Change Date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    const Divider(),

                    // Automatic Timing Section
                    const Text(
                      'Timing Mode (Automatic by Prayer Time or Clock)',
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
                      // Prayer Selection Dropdown with Day Periods
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
                          helperText: 'Enter delay after prayer (e.g. 15, 30, 45, 60 mins)',
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
                      // Exact Clock Time Picker
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time, color: AppTheme.emeraldPrimary),
                        title: const Text('Start Time', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        subtitle: Text(
                          startTime.format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        trailing: TextButton(
                          child: const Text('Change Time'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              setState(() => startTime = picked);
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
                                  'Task Alarm: $formattedTimeStr',
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

                    // Duration Selector (e.g. 1 Hour)
                    const Text('Duration', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Builder(builder: (context) {
                      final availableDurations = {15, 30, 45, 60, 90, 120, 180, durationMinutes}.toList()..sort();
                      return DropdownButtonFormField<int>(
                        value: durationMinutes,
                        isExpanded: true,
                        decoration: const InputDecoration(
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

                    // Priority
                    DropdownButtonFormField<TaskPriority>(
                      value: priority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TaskPriority.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => priority = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Frequency Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: taskToEdit?.frequency ?? 'One-Time',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat_outlined),
                      ),
                      items: const ['One-Time', 'Daily', 'Weekly', 'Monthly']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    final scheduledDateIso = DateFormat('yyyy-MM-dd').format(selectedDate);

                    final calculatedTarget = PrayerTimeHelper.calculateTargetTime(
                      isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
                      clockTime: startTime,
                      prayerName: selectedPrayer,
                      referencePoint: prayerRef,
                      offsetMinutes: offsetMinutes,
                      prayerTimings: prayerTimings,
                      settings: prayerSettings,
                    );

                    var scheduledStartDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      calculatedTarget.hour,
                      calculatedTarget.minute,
                    );

                    // If scheduled time has already passed today, advance to tomorrow so alarm always fires
                    if (scheduledStartDateTime.isBefore(DateTime.now())) {
                      scheduledStartDateTime = scheduledStartDateTime.add(const Duration(days: 1));
                    }

                    final savedStartTimeStr = PrayerTimeHelper.formatScheduleTimeString(
                      isPrayerRelative: timeMode == 'PRAYER_RELATIVE',
                      clockTime: startTime,
                      prayerName: selectedPrayer,
                      referencePoint: prayerRef,
                      offsetMinutes: offsetMinutes,
                      prayerTimings: prayerTimings,
                      settings: prayerSettings,
                    );

                    final scheduledEndDateTime = scheduledStartDateTime.add(Duration(minutes: durationMinutes));
                    final savedEndTimeStr = DateFormat('hh:mm a').format(scheduledEndDateTime);

                    if (taskToEdit == null) {
                      await ref.read(todayTasksProvider.notifier).addTask(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            scheduledDate: scheduledDateIso,
                            startTime: savedStartTimeStr,
                            endTime: savedEndTimeStr,
                            durationMinutes: durationMinutes,
                            priority: priority,
                          );
                    } else {
                      final updated = WorkTask(
                        id: taskToEdit.id,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        scheduledDate: scheduledDateIso,
                        startTime: savedStartTimeStr,
                        endTime: savedEndTimeStr,
                        durationMinutes: durationMinutes,
                        priority: priority,
                        status: taskToEdit.status,
                        createdAt: taskToEdit.createdAt,
                      );
                      await ref.read(todayTasksProvider.notifier).updateTask(updated);
                    }

                    // 1. Schedule notification for start time
                    if (scheduledStartDateTime.isAfter(DateTime.now())) {
                      await NotificationService.instance.scheduleNotification(
                        id: scheduledStartDateTime.millisecondsSinceEpoch ~/ 1000,
                        title: '🚀 Task Started: ${titleController.text.trim()}',
                        body: 'Your $durationMinutes-minute scheduled task starts now ($savedStartTimeStr).',
                        scheduledDate: scheduledStartDateTime,
                        channelId: AppConstants.taskChannelId,
                        channelName: AppConstants.taskChannelName,
                      );
                    }

                    // 2. Schedule notification for task timeout (end of duration)
                    if (scheduledEndDateTime.isAfter(DateTime.now())) {
                      await NotificationService.instance.scheduleNotification(
                        id: (scheduledEndDateTime.millisecondsSinceEpoch ~/ 1000) + 1,
                        title: '⏰ Task Timeout Alarm: ${titleController.text.trim()}',
                        body: 'Time is up! Your $durationMinutes-minute work session for "${titleController.text.trim()}" has completed.',
                        scheduledDate: scheduledEndDateTime,
                        channelId: AppConstants.taskChannelId,
                        channelName: AppConstants.taskChannelName,
                      );
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(taskToEdit == null
                              ? 'Task scheduled: $savedStartTimeStr'
                              : 'Task updated: $savedStartTimeStr'),
                        ),
                      );
                    }
                  },
                  child: Text(taskToEdit == null ? 'Save & Schedule Task' : 'Update Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatSeconds(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red.shade700;
      case TaskPriority.medium:
        return AppTheme.goldAccent;
      case TaskPriority.low:
        return Colors.blue.shade700;
    }
  }
}
