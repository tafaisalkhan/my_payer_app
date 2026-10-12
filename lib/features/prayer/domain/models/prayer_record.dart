enum PrayerStatus {
  onTime('On Time'),
  qada('Qada'),
  notPrayed('Not Prayed'),
  pending('Pending');

  final String label;
  const PrayerStatus(this.label);

  static PrayerStatus fromString(String str) {
    switch (str.toUpperCase()) {
      case 'ON_TIME':
      case 'ON TIME':
      case 'ONTIME':
        return PrayerStatus.onTime;
      case 'QADA':
        return PrayerStatus.qada;
      case 'NOT_PRAYED':
      case 'NOT PRAYED':
        return PrayerStatus.notPrayed;
      default:
        return PrayerStatus.pending;
    }
  }
}

class PrayerRecord {
  final String id;
  final String date; // YYYY-MM-DD
  final String prayerName; // Fajr, Dhuhr, Asr, Maghrib, Isha
  final PrayerStatus status;
  final bool takbirEUla;
  final DateTime updatedAt;

  const PrayerRecord({
    required this.id,
    required this.date,
    required this.prayerName,
    required this.status,
    required this.takbirEUla,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'prayer_name': prayerName,
      'status': status.name.toUpperCase(),
      'takbir_e_ula': takbirEUla ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PrayerRecord.fromMap(Map<String, dynamic> map) {
    return PrayerRecord(
      id: map['id'] as String,
      date: map['date'] as String,
      prayerName: map['prayer_name'] as String,
      status: PrayerStatus.fromString(map['status'] as String),
      takbirEUla: (map['takbir_e_ula'] as int) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
