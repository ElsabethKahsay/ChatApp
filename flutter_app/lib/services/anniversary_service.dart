import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

/// Anniversary Service
/// 
/// Tracks special dates (friendship anniversary, etc.) and shows
/// confetti/badges on those dates.
class AnniversaryService {
  static const String _specialDateKey = 'special_anniversary_date';
  static const String _specialDateLabelKey = 'special_anniversary_label';
  static const String _lastShownKey = 'anniversary_last_shown';
  
  /// Set a special anniversary date
  static Future<void> setSpecialDate(DateTime date, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_specialDateKey, date.toIso8601String());
    await prefs.setString(_specialDateLabelKey, label);
  }
  
  /// Get special anniversary date
  static Future<DateTime?> getSpecialDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_specialDateKey);
    if (dateStr == null) return null;
    return DateTime.parse(dateStr);
  }
  
  /// Get special date label
  static Future<String> getSpecialDateLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_specialDateLabelKey) ?? 'Special Day';
  }
  
  /// Check if today is the anniversary
  static Future<bool> isAnniversaryToday() async {
    final specialDate = await getSpecialDate();
    if (specialDate == null) return false;
    
    final now = DateTime.now();
    return now.month == specialDate.month && now.day == specialDate.day;
  }
  
  /// Get years since special date
  static Future<int> getYearsSince() async {
    final specialDate = await getSpecialDate();
    if (specialDate == null) return 0;
    
    final now = DateTime.now();
    return now.year - specialDate.year;
  }
  
  /// Check if we should show anniversary celebration
  /// (returns true if it's anniversary and hasn't been shown today)
  static Future<bool> shouldShowAnniversary() async {
    if (!await isAnniversaryToday()) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_lastShownKey);
    
    if (lastShown == null) return true;
    
    final lastShownDate = DateTime.parse(lastShown);
    final now = DateTime.now();
    
    // Only show once per day
    return lastShownDate.year != now.year ||
           lastShownDate.month != now.month ||
           lastShownDate.day != now.day;
  }
  
  /// Mark anniversary as shown today
  static Future<void> markAnniversaryShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, DateTime.now().toIso8601String());
  }
  
  /// Get anniversary message
  static Future<String> getAnniversaryMessage() async {
    final label = await getSpecialDateLabel();
    final years = await getYearsSince();
    
    if (years == 0) {
      return 'Happy $label! 🎉';
    } else if (years == 1) {
      return 'Happy 1st $label! 🎉';
    } else if (years == 2) {
      return 'Happy 2nd $label! 🎉';
    } else if (years == 3) {
      return 'Happy 3rd $label! 🎉';
    } else {
      return 'Happy ${years}th $label! 🎉';
    }
  }
  
  /// Clear special date
  static Future<void> clearSpecialDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_specialDateKey);
    await prefs.remove(_specialDateLabelKey);
    await prefs.remove(_lastShownKey);
  }
  
  /// Get days until anniversary
  static Future<int> getDaysUntilAnniversary() async {
    final specialDate = await getSpecialDate();
    if (specialDate == null) return -1;
    
    final now = DateTime.now();
    var nextAnniversary = DateTime(now.year, specialDate.month, specialDate.day);
    
    if (nextAnniversary.isBefore(now)) {
      nextAnniversary = DateTime(now.year + 1, specialDate.month, specialDate.day);
    }
    
    return nextAnniversary.difference(now).inDays;
  }
}

/// Widget to show anniversary banner
class AnniversaryBanner extends StatelessWidget {
  final VoidCallback? onDismiss;

  const AnniversaryBanner({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AnniversaryService.getAnniversaryMessage(),
      builder: (context, snapshot) {
        final message = snapshot.data ?? 'Happy Anniversary! 🎉';
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A6D4), Color(0xFFCA8BF1)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Controller for anniversary confetti
class AnniversaryConfettiController {
  late ConfettiController _controller;
  
  void init() {
    _controller = ConfettiController(duration: const Duration(seconds: 5));
  }
  
  void dispose() {
    _controller.dispose();
  }
  
  void play() {
    _controller.play();
  }
  
  void stop() {
    _controller.stop();
  }
  
  ConfettiController get controller => _controller;
}
