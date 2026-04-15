import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // ── Server URL ─────────────────────────────────────────────────────────────
  // IMPORTANT: This MUST be your development machine's local IP address
  // when testing on a real Android device.
  //
  // 1. Find your IP: On Mac, run `ipconfig getifaddr en0` in Terminal
  // 2. Update this value to match, e.g., 'http://192.168.1.114:3000'
  // 3. Ensure your phone and computer are on the same Wi-Fi network
  // 4. On Mac, disable firewall or allow port 3000: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add node`
  //
  // Configuration options:
  // static const String serverUrl = 'http://127.0.0.1:3000';       // Web browser only
  // static const String serverUrl = 'http://10.0.2.2:3000';       // Android emulator only
  static const String serverUrl = kIsWeb ? 'http://localhost:3000' : 'http://192.168.1.114:3000'; // UPDATE THIS IP for real devices!
  // static const String serverUrl = 'https://your-app.onrender.com'; // Production

  // ── Disappearing messages ──────────────────────────────────────────────────
  /// Default timer: received messages auto-delete after this duration.
  static const Duration disappearDuration = Duration(seconds: 60);

  /// Media auto-deletes from R2 after this long (set matching R2 lifecycle rule).
  static const Duration mediaExpiry = Duration(hours: 24);
}
