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

bool _isValidImageBytes(List<int> bytes) {
  if (bytes.length < 12) return false;
  final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  final isPng = bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  return isJpeg || isPng;
}

Future<bool> _isValidImageFile(File file) async {
  try {
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len < 12) return false;
    final header = await file.openRead(0, 12).fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    return _isValidImageBytes(header);
  } catch (_) {
    return false;
  }
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
    if (await _isValidImageFile(imageFile)) {
      return DailyMosqueImage(
        FileImage(imageFile),
        await creditFile.exists() ? await creditFile.readAsString() : null,
      );
    } else if (await imageFile.exists()) {
      await imageFile.delete();
    }

    final client = HttpClient()
      ..userAgent =
          'MyNamazScheduler/1.0 (https://play.google.com/store/apps/details?id=com.mynamaz.scheduler; android)';
    try {
      final api = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'categorymembers',
        'gcmtitle': 'Category:Featured pictures of mosques',
        'gcmtype': 'file',
        'gcmlimit': '100',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiurlwidth': '1280',
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
            (info['thumburl'] is String || info['url'] is String);
      }).toList()
            ..sort((a, b) => '${a['title']}'.compareTo('${b['title']}'));
      if (candidates.isEmpty) throw const FormatException('No mosque photos');

      for (var offset = 0; offset < candidates.length && offset < 5; offset++) {
        final page = candidates[(dayNumber + offset) % candidates.length];
        final info = (page['imageinfo'] as List).first as Map;
        final downloadUrls = <String>[
          if (info['thumburl'] is String) info['thumburl'] as String,
          if (info['url'] is String) info['url'] as String,
        ];
        for (final imageUrl in downloadUrls) {
          try {
            final photoResponse = await (await client
                    .getUrl(Uri.parse(imageUrl))
                    .timeout(const Duration(seconds: 12)))
                .close()
                .timeout(const Duration(seconds: 12));
            if (photoResponse.statusCode != HttpStatus.ok) continue;
            final bytes = await photoResponse.fold<List<int>>(
                <int>[],
                (list, chunk) =>
                    list..addAll(chunk)).timeout(const Duration(seconds: 15));
            if (!_isValidImageBytes(bytes)) continue;

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
            debugPrint('Could not download mosque photo ($imageUrl): $error');
          }
        }
      }
    } catch (error) {
      debugPrint('Could not refresh daily mosque photo: $error');
    } finally {
      client.close();
    }

    // Keep the most recent valid downloaded photo visible while offline.
    final previous = directory
        .listSync()
        .whereType<File>()
        .where((file) =>
            path.basename(file.path).startsWith('mosque_day_') &&
            file.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in previous) {
      if (!await _isValidImageFile(file)) continue;
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
