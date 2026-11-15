import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdhanLength { short, long }

final prayerAdhanProvider =
    StateNotifierProvider<PrayerAdhanNotifier, Map<String, AdhanLength>>((ref) {
  return PrayerAdhanNotifier();
});

class PrayerAdhanNotifier extends StateNotifier<Map<String, AdhanLength>> {
  PrayerAdhanNotifier() : super(const {}) {
    _ready = _load();
  }

  late final Future<void> _ready;

  static String _key(String prayer) => 'adhan_length_${prayer.toLowerCase()}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      for (final prayer in const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
        prayer: prefs.getString(_key(prayer)) == 'long'
            ? AdhanLength.long
            : AdhanLength.short,
    };
  }

  Future<void> setLength(String prayer, AdhanLength length) async {
    await _ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(prayer), length.name);
    state = {...state, prayer: length};
  }
}

final prayerAdhanLeadProvider =
    StateNotifierProvider<PrayerAdhanLeadNotifier, Map<String, int>>((ref) {
  return PrayerAdhanLeadNotifier();
});

class PrayerAdhanLeadNotifier extends StateNotifier<Map<String, int>> {
  PrayerAdhanLeadNotifier() : super(const {}) {
    _ready = _load();
  }

  late final Future<void> _ready;

  static String _key(String prayer) => 'adhan_lead_${prayer.toLowerCase()}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      for (final prayer in const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
        prayer: prefs.getInt(_key(prayer))?.clamp(0, 120) ?? 0,
    };
  }

  Future<void> setMinutes(String prayer, int minutes) async {
    await _ready;
    final clamped = minutes.clamp(0, 120);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(prayer), clamped);
    state = {...state, prayer: clamped};
  }
}
