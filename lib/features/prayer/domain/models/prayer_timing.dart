enum PrayerType { fajr, dhuhr, asr, maghrib, isha }

class PrayerTiming {
  final PrayerType type;
  final String name;
  final DateTime time;
  final bool isCurrent;
  final bool isNext;
  final Duration? timeRemaining;

  const PrayerTiming({
    required this.type,
    required this.name,
    required this.time,
    this.isCurrent = false,
    this.isNext = false,
    this.timeRemaining,
  });

  PrayerTiming copyWith({
    bool? isCurrent,
    bool? isNext,
    Duration? timeRemaining,
  }) {
    return PrayerTiming(
      type: type,
      name: name,
      time: time,
      isCurrent: isCurrent ?? this.isCurrent,
      isNext: isNext ?? this.isNext,
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }
}
