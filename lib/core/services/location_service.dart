import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'geocoding_service.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Service for getting user's location for prayer time calculations
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current position
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Get manual location that user saved
  Future<LocationData?> getManualLocation() async {
    final prefs = await _preferences;
    final latitude = prefs.getDouble('manual_latitude');
    final longitude = prefs.getDouble('manual_longitude');
    final cityName = prefs.getString('manual_city_name');

    if (latitude != null && longitude != null) {
      return LocationData(
        latitude: latitude,
        longitude: longitude,
        cityName: cityName ?? 'Custom Location',
      );
    }
    return null;
  }

  /// Set manual location
  Future<void> setManualLocation(double latitude, double longitude, String cityName) async {
    final prefs = await _preferences;
    await prefs.setDouble('manual_latitude', latitude);
    await prefs.setDouble('manual_longitude', longitude);
    await prefs.setString('manual_city_name', cityName);
    debugPrint('LocationService: Manual location set to $cityName ($latitude, $longitude)');
  }

  /// Clear manual location
  Future<void> clearManualLocation() async {
    final prefs = await _preferences;
    await prefs.remove('manual_latitude');
    await prefs.remove('manual_longitude');
    await prefs.remove('manual_city_name');
    debugPrint('LocationService: Manual location cleared');
  }

  // ── Desktop location persistence ──────────────────────────────────────────

  static const _kDesktopLat = 'desktop_ip_lat';
  static const _kDesktopLon = 'desktop_ip_lon';
  static const _kDesktopCity = 'desktop_ip_city';
  static const _kDesktopTs = 'desktop_ip_ts';
  static const _kDesktopCacheTtl = Duration(hours: 24);

  Future<LocationData?> _getCachedDesktopLocation() async {
    final prefs = await _preferences;
    final ts = prefs.getInt(_kDesktopTs);
    if (ts == null) return null;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _kDesktopCacheTtl) return null;
    final lat = prefs.getDouble(_kDesktopLat);
    final lon = prefs.getDouble(_kDesktopLon);
    final city = prefs.getString(_kDesktopCity) ?? 'Unknown City';
    if (lat == null || lon == null) return null;
    return LocationData(latitude: lat, longitude: lon, cityName: city);
  }

  Future<void> _saveDesktopLocation(LocationData loc) async {
    final prefs = await _preferences;
    await prefs.setDouble(_kDesktopLat, loc.latitude);
    await prefs.setDouble(_kDesktopLon, loc.longitude);
    await prefs.setString(_kDesktopCity, loc.cityName);
    await prefs.setInt(_kDesktopTs, DateTime.now().millisecondsSinceEpoch);
  }

  /// Tries IP geolocation in background and saves result for next app start.
  void _updateIpLocationInBackground() {
    Future.delayed(const Duration(seconds: 3), () async {
      final loc = await _getIpLocation();
      if (loc != null) {
        await _saveDesktopLocation(loc);
        debugPrint('LocationService: Background IP location saved: ${loc.cityName}');
      }
    });
  }

  /// Get location from IP address using HTTPS (desktop fallback).
  Future<LocationData?> _getIpLocation() async {
    try {
      debugPrint('LocationService: Trying IP-based geolocation...');
      // Use HTTPS to avoid Windows firewall/Defender blocking plain HTTP
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse('https://ipapi.co/json/'));
      request.headers.set('User-Agent', 'AuraApp/1.0');
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);
      debugPrint('LocationService: IP response received (${response.statusCode})');
      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        // ipapi.co returns latitude/longitude directly
        final lat = data['latitude'];
        final lon = data['longitude'];
        final city = data['city'] as String? ?? 'Unknown City';
        if (lat != null && lon != null) {
          debugPrint('LocationService: IP location: $city ($lat, $lon)');
          return LocationData(
            latitude: (lat as num).toDouble(),
            longitude: (lon as num).toDouble(),
            cityName: city,
          );
        }
      }
    } catch (e) {
      debugPrint('LocationService: IP geolocation failed: $e');
    }
    return null;
  }

  /// Get best location (GPS or manual)
  Future<LocationData> getBestLocation() async {
    // First try manual location
    final manualLocation = await getManualLocation();
    if (manualLocation != null) {
      debugPrint('LocationService: Using manual location: ${manualLocation.cityName}');
      return manualLocation;
    }

    // On desktop, use cached location first, then IP geolocation
    if (_isDesktop) {
      // Use recently saved location (within 24 h) to avoid HTTP request on every start
      final cached = await _getCachedDesktopLocation();
      if (cached != null) {
        debugPrint('LocationService: Using saved desktop location: ${cached.cityName}');
        return cached;
      }
      // Default to Mecca — user can set actual location in Settings
      debugPrint('LocationService: No cached location, using Mecca default');
      return LocationData(latitude: 21.4225, longitude: 39.8262, cityName: 'Mecca');
    }

    // Fall back to GPS
    debugPrint('LocationService: Getting GPS location...');
    try {
      final position = await getCurrentPosition();

      // Get city name from coordinates
      String cityName = 'Current Location';
      try {
        // Get language from SharedPreferences
        final prefs = await _preferences;
        final language = prefs.getString('language') ?? 'en';

        // First try OpenStreetMap Geocoding API (free, no API key)
        debugPrint('LocationService: Trying OpenStreetMap Geocoding API...');
        final osmCityName = await GeocodingService.instance.getLocalizedCityName(
          position.latitude,
          position.longitude,
          language,
        );

        if (osmCityName != null && osmCityName.isNotEmpty) {
          cityName = osmCityName;
          debugPrint('LocationService: City name from OpenStreetMap: $cityName');
        } else {
          // Fallback to local geocoding
          debugPrint('LocationService: Falling back to local geocoding');
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            // Try multiple fields for city name
            cityName = place.locality ??
                       place.subAdministrativeArea ??
                       place.administrativeArea ??
                       place.subLocality ??
                       place.name ??
                       'Current Location';
            debugPrint('LocationService: Geocoding result: locality=${place.locality}, subAdminArea=${place.subAdministrativeArea}, adminArea=${place.administrativeArea}');
            debugPrint('LocationService: Selected city name: $cityName (language: $language)');
          }
        }
      } catch (e) {
        debugPrint('LocationService: Could not get city name: $e');
        // Fallback: show coordinates if geocoding fails
        cityName = 'GPS Location';
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
      );
    } catch (e) {
      throw Exception('No location available. Please enable GPS or set a manual location.');
    }
  }

  /// Check if using manual location
  Future<bool> isUsingManualLocation() async {
    final manualLocation = await getManualLocation();
    return manualLocation != null;
  }
}

