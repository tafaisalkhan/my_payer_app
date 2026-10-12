class QuranSchedule {
  final String id;
  final String frequency; // DAILY, EVERY_2_DAYS, EVERY_3_DAYS, CUSTOM, WEEKLY, MONTHLY
  final String recitationTime; // HH:mm
  final int durationMinutes;
  final int surahId;
  final String surahName;
  final int startAyah;
  final int endAyah;
  final int? juz;
  final String selectionType; // SURAH, PART
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const QuranSchedule({
    required this.id,
    required this.frequency,
    required this.recitationTime,
    this.durationMinutes = 30,
    required this.surahId,
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    this.juz,
    this.selectionType = 'SURAH',
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isPartSchedule =>
      selectionType == 'PART' ||
      (juz != null && surahId == 0) ||
      surahName.startsWith('Part');

  String get displayTitle =>
      isPartSchedule ? surahName : '$surahName (Ayah $startAyah-$endAyah)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'frequency': frequency,
      'recitation_time': recitationTime,
      'duration_minutes': durationMinutes,
      'surah_id': surahId,
      'surah_name': surahName,
      'start_ayah': startAyah,
      'end_ayah': endAyah,
      'juz': juz,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory QuranSchedule.fromMap(Map<String, dynamic> map) {
    final sName = map['surah_name'] as String;
    final isPart = sName.startsWith('Part') || (map['juz'] != null && (map['surah_id'] as int) == 0);

    return QuranSchedule(
      id: map['id'] as String,
      frequency: map['frequency'] as String,
      recitationTime: map['recitation_time'] as String,
      durationMinutes: map['duration_minutes'] as int? ?? 30,
      surahId: map['surah_id'] as int,
      surahName: sName,
      startAyah: map['start_ayah'] as int,
      endAyah: map['end_ayah'] as int,
      juz: map['juz'] as int?,
      selectionType: isPart ? 'PART' : 'SURAH',
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
