import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';

class DateFormatter {
  static final DateFormat _gregorianFormat = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _shortDateFormat = DateFormat('EEE, d MMM');
  static final DateFormat _timeFormat12 = DateFormat('hh:mm a');
  static final DateFormat _timeFormat24 = DateFormat('HH:mm');

  static String formatGregorian(DateTime date) => _gregorianFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);

  static String formatTime(DateTime time, {bool use24Hour = false}) {
    return use24Hour ? _timeFormat24.format(time) : _timeFormat12.format(time);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Calculates Hijri Date algorithmically from Gregorian DateTime
  static String formatHijri(DateTime date) {
    int day = date.day;
    int month = date.month;
    int year = date.year;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    int a = (year / 100).floor();
    int b = 2 - a + (a / 4).floor();
    int julianDay = (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;

    int z = julianDay - 1948440 + 10632;
    int n = ((z - 1) / 10631).floor();
    z = z - 10631 * n + 354;
    int j = ((10985 - z) / 5316).floor() * ((50 * z) / 17719).floor() +
        ((z / 5670).floor() * ((43 * z) / 15238).floor());
    z = z - ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
        ((j / 30).floor() * ((15238 * j) / 43).floor()) +
        29;

    int m = ((24 * z) / 709).floor();
    int d = z - ((709 * m) / 24).floor();
    int y = 30 * n + j - 30;

    int hijriDay = d;
    int hijriMonth = m; // 1-indexed
    int hijriYear = y;

    String monthName = (hijriMonth >= 1 && hijriMonth <= 12)
        ? AppConstants.hijriMonths[hijriMonth - 1]
        : 'Hijri';

    return '$hijriDay $monthName $hijriYear AH';
  }
}
