import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Constants {
  // ── Server URLs ────────────────────────────────────────────────────────────
  static const String devUrl = 'https://server-production-20e4.up.railway.app';
  static const String prodUrl = 'https://server-production-20e4.up.railway.app';

  static String serverUrl = kReleaseMode ? prodUrl : devUrl;

  static const String _prefsKey = 'server_url_override';

  /// Call once at app startup
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = prefs.getString(_prefsKey);
      if (override != null) {
        serverUrl = override;
      }
    } catch (_) {}
  }

  static Future<void> setServerUrl(String url) async {
    serverUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
  }

  // ── Retention Policies ─────────────────────────────────────────────────────
  static const Duration historyLimit = Duration(hours: 24);
  static const Duration socketTimeout = Duration(seconds: 10);
}
