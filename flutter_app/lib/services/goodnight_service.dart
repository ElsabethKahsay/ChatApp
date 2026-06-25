import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Goodnight Autofade Service
/// 
/// Gradually darkens the app background as night progresses.
/// Starts dimming after 9 PM until user-set bedtime.
class GoodnightService {
  static const String _enabledKey = 'goodnight_enabled';
  static const String _bedtimeKey = 'goodnight_bedtime';
  static const String _dimmingStartKey = 'goodnight_dimming_start';
  
  // Default times
  static const int defaultDimmingStartHour = 21; // 9 PM
  static const int defaultBedtimeHour = 23; // 11 PM
  
  /// Check if goodnight mode is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
  
  /// Enable/disable goodnight mode
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
  
  /// Get bedtime hour
  static Future<int> getBedtimeHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bedtimeKey) ?? defaultBedtimeHour;
  }
  
  /// Set bedtime hour
  static Future<void> setBedtimeHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bedtimeKey, hour);
  }
  
  /// Get dimming start hour
  static Future<int> getDimmingStartHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dimmingStartKey) ?? defaultDimmingStartHour;
  }
  
  /// Set dimming start hour
  static Future<void> setDimmingStartHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dimmingStartKey, hour);
  }
  
  /// Calculate current dimming factor (0.0 to 1.0)
  /// 0.0 = no dimming (full brightness)
  /// 1.0 = maximum dimming (darkest)
  static Future<double> getCurrentDimmingFactor() async {
    if (!await isEnabled()) return 0.0;
    
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60);
    
    final dimmingStart = await getDimmingStartHour();
    final bedtime = await getBedtimeHour();
    
    // If before dimming start, no dimming
    if (currentHour < dimmingStart) return 0.0;
    
    // If after bedtime, maximum dimming
    if (currentHour >= bedtime) return 1.0;
    
    // Calculate progressive dimming
    final totalDimmingHours = bedtime - dimmingStart;
    final hoursIntoDimming = currentHour - dimmingStart;
    
    // Use curved animation for natural feel
    final t = hoursIntoDimming / totalDimmingHours;
    return _easeInOutCubic(t);
  }
  
  /// Ease-in-out cubic curve for smooth dimming
  static double _easeInOutCubic(double t) {
    if (t < 0.5) {
      return 4 * t * t * t;
    } else {
      return 1 - ((-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2)) / 2;
    }
  }
  
  /// Get current brightness overlay opacity
  static Future<double> getOverlayOpacity() async {
    final dimmingFactor = await getCurrentDimmingFactor();
    // Max opacity of 0.6 (60% dark)
    return dimmingFactor * 0.6;
  }
  
  /// Get brightness level for screen (inverse of dimming)
  static Future<double> getBrightnessLevel() async {
    final dimmingFactor = await getCurrentDimmingFactor();
    // Brightness goes from 1.0 to 0.4
    return 1.0 - (dimmingFactor * 0.6);
  }
  
  /// Format hour for display (e.g., 21 -> "9:00 PM")
  static String formatHour(int hour) {
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:00 $period';
  }
  
  /// Check if currently in dimming period
  static Future<bool> isInDimmingPeriod() async {
    if (!await isEnabled()) return false;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    final dimmingStart = await getDimmingStartHour();
    final bedtime = await getBedtimeHour();
    
    return currentHour >= dimmingStart && currentHour < bedtime;
  }
  
  /// Stream for dimming updates (updates every minute)
  static Stream<double> dimmingStream() async* {
    while (true) {
      yield await getOverlayOpacity();
      await Future.delayed(const Duration(minutes: 1));
    }
  }
}

/// Widget that applies goodnight dimming overlay
class GoodnightOverlay extends StatefulWidget {
  final Widget child;
  
  const GoodnightOverlay({super.key, required this.child});
  
  @override
  State<GoodnightOverlay> createState() => _GoodnightOverlayState();
}

class _GoodnightOverlayState extends State<GoodnightOverlay> {
  double _overlayOpacity = 0.0;
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _updateDimming();
    // Update every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateDimming();
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _updateDimming() async {
    final opacity = await GoodnightService.getOverlayOpacity();
    if (mounted && opacity != _overlayOpacity) {
      setState(() => _overlayOpacity = opacity);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_overlayOpacity > 0)
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              color: Colors.black.withValues(alpha: _overlayOpacity),
            ),
          ),
      ],
    );
  }
}

/// Widget to show goodnight indicator
class GoodnightIndicator extends StatelessWidget {
  const GoodnightIndicator({super.key});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!;
        final isEnabled = data['enabled'] as bool;
        final isDimming = data['dimming'] as bool;
        final opacity = data['opacity'] as double;
        
        if (!isEnabled || !isDimming) return const SizedBox.shrink();
        
        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: Colors.amber[300],
                ),
                const SizedBox(width: 6),
                Text(
                  'Night mode ${(opacity * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<Map<String, dynamic>> _getStatus() async {
    return {
      'enabled': await GoodnightService.isEnabled(),
      'dimming': await GoodnightService.isInDimmingPeriod(),
      'opacity': await GoodnightService.getOverlayOpacity(),
    };
  }
}
