import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/core/theme/app_theme.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';

class QiblaCompassScreen extends ConsumerWidget {
  const QiblaCompassScreen({super.key});

  /// Calculates the great-circle Qibla bearing in degrees relative to True North
  double _calculateQiblaBearing(double userLat, double userLng) {
    double lat1 = userLat * (math.pi / 180.0);
    double lng1 = userLng * (math.pi / 180.0);
    double lat2 = AppConstants.kaabaLatitude * (math.pi / 180.0);
    double lng2 = AppConstants.kaabaLongitude * (math.pi / 180.0);

    double dLng = lng2 - lng1;

    double y = math.sin(dLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    double bearing = math.atan2(y, x);
    bearing = bearing * (180.0 / math.pi);
    return (bearing + 360.0) % 360.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationDataProvider);
    final location = locationAsync.valueOrNull;

    final double userLat = location?.latitude ?? AppConstants.defaultLat;
    final double userLng = location?.longitude ?? AppConstants.defaultLng;
    final double qiblaBearing = _calculateQiblaBearing(userLat, userLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Direction Compass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading location: $err')),
        data: (loc) {
          return StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildNoSensorFallback(context, qiblaBearing);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              double? heading = snapshot.data?.heading;

              // Sensor not available on device / emulator
              if (heading == null) {
                return _buildNoSensorFallback(context, qiblaBearing);
              }

              // Calculate angle to align compass dial toward Qibla
              double headingRad = heading * (math.pi / 180.0);
              double qiblaRad = qiblaBearing * (math.pi / 180.0);
              double diffAngle = qiblaRad - headingRad;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Location Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/kaaba_bg.jpg'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Color(0xB3000000),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.goldAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location: ${loc.city}, ${loc.country}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                ),
                                Text(
                                  'Qibla Angle: ${qiblaBearing.toStringAsFixed(1)}° Clockwise from North',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Calibration Advice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.goldAccent, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Rotate device in a figure-8 motion to calibrate magnetic compass sensors.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Visual Compass Dial
                    SizedBox(
                      height: 260,
                      width: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Rotating Compass Ring
                          Transform.rotate(
                            angle: -headingRad,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.emeraldPrimary, width: 4),
                                color: Theme.of(context).cardColor,
                              ),
                              child: const Center(
                                child: Text('N', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                              ),
                            ),
                          ),

                          // Qibla Pointer Arrow
                          Transform.rotate(
                            angle: diffAngle,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation, size: 80, color: AppTheme.goldAccent),
                                SizedBox(height: 4),
                                Text(
                                  'KAABA',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldAccent, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Heading: ${heading.toStringAsFixed(0)}°',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoSensorFallback(BuildContext context, double qiblaBearing) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Magnetometer Sensor Unavailable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Your device does not support live compass sensors. Qibla bearing to Makkah from your location is:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.emeraldPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${qiblaBearing.toStringAsFixed(1)}° Clockwise from North',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
