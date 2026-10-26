import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _isLoading = false;
  String _selectedMethod = 'KARACHI';
  String _selectedMadhab = 'HANAFI';

  final List<Map<String, String>> _methods = [
    {'code': 'KARACHI', 'name': 'University of Islamic Sciences, Karachi'},
    {'code': 'MWL', 'name': 'Muslim World League (MWL)'},
    {'code': 'ISNA', 'name': 'Islamic Society of North America (ISNA)'},
    {'code': 'EGYPT', 'name': 'Egyptian General Authority of Survey'},
    {'code': 'MAKKAH', 'name': 'Umm Al-Qura University, Makkah'},
    {'code': 'GULF', 'name': 'Gulf Region'},
    {'code': 'TEHRAN', 'name': 'Institute of Geophysics, Tehran'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _step ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _step
                          ? AppTheme.emeraldPrimary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: _buildStepContent(),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_step == 2 ? 'Get Started' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/mosque_hero.jpg',
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to My Namaz Scheduler',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Accurate 5 Daily Prayer Timings, Qibla Compass, Quran Recitation Reminders, and Daily Activity Tracker.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        );

      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calculation & Juristic Method',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred calculation authority and Asr juristic school.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              const Text('Calculation Method', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _methods.map((m) {
                      return DropdownMenuItem(
                        value: m['code'],
                        child: Text(m['name']!, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMethod = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Asr Jurisprudence (Madhab)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Hanafi'),
                      selected: _selectedMadhab == 'HANAFI',
                      onSelected: (_) => setState(() => _selectedMadhab = 'HANAFI'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Shafi\'i / Maliki / Hanbali'),
                      selected: _selectedMadhab == 'SHAFI',
                      onSelected: (_) => setState(() => _selectedMadhab = 'SHAFI'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 2:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_active, size: 70, color: AppTheme.goldAccent),
            const SizedBox(height: 24),
            const Text(
              'Permissions & Location',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'We use location to calculate accurate prayer timings for your city and send timely Adhan reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        );
    }
  }

  Future<void> _handleNext() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Save settings
      await ref.read(prayerSettingsProvider.notifier).updateMethod(_selectedMethod);
      await ref.read(prayerSettingsProvider.notifier).updateMadhab(_selectedMadhab);

      // 2. Request Location & Notifications
      final locationService = ref.read(locationServiceProvider);
      await locationService.getCurrentOrSavedLocation();
      await NotificationService.instance.requestPermissions();

      // 3. Mark Onboarding completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        context.go('/');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
