class QuranHistory {
  final String id;
  final String scheduleId;
  final String date; // YYYY-MM-DD
  final String surahName;
  final int startAyah;
  final int endAyah;
  final String status; // COMPLETED, SKIPPED, REMINDED_LATER
  final DateTime completedAt;

  const QuranHistory({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    required this.status,
    required this.completedAt,
  });

  bool get isPartHistory =>
      surahName.startsWith('Part') || (startAyah == 0 && endAyah == 0);

  String get displayTitle =>
      isPartHistory ? surahName : '$surahName ($startAyah-$endAyah)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schedule_id': scheduleId,
      'date': date,
      'surah_name': surahName,
      'start_ayah': startAyah,
      'end_ayah': endAyah,
      'status': status,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  factory QuranHistory.fromMap(Map<String, dynamic> map) {
    return QuranHistory(
      id: map['id'] as String,
      scheduleId: map['schedule_id'] as String,
      date: map['date'] as String,
      surahName: map['surah_name'] as String,
      startAyah: map['start_ayah'] as int,
      endAyah: map['end_ayah'] as int,
      status: map['status'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }
}
