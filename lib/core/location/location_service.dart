import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final bool isManual;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    this.isManual = false,
  });
}

class LocationService {
  static const String keyLat = 'loc_latitude';
  static const String keyLng = 'loc_longitude';
  static const String keyCity = 'loc_city';
  static const String keyCountry = 'loc_country';
  static const String keyIsManual = 'loc_is_manual';

  String _detectCityFromCoordinates(double lat, double lng) {
    if (lat >= 24.0 && lat <= 25.5 && lng >= 66.0 && lng <= 67.8) {
      return 'Karachi';
    } else if (lat >= 31.0 && lat <= 32.0 && lng >= 74.0 && lng <= 75.0) {
      return 'Lahore';
    } else if (lat >= 33.3 && lat <= 33.9 && lng >= 72.8 && lng <= 73.3) {
      return 'Islamabad';
    } else if (lat >= 33.5 && lat <= 33.8 && lng >= 73.0 && lng <= 73.2) {
      return 'Rawalpindi';
    } else if (lat >= 31.3 && lat <= 31.6 && lng >= 73.0 && lng <= 73.2) {
      return 'Faisalabad';
    } else if (lat >= 30.1 && lat <= 30.3 && lng >= 71.4 && lng <= 71.6) {
      return 'Multan';
    } else if (lat >= 33.9 && lat <= 34.2 && lng >= 71.4 && lng <= 71.7) {
      return 'Peshawar';
    } else if (lat >= 30.1 && lat <= 30.3 && lng >= 66.9 && lng <= 67.1) {
      return 'Quetta';
    }
    if (lat > 20 && lat < 28 && lng > 60 && lng < 75) {
      return 'Karachi';
    }
    return AppConstants.defaultCity;
  }

  Future<LocationData> getCurrentOrSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isManual = prefs.getBool(keyIsManual) ?? false;

    if (isManual) {
      final double lat = prefs.getDouble(keyLat) ?? AppConstants.defaultLat;
      final double lng = prefs.getDouble(keyLng) ?? AppConstants.defaultLng;
      final String city = prefs.getString(keyCity) ?? AppConstants.defaultCity;
      final String country = prefs.getString(keyCountry) ?? AppConstants.defaultCountry;
      return LocationData(latitude: lat, longitude: lng, city: city, country: country, isManual: true);
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return getSavedLocationOrDefault(prefs);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return getSavedLocationOrDefault(prefs);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return getSavedLocationOrDefault(prefs);
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final detectedCity = _detectCityFromCoordinates(position.latitude, position.longitude);

      // Save GPS coordinates & detected city
      await prefs.setDouble(keyLat, position.latitude);
      await prefs.setDouble(keyLng, position.longitude);
      await prefs.setString(keyCity, detectedCity);
      await prefs.setString(keyCountry, AppConstants.defaultCountry);

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        city: detectedCity,
        country: AppConstants.defaultCountry,
        isManual: false,
      );
    } catch (_) {
      return getSavedLocationOrDefault(prefs);
    }
  }

  LocationData getSavedLocationOrDefault(SharedPreferences prefs) {
    final double lat = prefs.getDouble(keyLat) ?? AppConstants.defaultLat;
    final double lng = prefs.getDouble(keyLng) ?? AppConstants.defaultLng;
    final String city = prefs.getString(keyCity) ?? AppConstants.defaultCity;
    final String country = prefs.getString(keyCountry) ?? AppConstants.defaultCountry;
    final bool isManual = prefs.getBool(keyIsManual) ?? false;

    return LocationData(
      latitude: lat,
      longitude: lng,
      city: city,
      country: country,
      isManual: isManual,
    );
  }

  Future<void> saveManualLocation({
    required double latitude,
    required double longitude,
    required String city,
    required String country,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyLat, latitude);
    await prefs.setDouble(keyLng, longitude);
    await prefs.setString(keyCity, city);
    await prefs.setString(keyCountry, country);
    await prefs.setBool(keyIsManual, true);
  }

  Future<void> setAutoLocationMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsManual, false);
  }
}
