import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../crypto/key_store.dart';
import 'api_service.dart';

/// Push notification service using Firebase Cloud Messaging
class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Initialize Firebase and request permissions
  static Future<void> init() async {
    await Firebase.initializeApp();

    // Request permission on iOS/macOS
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configure foreground presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_onTokenRefresh);

    // Get initial token
    final token = await _fcm.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  /// Handle background messages
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print('📨 Background message: ${message.messageId}');
    // Background messages can be stored locally when app restarts
  }

  /// Register FCM token with backend
  static Future<void> _registerToken(String token) async {
    try {
      final authToken = await KeyStore.getAuthToken();
      if (authToken != null) {
        await ApiService.registerFcmToken(authToken, token);
        print('✅ FCM token registered');
      }
    } catch (e) {
      print('❌ Failed to register FCM token: $e');
    }
  }

  /// Handle token refresh
  static Future<void> _onTokenRefresh(String token) async {
    print('🔄 FCM token refreshed');
    await _registerToken(token);
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
