import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/message_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for push notifications (may fail on web without config)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization skipped: $e');
  }

  // Initialize secure message storage (may fail on web - uses SQLite)
  try {
    await MessageStore.init();
  } catch (e) {
    debugPrint('MessageStore initialization skipped: $e');
  }

  runApp(const SecureChatApp());
}
