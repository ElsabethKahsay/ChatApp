class Constants {
  // ── Server URL ─────────────────────────────────────────────────────────────
  // Switch to your deployed URL once the backend is on Render/Railway.
  // Android emulator uses 10.0.2.2 to reach the Mac's localhost.
  // iOS simulator can use localhost directly.
  // Real device (same Wi-Fi): use your Mac's local IP, e.g. 192.168.1.42
  // static const String serverUrl = 'http://localhost:3000';       // Web browser
  // static const String serverUrl = 'http://10.0.2.2:3000';    // Android emulator
  static const String serverUrl = 'http://192.168.1.114:3000'; // Real device
  // static const String serverUrl = 'https://your-app.onrender.com'; // Production

  // ── Disappearing messages ──────────────────────────────────────────────────
  /// Default timer: received messages auto-delete after this duration.
  static const Duration disappearDuration = Duration(seconds: 30);

  /// Media auto-deletes from R2 after this long (set matching R2 lifecycle rule).
  static const Duration mediaExpiry = Duration(hours: 24);
}
