import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../crypto/key_store.dart';
import 'api_service.dart';

class FcmService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      // 1. Request permissions for Android 13+
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get the token
        String? token = await _fcm.getToken();
        if (token != null) await _registerWithBackend(token);

        // 3. Listen for token refreshes
        _fcm.onTokenRefresh.listen(_registerWithBackend);
      }
    } catch (e) {
      debugPrint('FCM Init Error: $e');
    }
  }

  static Future<void> _registerWithBackend(String token) async {
    final authToken = await KeyStore.getAuthToken();
    if (authToken != null) {
      try {
        await ApiService.registerFcmToken(authToken, token);
        debugPrint('🚀 FCM Token Registered with Production Backend');
      } catch (e) {
        debugPrint('❌ FCM Registration Failed: $e');
      }
    }
  }
}
