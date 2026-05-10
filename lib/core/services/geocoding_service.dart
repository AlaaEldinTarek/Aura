import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Service for getting localized city names using OpenStreetMap Nominatim API
/// Free, no API key required, supports multiple languages
class GeocodingService {
  GeocodingService._();

  static final GeocodingService _instance = GeocodingService._();
  static GeocodingService get instance => _instance;

  /// Search for a city by name using OpenStreetMap Nominatim.
  /// Returns a list of [CityResult] with coordinates and display names.
  Future<List<CityResult>> searchCity(String query, String languageCode) async {
    if (query.trim().length < 2) return [];
    try {
      final acceptLanguage = languageCode == 'ar' ? 'ar-SA' : 'en-US';
      final encoded = Uri.encodeQueryComponent(query);
      final url = 'https://nominatim.openstreetmap.org/search'
          '?format=json'
          '&q=$encoded'
          '&addressdetails=1'
          '&limit=6'
          '&featuretype=city';

      final response = await Dio().get(
        url,
        options: Options(headers: {
          'Accept': 'application/json',
          'Accept-Language': acceptLanguage,
          'User-Agent': 'Aura-Prayer-App',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.data is List) {
        final results = <CityResult>[];
        for (final item in response.data as List) {
          final m = item as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;
          final address = m['address'] as Map<String, dynamic>? ?? {};
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              m['name'] ??
              '';
          final country = address['country'] ?? '';
          if (city.toString().isEmpty) continue;
          results.add(CityResult(
            cityName: city.toString(),
            country: country.toString(),
            latitude: lat,
            longitude: lon,
          ));
        }
        return results;
      }
    } catch (e) {
      debugPrint('GeocodingService: Search error - $e');
    }
    return [];
  }

  /// Get localized city name from coordinates using OpenStreetMap Nominatim
  /// [latitude] - Latitude
  /// [longitude] - Longitude
  /// [languageCode] - Language code ('ar' for Arabic, 'en' for English)
  /// Returns localized city name or null if failed
  Future<String?> getLocalizedCityName(
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    try {
      // Map language codes for Nominatim
      // Nominatim uses standard language codes
      final acceptLanguage = languageCode == 'ar' ? 'ar-SA' : 'en-US';

      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=$latitude'
          '&lon=$longitude'
          '&zoom=10'
          '&addressdetails=1';

      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Accept-Language': acceptLanguage,
            'User-Agent': 'Aura-Prayer-App',
          },
        ),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : json.decode(response.data.toString()) as Map<String, dynamic>;

        if (data['address'] != null) {
          final address = data['address'] as Map<String, dynamic>;

          // Try to get city name in priority order
          final cityName = address['city'] ??
                           address['town'] ??
                           address['village'] ??
                           address['suburb'] ??
                           address['county'] ??
                           address['state'] ??
                           address['state_district'];

          if (cityName != null && cityName.isNotEmpty) {
            debugPrint('GeocodingService: Found city: $cityName (language: $languageCode)');
            return cityName.toString();
          }
        }
      }

      debugPrint('GeocodingService: No results found');
      return null;
    } catch (e) {
      debugPrint('GeocodingService: Error getting city name: $e');
      return null;
    }
  }
}

class CityResult {
  final String cityName;
  final String country;
  final double latitude;
  final double longitude;

  const CityResult({
    required this.cityName,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get displayName =>
      country.isNotEmpty ? '$cityName, $country' : cityName;
}
