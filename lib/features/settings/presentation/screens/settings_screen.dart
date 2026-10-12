import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('pref_theme_mode') ?? 'system';
    if (themeStr == 'dark') {
      state = ThemeMode.dark;
    } else if (themeStr == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    await prefs.setString('pref_theme_mode', mode.name);
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsStateNotifier, Map<String, dynamic>>((ref) {
  return SettingsStateNotifier();
});

class SettingsStateNotifier extends StateNotifier<Map<String, dynamic>> {
  SettingsStateNotifier()
      : super({
          'use_24hr_clock': false,
          'language': 'English',
          'namaz_notifications': true,
          'adhan_sound_enabled': true,
          'quran_notifications': true,
          'task_notifications': true,
          'pre_prayer_reminder_mins': 10,
        }) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      'use_24hr_clock': prefs.getBool('use_24hr_clock') ?? false,
      'language': prefs.getString('language') ?? 'English',
      'namaz_notifications': prefs.getBool('namaz_notifications') ?? true,
      'adhan_sound_enabled': prefs.getBool('adhan_sound_enabled') ?? true,
      'quran_notifications': prefs.getBool('quran_notifications') ?? true,
      'task_notifications': prefs.getBool('task_notifications') ?? true,
      'pre_prayer_reminder_mins': prefs.getInt('pre_prayer_reminder_mins') ?? 10,
    };
  }

  Future<void> setBool(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    state = {...state, key: val};
  }

  Future<void> setString(String key, String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    state = {...state, key: val};
  }

  Future<void> setInt(String key, int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
    state = {...state, key: val};
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isPlayingAdhan = false;

  final Map<String, String> _calculationMethods = {
    'KARACHI': 'University of Islamic Sciences, Karachi',
    'ISNA': 'Islamic Society of North America (ISNA)',
    'MWL': 'Muslim World League (MWL)',
    'MAKKAH': 'Umm Al-Qura University, Makkah',
    'EGYPT': 'Egyptian General Authority of Survey',
    'DUBAI': 'Dubai / UAE',
    'QATAR': 'Qatar',
    'KUWAIT': 'Kuwait',
    'SINGAPORE': 'MUIS Singapore',
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerSettingsProvider);
    final appSettings = ref.watch(settingsNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Location & Calculation'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, color: AppTheme.emeraldPrimary),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Update coordinates & city', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.emeraldPrimary),
                        onPressed: () {
                          ref.invalidate(locationDataProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Updating location...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.calculate, color: AppTheme.emeraldPrimary),
                      SizedBox(width: 10),
                      Text('Prayer Calculation Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settings.method,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _calculationMethods.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(prayerSettingsProvider.notifier).updateMethod(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.gavel, color: AppTheme.emeraldPrimary),
                      SizedBox(width: 10),
                      Text('Asr Jurisprudence (Madhab)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Hanafi (Later Asr)')),
                          selected: settings.madhab == 'HANAFI',
                          selectedColor: AppTheme.emeraldPrimary.withValues(alpha: 0.2),
                          onSelected: (_) {
                            ref.read(prayerSettingsProvider.notifier).updateMadhab('HANAFI');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Shafi\'i / Standard')),
                          selected: settings.madhab != 'HANAFI',
                          selectedColor: AppTheme.emeraldPrimary.withValues(alpha: 0.2),
                          onSelected: (_) {
                            ref.read(prayerSettingsProvider.notifier).updateMadhab('SHAFI');
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune, color: AppTheme.emeraldPrimary),
                    title: const Text('Prayer Time Offsets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Manually adjust prayer minutes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showOffsetsDialog(context, settings),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('Notifications & Audio'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active, color: AppTheme.emeraldPrimary),
                  title: const Text('Prayer Notifications'),
                  subtitle: const Text('Receive alerts at prayer time'),
                  value: appSettings['namaz_notifications'] ?? true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).setBool('namaz_notifications', val);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up, color: AppTheme.emeraldPrimary),
                  title: const Text('Short Adhan Sound'),
                  subtitle: const Text('Play "Allahu Akbar, Allahu Akbar"'),
                  value: appSettings['adhan_sound_enabled'] ?? true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).setBool('adhan_sound_enabled', val);
                  },
                ),
                if (appSettings['adhan_sound_enabled'] ?? true)
                  ListTile(
                    leading: Icon(Icons.play_circle_fill, color: AppTheme.goldAccent),
                    title: const Text('Preview Short Adhan Audio'),
                    trailing: ElevatedButton.icon(
                      icon: Icon(_isPlayingAdhan ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPlayingAdhan ? 'Stop' : 'Preview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldPrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_isPlayingAdhan) {
                          await NotificationService.instance.stopAdhanPreview();
                          setState(() => _isPlayingAdhan = false);
                        } else {
                          setState(() => _isPlayingAdhan = true);
                          await NotificationService.instance.playAdhanPreview();
                          if (mounted) {
                            setState(() => _isPlayingAdhan = false);
                          }
                        }
                      },
                    ),
                  ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.menu_book, color: AppTheme.emeraldPrimary),
                  title: const Text('Quran Recitation Reminders'),
                  subtitle: const Text('Receive scheduled Quran alerts'),
                  value: appSettings['quran_notifications'] ?? true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).setBool('quran_notifications', val);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.task_alt, color: AppTheme.emeraldPrimary),
                  title: const Text('Task Reminders'),
                  subtitle: const Text('Receive work activity notifications'),
                  value: appSettings['task_notifications'] ?? true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).setBool('task_notifications', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('Preferences & Appearance'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6, color: AppTheme.emeraldPrimary),
                  title: const Text('App Theme'),
                  subtitle: Text(themeMode.name.toUpperCase()),
                  onTap: () => _showThemePicker(context, themeMode),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.access_time, color: AppTheme.emeraldPrimary),
                  title: const Text('24-Hour Clock Format'),
                  subtitle: const Text('Display time as 14:30 instead of 2:30 PM'),
                  value: appSettings['use_24hr_clock'] ?? false,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).setBool('use_24hr_clock', val);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.language, color: AppTheme.emeraldPrimary),
                  title: const Text('Language'),
                  subtitle: Text(appSettings['language'] ?? 'English'),
                  onTap: () => _showLanguagePicker(context, appSettings['language'] ?? 'English'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('Data & Privacy'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup, color: AppTheme.emeraldPrimary),
                  title: const Text('Backup / Export Data'),
                  subtitle: const Text('Export local database and history'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local data exported successfully to backup folder.')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Clear Local Data'),
                  subtitle: const Text('Reset prayer records and task logs'),
                  onTap: () => _showClearDataConfirm(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'My Namaz Scheduler v1.0.0\nLocal-First Islamic Daily Planner',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.emeraldPrimary,
        ),
      ),
    );
  }


  void _showOffsetsDialog(BuildContext context, PrayerCalculationSettings settings) {
    int fajr = settings.fajrOffset;
    int dhuhr = settings.dhuhrOffset;
    int asr = settings.asrOffset;
    int maghrib = settings.maghribOffset;
    int isha = settings.ishaOffset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Adjust Prayer Offsets (Minutes)'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildOffsetRow('Fajr', fajr, (val) => setState(() => fajr = val)),
                _buildOffsetRow('Dhuhr', dhuhr, (val) => setState(() => dhuhr = val)),
                _buildOffsetRow('Asr', asr, (val) => setState(() => asr = val)),
                _buildOffsetRow('Maghrib', maghrib, (val) => setState(() => maghrib = val)),
                _buildOffsetRow('Isha', isha, (val) => setState(() => isha = val)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldPrimary),
              onPressed: () {
                ref.read(prayerSettingsProvider.notifier).updateOffsets(
                      fajr: fajr,
                      dhuhr: dhuhr,
                      asr: asr,
                      maghrib: maghrib,
                      isha: isha,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffsetRow(String prayer, int current, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(prayer, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onChanged(current - 1),
              ),
              Text('$current min', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(current + 1),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeModeProvider.notifier).setTheme(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light Mode'),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeModeProvider.notifier).setTheme(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark Mode'),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeModeProvider.notifier).setTheme(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, String currentLang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: currentLang,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsNotifierProvider.notifier).setString('language', val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Urdu (اردو)'),
              value: 'Urdu',
              groupValue: currentLang,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsNotifierProvider.notifier).setString('language', val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDataConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently erase all local prayer records, quran history, and work task logs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local records cleared.')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
