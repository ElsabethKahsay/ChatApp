import 'package:flutter/material.dart';

class ScreenshotService with WidgetsBindingObserver {
  static final ScreenshotService _instance = ScreenshotService._();
  factory ScreenshotService() => _instance;
  ScreenshotService._();

  bool _secure = false;
  final List<void Function()> _overlayListeners = [];

  void enableScreenshotPrevention() {
    _secure = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void disableScreenshotPrevention() {
    _secure = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  void addOverlayListener(void Function() callback) {
    _overlayListeners.add(callback);
  }

  void removeOverlayListener(void Function() callback) {
    _overlayListeners.remove(callback);
  }

  bool get isSecure => _secure;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _secure) {
      for (final listener in _overlayListeners) {
        listener();
      }
    }
  }
}
