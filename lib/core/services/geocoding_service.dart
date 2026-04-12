import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Service for getting localized city names using OpenStreetMap Nominatim API
/// Free, no API key required, supports multiple languages
class GeocodingService {
  GeocodingService._();

  static final GeocodingService _instance = GeocodingService._();
  static GeocodingService get instance => _instance;

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

      if (response.statusCode == 200) {
        final data = json.decode(response.data.toString());

        if (data != null && data['address'] != null) {
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
