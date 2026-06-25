import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';
import 'core/constants.dart';
import 'services/message_store.dart';
import 'services/socket_service.dart';
import 'crypto/key_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Constants.init();

  if (!kIsWeb) {
    await MessageStore.init();
    await [
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.notification,
    ].request();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final token = await KeyStore.getAuthToken();
    final userId = await KeyStore.getUserId();
    if (token != null && userId != null) {
      SocketService.connect(userId, token);
    }
  }

  runApp(const SecureChatApp());
}
