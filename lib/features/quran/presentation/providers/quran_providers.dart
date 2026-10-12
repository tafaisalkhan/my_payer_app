import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/quran/data/repositories/quran_repository.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_history.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_schedule.dart';

final quranRepositoryProvider = Provider<QuranRepository>((ref) => QuranRepository());

final quranSchedulesProvider = StateNotifierProvider<QuranSchedulesNotifier, List<QuranSchedule>>((ref) {
  final repo = ref.watch(quranRepositoryProvider);
  return QuranSchedulesNotifier(repo);
});

class QuranSchedulesNotifier extends StateNotifier<List<QuranSchedule>> {
  final QuranRepository _repo;

  QuranSchedulesNotifier(this._repo) : super([]) {
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    state = await _repo.getActiveSchedules();
  }

  Future<void> addSchedule(QuranSchedule schedule) async {
    await _repo.saveSchedule(schedule);
    await loadSchedules();
  }

  Future<void> updateSchedule(QuranSchedule schedule) async {
    await _repo.saveSchedule(schedule);
    await loadSchedules();
  }

  Future<void> deleteSchedule(String id) async {
    await _repo.deleteSchedule(id);
    await loadSchedules();
  }
}

final quranHistoryProvider = StateNotifierProvider<QuranHistoryNotifier, List<QuranHistory>>((ref) {
  final repo = ref.watch(quranRepositoryProvider);
  return QuranHistoryNotifier(repo);
});

class QuranHistoryNotifier extends StateNotifier<List<QuranHistory>> {
  final QuranRepository _repo;

  QuranHistoryNotifier(this._repo) : super([]) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = await _repo.getHistory();
  }

  Future<void> markCompleted({
    required String scheduleId,
    required String surahName,
    required int startAyah,
    required int endAyah,
    String status = 'COMPLETED',
  }) async {
    final now = DateTime.now();
    final dateIso = DateFormat('yyyy-MM-dd').format(now);

    final history = QuranHistory(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      scheduleId: scheduleId,
      date: dateIso,
      surahName: surahName,
      startAyah: startAyah,
      endAyah: endAyah,
      status: status,
      completedAt: now,
    );

    await _repo.addHistory(history);
    await loadHistory();
  }
}
