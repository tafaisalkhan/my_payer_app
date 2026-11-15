import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/core/location/location_service.dart';
import 'package:mynamaz_scheduler/core/utils/date_formatter.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/prayer_check_in_service.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';

enum PrayerRecordsView { pending, day, week, month, year }

class PrayerRecordsScreen extends ConsumerStatefulWidget {
  final PrayerRecordsView initialView;
  final String? initialPrayer;

  const PrayerRecordsScreen({
    super.key,
    this.initialView = PrayerRecordsView.pending,
    this.initialPrayer,
  });

  @override
  ConsumerState<PrayerRecordsScreen> createState() =>
      _PrayerRecordsScreenState();
}

class _RecordData {
  final List<PendingPrayerCheckIn> pending;
  final Map<String, PrayerRecord> records;
  final Map<String, int> completedByDate;
  final Set<String> pendingDates;
  final Set<String> missedDates;
  final LocationData location;
  final PrayerCalculationSettings settings;
  final DateTime installed;

  const _RecordData(
      this.pending,
      this.records,
      this.completedByDate,
      this.pendingDates,
      this.missedDates,
      this.location,
      this.settings,
      this.installed);
}

class _PrayerRecordsScreenState extends ConsumerState<PrayerRecordsScreen> {
  late PrayerRecordsView _view;
  late DateTime _selectedDate;
  late Future<_RecordData> _data;
  String? _editingKey;
  bool _autoEditDone = false;
  PrayerStatus? _status;
  PrayerPlace? _place;
  int? _joinedRakats;
  bool? _takbirEUla;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _selectedDate = DateTime.now();
    _data = _loadData();
  }

  String _iso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<_RecordData> _loadData() async {
    await ref.read(prayerSettingsProvider.notifier).ready;
    final location = await ref.read(locationDataProvider.future);
    final repository = ref.read(prayerRepositoryProvider);
    final settings = ref.read(prayerSettingsProvider);
    final installed = await PrayerCheckInService.installDate();
    final records = (await repository.getAllPrayerRecords())
        .where((record) => record.date.compareTo(_iso(installed)) >= 0)
        .toList();
    final pending = await PrayerCheckInService.load(
      repository: repository,
      latitude: location.latitude,
      longitude: location.longitude,
      settings: settings,
    );
    final completedByDate = <String, int>{};
    final missedDates = <String>{};
    for (final record in records) {
      if (record.status == PrayerStatus.onTime ||
          record.status == PrayerStatus.qada) {
        completedByDate.update(record.date, (count) => count + 1,
            ifAbsent: () => 1);
      }
      if (record.status == PrayerStatus.notPrayed) {
        missedDates.add(record.date);
      }
    }
    return _RecordData(
      pending,
      {
        for (final record in records)
          '${record.date}_${record.prayerName.toUpperCase()}': record
      },
      completedByDate,
      {for (final item in pending) item.dateIso},
      missedDates,
      location,
      settings,
      installed,
    );
  }

  void _reload() => setState(() => _data = _loadData());

  List<PendingPrayerCheckIn> _prayersFor(DateTime date, _RecordData data) {
    final day = DateTime(date.year, date.month, date.day);
    return ref
        .read(prayerRepositoryProvider)
        .calculatePrayerTimings(
          latitude: data.location.latitude,
          longitude: data.location.longitude,
          date: day,
          settings: data.settings,
        )
        .map((timing) => PendingPrayerCheckIn(
              _iso(day),
              timing.name,
              timing.time,
            ))
        .toList();
  }

  PrayerRecord? _recordFor(PendingPrayerCheckIn item, _RecordData data) =>
      data.records['${item.dateIso}_${item.prayer.toUpperCase()}'];

  void _edit(PendingPrayerCheckIn item, PrayerRecord? existing) {
    setState(() {
      _editingKey = '${item.dateIso}_${item.prayer.toUpperCase()}';
      _status =
          existing?.status == PrayerStatus.pending ? null : existing?.status;
      _place = existing?.place;
      _joinedRakats = existing?.joinedRakats;
      _takbirEUla = existing == null
          ? null
          : existing.takbirEUla
              ? true
              : existing.joinedRakats != null
                  ? false
                  : null;
      _error = null;
    });
  }

  Future<void> _save(PendingPrayerCheckIn item) async {
    if (_saving || _status == null) return;
    if (_status == PrayerStatus.onTime && _place == null) {
      setState(() => _error = 'Choose Home or Mosque.');
      return;
    }
    if (_status == PrayerStatus.onTime &&
        _place == PrayerPlace.mosque &&
        _takbirEUla == null) {
      setState(() => _error = 'Choose Yes or No for Takbir-e-Ula.');
      return;
    }
    if (_status == PrayerStatus.onTime &&
        _place == PrayerPlace.mosque &&
        _takbirEUla == false &&
        _joinedRakats == null) {
      setState(() => _error = 'Choose how many rakats you missed.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final onTime = _status == PrayerStatus.onTime;
      await ref.read(prayerRepositoryProvider).savePrayerRecord(PrayerRecord(
            id: '${item.dateIso}_${item.prayer.toUpperCase()}',
            date: item.dateIso,
            prayerName: item.prayer,
            status: _status!,
            place: onTime ? _place : null,
            takbirEUla:
                onTime && _place == PrayerPlace.mosque && _takbirEUla == true,
            joinedRakats:
                onTime && _place == PrayerPlace.mosque && _takbirEUla == false
                    ? _joinedRakats
                    : null,
            updatedAt: DateTime.now(),
          ));
      if (item.dateIso == _iso(DateTime.now())) {
        await ref.read(todayPrayerRecordsProvider.notifier).loadTodayRecords();
      }
      ref.invalidate(namazProgressStatsProvider);
      ref.invalidate(prayerHistoryProvider);
      if (!mounted) return;
      setState(() {
        _editingKey = null;
        _saving = false;
        _data = _loadData();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this prayer.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Namaz records'),
        actions: [
          IconButton(
            tooltip: 'Refresh records',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_RecordData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load prayer records or location.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (!_autoEditDone && widget.initialPrayer != null) {
            _autoEditDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              for (final item in _prayersFor(_selectedDate, data)) {
                if (item.prayer.toLowerCase() ==
                    widget.initialPrayer!.toLowerCase()) {
                  _edit(item, _recordFor(item, data));
                  break;
                }
              }
            });
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data.pending.length} prayers awaiting check-in',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final view in PrayerRecordsView.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(switch (view) {
                              PrayerRecordsView.pending => 'Pending',
                              PrayerRecordsView.day =>
                                'Day (${_progressForDays([
                                      _selectedDate
                                    ], data).completed}/${_progressForDays([
                                      _selectedDate
                                    ], data).total})',
                              PrayerRecordsView.week =>
                                'Week (${_progressForDays(_weekDays(), data).completed}/${_progressForDays(_weekDays(), data).total})',
                              PrayerRecordsView.month => 'Month',
                              PrayerRecordsView.year => 'Year',
                            }),
                            selected: _view == view,
                            onSelected: (_) => setState(() {
                              _view = view;
                              _editingKey = null;
                            }),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(
                child: _view == PrayerRecordsView.pending
                    ? _pendingList(data)
                    : _calendarView(data)),
          ]);
        },
      ),
    );
  }

  Widget _pendingList(_RecordData data) {
    if (data.pending.isEmpty) {
      return const Center(
          child: Text('All past prayers have been checked in.'));
    }
    final pending = data.pending.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pending.length,
      itemBuilder: (context, index) => _prayerCard(pending[index], data),
    );
  }

  Widget _calendarView(_RecordData data) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          IconButton(
            tooltip: 'Previous',
            onPressed: _previousPeriodIsAvailable(data.installed)
                ? () => _movePeriod(-1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
              child: Text(_periodTitle(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: 'Next',
            onPressed: _nextPeriodIsAvailable() ? () => _movePeriod(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Choose date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: data.installed,
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            icon: const Icon(Icons.calendar_month),
          ),
        ]),
        if (_view == PrayerRecordsView.month || _view == PrayerRecordsView.year)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 12, runSpacing: 4, children: [
              _legend('5/5 complete', Colors.green),
              _legend('Some complete', Colors.teal),
              _legend('Missed', Colors.red),
              _legend('Pending', Colors.orange),
            ]),
          ),
        if (_view == PrayerRecordsView.day)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Hijri: ${DateFormatter.formatHijri(_selectedDate)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        if (_view == PrayerRecordsView.day) ..._dayCards(data),
        if (_view == PrayerRecordsView.week) ..._weekCards(data),
        if (_view == PrayerRecordsView.month)
          _monthCalendar(_selectedDate.year, _selectedDate.month, data),
        if (_view == PrayerRecordsView.year)
          for (var month = 1; month <= 12; month++)
            if (!DateTime(_selectedDate.year, month + 1, 0)
                    .isBefore(data.installed) &&
                !DateTime(_selectedDate.year, month, 1).isAfter(DateTime.now()))
              _monthCalendar(_selectedDate.year, month, data),
      ],
    );
  }

  void _movePeriod(int amount) {
    setState(() {
      _editingKey = null;
      _selectedDate = switch (_view) {
        PrayerRecordsView.day => DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day + amount),
        PrayerRecordsView.week => DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day + amount * 7),
        PrayerRecordsView.month =>
          DateTime(_selectedDate.year, _selectedDate.month + amount, 1),
        PrayerRecordsView.year => DateTime(_selectedDate.year + amount, 1, 1),
        PrayerRecordsView.pending => _selectedDate,
      };
    });
  }

  DateTime _periodStart(DateTime date) => switch (_view) {
        PrayerRecordsView.day => DateTime(date.year, date.month, date.day),
        PrayerRecordsView.week =>
          DateTime(date.year, date.month, date.day - date.weekday + 1),
        PrayerRecordsView.month => DateTime(date.year, date.month, 1),
        PrayerRecordsView.year => DateTime(date.year, 1, 1),
        PrayerRecordsView.pending => date,
      };

  bool _previousPeriodIsAvailable(DateTime installed) =>
      _periodStart(_nextPeriodDate(-1)).isAfter(installed) ||
      _periodStart(_nextPeriodDate(-1))
          .isAtSameMomentAs(_periodStart(installed));

  bool _nextPeriodIsAvailable() =>
      !_periodStart(_nextPeriodDate(1)).isAfter(DateTime.now());

  DateTime _nextPeriodDate(int amount) => switch (_view) {
        PrayerRecordsView.day => DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day + amount),
        PrayerRecordsView.week => DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day + amount * 7),
        PrayerRecordsView.month =>
          DateTime(_selectedDate.year, _selectedDate.month + amount, 1),
        PrayerRecordsView.year => DateTime(_selectedDate.year + amount, 1, 1),
        PrayerRecordsView.pending => _selectedDate,
      };

  String _periodTitle() => switch (_view) {
        PrayerRecordsView.day =>
          DateFormat('EEEE, d MMM y').format(_selectedDate),
        PrayerRecordsView.week =>
          'Week of ${DateFormat('d MMM y').format(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)))}',
        PrayerRecordsView.month => DateFormat('MMMM y').format(_selectedDate),
        PrayerRecordsView.year => '${_selectedDate.year}',
        PrayerRecordsView.pending => 'Pending',
      };

  List<Widget> _dayCards(_RecordData data) {
    final items = _prayersFor(_selectedDate, data);
    return _selectedDate.isBefore(data.installed)
        ? [const Text('Tracking started on the install date.')]
        : [for (final item in items) _prayerCard(item, data)];
  }

  ({int completed, int total}) _progressForDays(
      Iterable<DateTime> days, _RecordData data) {
    final now = DateTime.now();
    var completed = 0;
    var total = 0;
    for (final day in days) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      if (normalizedDay.isBefore(data.installed) ||
          normalizedDay.isAfter(now)) {
        continue;
      }
      for (final item in _prayersFor(normalizedDay, data)) {
        final record = _recordFor(item, data);
        if (item.time.isAfter(now) && record == null) continue;
        total++;
        if (record?.status == PrayerStatus.onTime ||
            record?.status == PrayerStatus.qada) {
          completed++;
        }
      }
    }
    return (completed: completed, total: total);
  }

  List<DateTime> _weekDays() {
    final monday =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    return List.generate(7,
        (offset) => DateTime(monday.year, monday.month, monday.day + offset));
  }

  List<Widget> _weekCards(_RecordData data) {
    final monday = _weekDays().first;
    return [
      for (var offset = 0; offset < 7; offset++)
        if (!DateTime(monday.year, monday.month, monday.day + offset)
                .isBefore(data.installed) &&
            !DateTime(monday.year, monday.month, monday.day + offset)
                .isAfter(DateTime.now()))
          _daySummary(
              DateTime(monday.year, monday.month, monday.day + offset), data),
    ];
  }

  Widget _daySummary(DateTime day, _RecordData data) {
    final dateIso = _iso(day);
    final completed = data.completedByDate[dateIso] ?? 0;
    final pending =
        data.pending.where((item) => item.dateIso == dateIso).length;
    final times = _prayersFor(day, data)
        .map((item) => '${item.prayer} ${DateFormat.jm().format(item.time)}')
        .join('  ·  ');
    return Card(
        child: ListTile(
      title: Text(DateFormat('EEE, d MMM').format(day)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormatter.formatHijri(day)),
        Text('$completed / 5 completed · $pending pending'),
        Text(times, style: Theme.of(context).textTheme.bodySmall),
      ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() {
        _selectedDate = day;
        _view = PrayerRecordsView.day;
        _editingKey = null;
      }),
    ));
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _monthCalendar(int year, int month, _RecordData data) {
    final first = DateTime(year, month, 1);
    final days = DateTime(year, month + 1, 0).day;
    final leading = first.weekday - 1;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        TextButton(
          onPressed: () => setState(() {
            _selectedDate = first;
            _view = PrayerRecordsView.month;
          }),
          child: Text(DateFormat('MMMM y').format(first)),
        ),
        Text(
          '${DateFormatter.formatHijri(first)} – '
          '${DateFormatter.formatHijri(DateTime(year, month + 1, 0))}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(children: [
          for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Text(label))),
        ]),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.92,
          ),
          itemCount: leading + days,
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1) return const SizedBox.shrink();
            final day = DateTime(year, month, number);
            if (day.isBefore(data.installed) || day.isAfter(DateTime.now())) {
              return const SizedBox.shrink();
            }
            final dateIso = _iso(day);
            final completed = data.completedByDate[dateIso] ?? 0;
            final pending = data.pendingDates.contains(dateIso);
            final missed = data.missedDates.contains(dateIso);
            final color = completed == 5
                ? Colors.green
                : completed > 0
                    ? Colors.teal
                    : missed
                        ? Colors.red
                        : pending
                            ? Colors.orange
                            : Theme.of(context).colorScheme.onSurfaceVariant;
            return InkWell(
              onTap: () => setState(() {
                _selectedDate = day;
                _view = PrayerRecordsView.day;
                _editingKey = null;
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$number',
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Text('H ${DateFormatter.formatHijri(day).split(' ').first}',
                      style: TextStyle(color: color, fontSize: 8)),
                  if (completed > 0)
                    Text('$completed/5',
                        style: TextStyle(color: color, fontSize: 9)),
                  if (completed == 0 && pending)
                    Icon(Icons.circle, size: 5, color: color),
                ],
              ),
            );
          },
        ),
      ]),
    ));
  }

  Widget _prayerCard(PendingPrayerCheckIn item, _RecordData data) {
    final record = _recordFor(item, data);
    final key = '${item.dateIso}_${item.prayer.toUpperCase()}';
    final canEdit = !item.time.isAfter(DateTime.now());
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(
            '${item.prayer} · ${DateFormat('EEE, d MMM y').format(item.time)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          )),
          Text(DateFormat.jm().format(item.time)),
        ]),
        const SizedBox(height: 4),
        Text(DateFormatter.formatHijri(item.time),
            style: Theme.of(context).textTheme.bodySmall),
        Text(record?.status.label ?? (canEdit ? 'Pending' : 'Upcoming')),
        if (record?.place != null ||
            record?.takbirEUla == true ||
            record?.joinedRakats != null)
          Text([
            if (record?.place != null)
              record!.place == PrayerPlace.mosque ? 'Mosque' : 'Home',
            if (record?.takbirEUla == true) 'Takbir-e-Ula',
            if (record?.joinedRakats != null)
              '${PrayerRecord.fardRakatCount(item.prayer) - record!.joinedRakats!} rakats missed',
          ].join(' · ')),
        if (canEdit)
          TextButton.icon(
            onPressed: () => _edit(item, record),
            icon: const Icon(Icons.edit_outlined),
            label: Text(record == null ? 'Check in' : 'Edit'),
          ),
        if (_editingKey == key) _editor(item),
      ]),
    ));
  }

  Widget _editor(PendingPrayerCheckIn item) {
    final fard = PrayerRecord.fardRakatCount(item.prayer);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      const Text('Prayer status'),
      Wrap(spacing: 6, children: [
        for (final option in const [
          PrayerStatus.onTime,
          PrayerStatus.qada,
          PrayerStatus.notPrayed
        ])
          ChoiceChip(
            label: Text(option.label),
            selected: _status == option,
            onSelected: (_) => setState(() {
              _status = option;
              _error = null;
              if (option != PrayerStatus.onTime) {
                _place = null;
                _joinedRakats = null;
                _takbirEUla = null;
              }
            }),
          ),
      ]),
      if (_status == PrayerStatus.onTime) ...[
        const SizedBox(height: 8),
        const Text('Prayed at'),
        Wrap(spacing: 6, children: [
          for (final option in PrayerPlace.values)
            ChoiceChip(
              label: Text(option == PrayerPlace.mosque ? 'Mosque' : 'Home'),
              selected: _place == option,
              onSelected: (_) => setState(() {
                _place = option;
                if (option == PrayerPlace.home) {
                  _joinedRakats = null;
                  _takbirEUla = null;
                }
                _error = null;
              }),
            ),
        ]),
        if (_place == PrayerPlace.mosque) ...[
          const SizedBox(height: 8),
          const Text('Takbir-e-Ula?'),
          Wrap(spacing: 6, children: [
            for (final answer in [true, false])
              ChoiceChip(
                label: Text(answer ? 'Yes' : 'No'),
                selected: _takbirEUla == answer,
                onSelected: (_) {
                  setState(() {
                    _takbirEUla = answer;
                    _joinedRakats = null;
                    _error = null;
                  });
                  if (answer) _save(item);
                },
              ),
          ]),
          if (_takbirEUla == false)
            Row(children: [
              Expanded(child: Text('Rakats missed (of $fard)')),
              DropdownButton<int>(
                value: _joinedRakats == null ? null : fard - _joinedRakats!,
                hint: const Text('Select'),
                items: [
                  for (var count = 0; count <= fard; count++)
                    DropdownMenuItem(value: count, child: Text('$count'))
                ],
                onChanged: (value) => setState(() {
                  _joinedRakats = value == null ? null : fard - value;
                  _error = null;
                }),
              ),
            ]),
        ],
      ],
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(
          onPressed: _saving ? null : () => setState(() => _editingKey = null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _status == null ? null : () => _save(item),
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ]),
    ]);
  }
}
