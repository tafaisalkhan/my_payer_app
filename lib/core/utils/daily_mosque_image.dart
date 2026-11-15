import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DailyMosqueImage {
  final ImageProvider image;
  final String? credit;

  const DailyMosqueImage(this.image, this.credit);
}

final dailyMosqueImageProvider = FutureProvider<DailyMosqueImage>((ref) async {
  const fallback = DailyMosqueImage(
    AssetImage('assets/images/mosque_hero.jpg'),
    null,
  );
  if (kIsWeb) return fallback;

  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final refreshTimer = Timer(tomorrow.difference(now), ref.invalidateSelf);
  ref.onDispose(refreshTimer.cancel);

  final dayKey = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final dayNumber =
      DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;

  try {
    final directory = await getApplicationSupportDirectory();
    final imageFile = File(path.join(directory.path, 'mosque_day_$dayKey.jpg'));
    final creditFile =
        File(path.join(directory.path, 'mosque_day_$dayKey.txt'));
    if (await imageFile.exists() && await imageFile.length() > 0) {
      return DailyMosqueImage(
        FileImage(imageFile),
        await creditFile.exists() ? await creditFile.readAsString() : null,
      );
    }

    final client = HttpClient()
      ..userAgent = 'MyNamazScheduler/1.0 (daily mosque photo)';
    try {
      final api = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'categorymembers',
        'gcmtitle': 'Category:Featured pictures of mosques',
        'gcmtype': 'file',
        'gcmlimit': '100',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiurlwidth': '1200',
        'format': 'json',
      });
      final response =
          await (await client.getUrl(api).timeout(const Duration(seconds: 12)))
              .close()
              .timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Photo catalog returned ${response.statusCode}');
      }
      final json = jsonDecode(await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12))) as Map<String, dynamic>;
      final pages = (json['query'] as Map?)?['pages'] as Map?;
      final candidates =
          (pages?.values ?? const []).whereType<Map>().where((page) {
        final info = (page['imageinfo'] as List?)?.firstOrNull as Map?;
        return info != null &&
            (info['mime'] == 'image/jpeg' || info['mime'] == 'image/png') &&
            info['thumburl'] is String;
      }).toList()
            ..sort((a, b) => '${a['title']}'.compareTo('${b['title']}'));
      if (candidates.isEmpty) throw const FormatException('No mosque photos');

      for (var offset = 0; offset < candidates.length && offset < 5; offset++) {
        final page = candidates[(dayNumber + offset) % candidates.length];
        final info = (page['imageinfo'] as List).first as Map;
        try {
          final photoResponse = await (await client
                  .getUrl(Uri.parse(info['thumburl'] as String))
                  .timeout(const Duration(seconds: 12)))
              .close()
              .timeout(const Duration(seconds: 12));
          if (photoResponse.statusCode != HttpStatus.ok) continue;
          final bytes = await photoResponse.fold<List<int>>(
              <int>[],
              (list, chunk) =>
                  list..addAll(chunk)).timeout(const Duration(seconds: 15));
          if (bytes.isEmpty) continue;

          await imageFile.writeAsBytes(bytes, flush: true);
          final metadata = info['extmetadata'] as Map?;
          final artistHtml =
              (metadata?['Artist'] as Map?)?['value'] as String? ??
                  'Wikimedia Commons contributor';
          final artist = artistHtml
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&amp;', '&')
              .trim();
          final license =
              (metadata?['LicenseShortName'] as Map?)?['value'] as String? ??
                  '';
          final credit =
              '${artist.isEmpty ? 'Wikimedia Commons contributor' : artist} / Wikimedia Commons${license.isEmpty ? '' : ' ($license)'}';
          await creditFile.writeAsString(credit);
          return DailyMosqueImage(FileImage(imageFile), credit);
        } catch (error) {
          debugPrint('Could not download mosque photo: $error');
        }
      }
    } catch (error) {
      debugPrint('Could not refresh daily mosque photo: $error');
    } finally {
      client.close();
    }

    // Keep the most recent downloaded photo visible while offline.
    final previous = directory
        .listSync()
        .whereType<File>()
        .where((file) =>
            path.basename(file.path).startsWith('mosque_day_') &&
            file.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in previous) {
      if (await file.length() == 0) continue;
      final credit = File(file.path.replaceAll(RegExp(r'\.jpg$'), '.txt'));
      return DailyMosqueImage(
        FileImage(file),
        await credit.exists() ? await credit.readAsString() : null,
      );
    }
  } catch (error) {
    debugPrint('Daily mosque photo unavailable: $error');
  }
  return fallback;
});
