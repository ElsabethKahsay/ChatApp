import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../crypto/key_store.dart';

class ProfileService {
  static const Duration _timeout = Duration(seconds: 30);

  /// Get current user's full profile
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/profile'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get profile: ${response.statusCode}');
  }

  /// Get another user's public profile
  static Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get profile: ${response.statusCode}');
  }

  /// Update birthday
  static Future<void> updateBirthday(DateTime bday) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('${Constants.serverUrl}/api/profile/birthday'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'bday': bday.toIso8601String()}),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to update birthday');
    }
  }

  /// Update mood
  static Future<void> updateMood(String mood) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('${Constants.serverUrl}/api/profile/mood'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'mood': mood}),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to update mood');
    }
  }

  /// Update aura color
  static Future<void> updateAuraColor(String hexColor) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('${Constants.serverUrl}/api/profile/aura'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'auraColor': hexColor}),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to update aura color');
    }
  }

  /// Update city
  static Future<void> updateCity(String city) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('${Constants.serverUrl}/api/profile/city'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'city': city}),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to update city');
    }
  }

  /// Fetch random fact from API
  static Future<String> fetchRandomFact() async {
    try {
      final response = await http.get(
        Uri.parse('https://uselessfacts.jsph.pl/random.json?language=en'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? 'No fact available';
      }
      throw Exception('Failed to fetch fact');
    } catch (e) {
      throw Exception('Failed to fetch fact: $e');
    }
  }

  /// Fetch weather for city
  static Future<Map<String, dynamic>> fetchWeather(String city) async {
    // Using Open-Meteo (free, no API key required)
    try {
      // First, geocode the city
      final geoResponse = await http.get(
        Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1',
        ),
      ).timeout(_timeout);

      if (geoResponse.statusCode != 200) {
        throw Exception('Failed to find city');
      }

      final geoData = jsonDecode(geoResponse.body);
      if (geoData['results'] == null || geoData['results'].isEmpty) {
        throw Exception('City not found');
      }

      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      final cityName = geoData['results'][0]['name'];

      // Get weather data
      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&hourly=temperature_2m',
        ),
      ).timeout(_timeout);

      if (weatherResponse.statusCode == 200) {
        final data = jsonDecode(weatherResponse.body);
        return {
          'city': cityName,
          'temperature': data['current']['temperature_2m'],
          'unit': data['current_units']['temperature_2m'],
          'weatherCode': data['current']['weather_code'],
        };
      }
      throw Exception('Failed to fetch weather');
    } catch (e) {
      throw Exception('Failed to fetch weather: $e');
    }
  }

  /// Get weather emoji from WMO weather code
  static String getWeatherEmoji(int code) {
    // WMO Weather interpretation codes
    if (code == 0) return '☀️'; // Clear sky
    if (code >= 1 && code <= 3) return '🌤️'; // Mainly clear, partly cloudy, overcast
    if (code >= 45 && code <= 48) return '🌫️'; // Fog
    if (code >= 51 && code <= 55) return '🌧️'; // Drizzle
    if (code >= 61 && code <= 65) return '🌧️'; // Rain
    if (code >= 71 && code <= 77) return '🌨️'; // Snow
    if (code >= 80 && code <= 82) return '🌦️'; // Rain showers
    if (code >= 95 && code <= 99) return '⛈️'; // Thunderstorm
    return '🌡️';
  }
}
