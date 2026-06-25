import 'package:shared_preferences/shared_preferences.dart';
import 'message_store.dart';

/// Service for panic mode - quick exit and message clearing
class PanicModeService {
  static const String _panicEnabledKey = 'panic_mode_enabled';
  static const String _panicTriggerKey = 'panic_trigger_method';

  /// Enable panic mode
  static Future<void> enablePanicMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_panicEnabledKey, true);
  }

  /// Disable panic mode
  static Future<void> disablePanicMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_panicEnabledKey, false);
  }

  /// Check if panic mode is enabled
  static Future<bool> isPanicModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_panicEnabledKey) ?? false;
  }

  /// Trigger panic mode - clear all messages
  static Future<void> triggerPanic() async {
    // Clear all messages
    await MessageStore.clearAll();
  }

  /// Set panic trigger method (triple tap, shake, etc)
  static Future<void> setPanicTrigger(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_panicTriggerKey, method);
  }

  /// Get panic trigger method
  static Future<String> getPanicTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_panicTriggerKey) ?? 'triple_tap';
  }
}