/// Get localized city name
String getLocalizedCityName(String cityName, String languageCode) {
  // Common city name mappings for major cities worldwide
  final Map<String, Map<String, String>> cityTranslations = {
    // Saudi Arabia
    'Riyadh': {'en': 'Riyadh', 'ar': 'الرياض'},
    'Makkah': {'en': 'Makkah', 'ar': 'مكة المكرمة'},
    'Mecca': {'en': 'Makkah', 'ar': 'مكة المكرمة'},
    'Madinah': {'en': 'Madinah', 'ar': 'المدينة المنورة'},
    'Medina': {'en': 'Madinah', 'ar': 'المدينة المنورة'},
    'Jeddah': {'en': 'Jeddah', 'ar': 'جدة'},
    'Dammam': {'en': 'Dammam', 'ar': 'الدمام'},
    'Khobar': {'en': 'Khobar', 'ar': 'الخبر'},
    'Tabuk': {'en': 'Tabuk', 'ar': 'تبوك'},
    'Abha': {'en': 'Abha', 'ar': 'أبها'},
    'Taif': {'en': 'Taif', 'ar': 'الطائف'},
    'Buraidah': {'en': 'Buraidah', 'ar': 'بريدة'},
    'Hail': {'en': 'Hail', 'ar': 'حائل'},
    'Najran': {'en': 'Najran', 'ar': 'نجران'},
    'Jizan': {'en': 'Jizan', 'ar': 'جازان'},
    'Sakaka': {'en': 'Sakaka', 'ar': 'سكاكا'},
    'Arar': {'en': 'Arar', 'ar': 'عرعر'},
    'Qassim': {'en': 'Qassim', 'ar': 'القصيم'},
    'Jouf': {'en': 'Jouf', 'ar': 'الجوف'},
    'Bahah': {'en': 'Bahah', 'ar': 'الباحة'},
    'Rafha': {'en': 'Rafha', 'ar': 'رفها'},
    'Kharj': {'en': 'Kharj', 'ar': 'الخرج'},
    'Hafar Al-Batin': {'en': 'Hafar Al-Batin', 'ar': 'حفر الباطن'},
    // Egypt
    'Cairo': {'en': 'Cairo', 'ar': 'القاهرة'},
    'Alexandria': {'en': 'Alexandria', 'ar': 'الإسكندرية'},
    'Giza': {'en': 'Giza', 'ar': 'الجيزة'},
    // UAE
    'Dubai': {'en': 'Dubai', 'ar': 'دبي'},
    'Abu Dhabi': {'en': 'Abu Dhabi', 'ar': 'أبو ظبي'},
    'Sharjah': {'en': 'Sharjah', 'ar': 'الشارقة'},
    // Kuwait
    'Kuwait City': {'en': 'Kuwait City', 'ar': 'مدينة الكويت'},
    // Bahrain
    'Manama': {'en': 'Manama', 'ar': 'المنامة'},
    // Qatar
    'Doha': {'en': 'Doha', 'ar': 'الدوحة'},
    // Oman
    'Muscat': {'en': 'Muscat', 'ar': 'مسقط'},
    // Jordan
    'Amman': {'en': 'Amman', 'ar': 'عمان'},
    // Lebanon
    'Beirut': {'en': 'Beirut', 'ar': 'بيروت'},
    // Syria
    'Damascus': {'en': 'Damascus', 'ar': 'دمشق'},
    'Aleppo': {'en': 'Aleppo', 'ar': 'حلب'},
    // Iraq
    'Baghdad': {'en': 'Baghdad', 'ar': 'بغداد'},
    'Basra': {'en': 'Basra', 'ar': 'البصرة'},
    // Morocco
    'Casablanca': {'en': 'Casablanca', 'ar': 'الدار البيضاء'},
    'Rabat': {'en': 'Rabat', 'ar': 'الرباط'},
    'Marrakech': {'en': 'Marrakech', 'ar': 'مراكش'},
    'Fes': {'en': 'Fes', 'ar': 'فاس'},
    // Tunisia
    'Tunis': {'en': 'Tunis', 'ar': 'تونس'},
    'Sfax': {'en': 'Sfax', 'ar': 'صفاقس'},
    // Algeria
    'Algiers': {'en': 'Algiers', 'ar': 'الجزائر'},
    'Oran': {'en': 'Oran', 'ar': 'وهران'},
    // Turkey
    'Istanbul': {'en': 'Istanbul', 'ar': 'إسطنبول'},
    'Ankara': {'en': 'Ankara', 'ar': 'أنقرة'},
    'Izmir': {'en': 'Izmir', 'ar': 'إزمير'},
    // Yemen
    'Sanaa': {'en': 'Sanaa', 'ar': 'صنعاء'},
    'Aden': {'en': 'Aden', 'ar': 'عدن'},
    // Sudan
    'Khartoum': {'en': 'Khartoum', 'ar': 'الخرطوم'},
    'Omdurman': {'en': 'Omdurman', 'ar': 'أمدورمان'},
    // Libya
    'Tripoli': {'en': 'Tripoli', 'ar': 'طرابلس'},
    'Benghazi': {'en': 'Benghazi', 'ar': 'بنغازي'},
    // Palestine
    'Jerusalem': {'en': 'Jerusalem', 'ar': 'القدس'},
    'Gaza': {'en': 'Gaza', 'ar': 'غزة'},
    'Ramallah': {'en': 'Ramallah', 'ar': 'رام الله'},
    // Other major cities
    'London': {'en': 'London', 'ar': 'لندن'},
    'Paris': {'en': 'Paris', 'ar': 'باريس'},
    'New York': {'en': 'New York', 'ar': 'نيويورك'},
    'Berlin': {'en': 'Berlin', 'ar': 'برلين'},
    'Rome': {'en': 'Rome', 'ar': 'روما'},
    'Madrid': {'en': 'Madrid', 'ar': 'مدريد'},
    'Moscow': {'en': 'Moscow', 'ar': 'موسكو'},
    'Tokyo': {'en': 'Tokyo', 'ar': 'طوكيو'},
    'Beijing': {'en': 'Beijing', 'ar': 'بكين'},
    'Delhi': {'en': 'Delhi', 'ar': 'دلهي'},
    'Mumbai': {'en': 'Mumbai', 'ar': 'مومباي'},
    'Karachi': {'en': 'Karachi', 'ar': 'كراتشي'},
    'Istanbul': {'en': 'Istanbul', 'ar': 'إسطنبول'},
    'Lahore': {'en': 'Lahore', 'ar': 'لاهور'},
    'Bangkok': {'en': 'Bangkok', 'ar': 'بانكوك'},
    'Tehran': {'en': 'Tehran', 'ar': 'طهران'},
  };

  // Check if city name has translation
  if (cityTranslations.containsKey(cityName)) {
    return cityTranslations[cityName]![languageCode] ?? cityName;
  }

  // Return original if no translation found
  return cityName;
}

/// Simple location data class
class LocationData {
  final double latitude;
  final double longitude;
  final String cityName;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.cityName,
  });

  @override
  String toString() => '$cityName ($latitude, $longitude)';
}
