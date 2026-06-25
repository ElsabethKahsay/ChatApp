import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Period Tracker Service
/// 
/// Tracks menstrual cycle dates locally.
/// Data is never synced to the backend - completely private.
/// On web, uses localStorage; on native, uses SharedPreferences.
class PeriodTrackerService {
  static const String _cycleDataKey = 'period_cycle_data';
  static const String _enabledKey = 'period_tracker_enabled';
  
  /// Average cycle length (default 28 days)
  static const int defaultCycleLength = 28;
  
  /// Average period length (default 5 days)
  static const int defaultPeriodLength = 5;
  
  /// Check if period tracker is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
  
  /// Enable/disable period tracker
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
  
  /// Get all logged cycle data
  static Future<List<PeriodCycle>> getCycleData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_cycleDataKey);
      if (data == null) return [];
      
      final jsonList = jsonDecode(data) as List;
      return jsonList.map((json) => PeriodCycle.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading period data: $e');
      return [];
    }
  }
  
  /// Save cycle data
  static Future<void> saveCycleData(List<PeriodCycle> cycles) async {
    try {
      final jsonList = cycles.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cycleDataKey, jsonString);
    } catch (e) {
      debugPrint('Error saving period data: $e');
      throw Exception('Failed to save period data');
    }
  }
  
  /// Log a new period start date
  static Future<void> logPeriodStart(
    DateTime startDate, {
    int? periodLength,
    String? notes,
    List<String>? symptoms,
  }) async {
    final cycles = await getCycleData();
    
    // Check if there's already a cycle for this month
    final existingIndex = cycles.indexWhere((c) => 
      c.startDate.month == startDate.month && 
      c.startDate.year == startDate.year
    );
    
    final newCycle = PeriodCycle(
      startDate: startDate,
      periodLength: periodLength ?? defaultPeriodLength,
      notes: notes,
      symptoms: symptoms,
    );
    
    if (existingIndex >= 0) {
      cycles[existingIndex] = newCycle;
    } else {
      cycles.add(newCycle);
    }
    
    // Sort by date
    cycles.sort((a, b) => a.startDate.compareTo(b.startDate));
    
    await saveCycleData(cycles);
  }
  
  /// Delete a cycle entry
  static Future<void> deleteCycle(DateTime startDate) async {
    final cycles = await getCycleData();
    cycles.removeWhere((c) => 
      c.startDate.day == startDate.day &&
      c.startDate.month == startDate.month &&
      c.startDate.year == startDate.year
    );
    await saveCycleData(cycles);
  }
  
  /// Calculate next predicted period
  static Future<PeriodPrediction?> predictNextPeriod() async {
    final cycles = await getCycleData();
    if (cycles.isEmpty) return null;
    
    // Calculate average cycle length from last 3-6 cycles
    final avgCycleLength = _calculateAverageCycleLength(cycles);
    
    final lastCycle = cycles.last;
    final nextPeriodStart = lastCycle.startDate.add(Duration(days: avgCycleLength));
    
    // Calculate fertile window (typically 14 days before next period, 5-day window)
    final ovulationDay = nextPeriodStart.subtract(const Duration(days: 14));
    final fertileWindowStart = ovulationDay.subtract(const Duration(days: 5));
    final fertileWindowEnd = ovulationDay.add(const Duration(days: 1));
    
    // Calculate days until next period
    final daysUntil = nextPeriodStart.difference(DateTime.now()).inDays;
    
    return PeriodPrediction(
      nextPeriodDate: nextPeriodStart,
      fertileWindowStart: fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd,
      daysUntilPeriod: daysUntil,
      averageCycleLength: avgCycleLength,
    );
  }
  
  /// Calculate average cycle length from historical data
  static int _calculateAverageCycleLength(List<PeriodCycle> cycles) {
    if (cycles.length < 2) return defaultCycleLength;
    
    // Use last 6 cycles max
    final recentCycles = cycles.length > 6 
        ? cycles.sublist(cycles.length - 6) 
        : cycles;
    
    int totalDays = 0;
    int count = 0;
    
    for (int i = 1; i < recentCycles.length; i++) {
      final diff = recentCycles[i].startDate.difference(recentCycles[i-1].startDate).inDays;
      if (diff > 20 && diff < 40) { // Sanity check
        totalDays += diff;
        count++;
      }
    }
    
    return count > 0 ? (totalDays / count).round() : defaultCycleLength;
  }
  
  /// Get current cycle day (1-based)
  static Future<int?> getCurrentCycleDay() async {
    final cycles = await getCycleData();
    if (cycles.isEmpty) return null;
    
    final lastCycle = cycles.last;
    final daysSinceStart = DateTime.now().difference(lastCycle.startDate).inDays;
    
    return daysSinceStart + 1;
  }
  
  /// Check if currently in period
  static Future<bool> isCurrentlyInPeriod() async {
    final cycles = await getCycleData();
    if (cycles.isEmpty) return false;
    
    final lastCycle = cycles.last;
    final daysSinceStart = DateTime.now().difference(lastCycle.startDate).inDays;
    
    return daysSinceStart >= 0 && daysSinceStart < lastCycle.periodLength;
  }
  
  /// Format date for display
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  /// Get days in month
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
  
  /// Import cycle data from Flo app CSV export
  /// Flo CSV format typically contains: Date, Period flow, etc.
  static Future<int> importFromFlo(String csvData) async {
    try {
      final cycles = <PeriodCycle>[];
      final lines = csvData.split('\n');
      
      // Skip header row and process each line
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final columns = line.split(',');
        if (columns.isEmpty) continue;
        
        // Parse date (Flo typically uses dd.MM.yyyy or MM/dd/yyyy format)
        final dateStr = columns[0].trim().replaceAll('"', '');
        DateTime? date = _parseFloDate(dateStr);
        
        if (date == null) continue;
        
        // Check if this line indicates a period (has flow data)
        final hasPeriod = columns.length > 1 && columns[1].trim().isNotEmpty;
        
        if (hasPeriod) {
          // Check if this continues an existing cycle or starts a new one
          final lastCycle = cycles.isNotEmpty ? cycles.last : null;
          final daysSinceLast = lastCycle != null 
              ? date.difference(lastCycle.startDate).inDays 
              : null;
          
          // If more than 7 days since last period, start a new cycle
          if (daysSinceLast == null || daysSinceLast > 7) {
            cycles.add(PeriodCycle(
              startDate: date,
              periodLength: 5,
            ));
          }
        }
      }
      
      // Merge with existing data (avoid duplicates)
      final existingCycles = await getCycleData();
      final merged = _mergeCycles(existingCycles, cycles);
      
      await saveCycleData(merged);
      return cycles.length;
    } catch (e) {
      debugPrint('Error importing Flo data: $e');
      throw Exception('Failed to import Flo data: $e');
    }
  }
  
  /// Parse date from Flo export (handles multiple formats)
  static DateTime? _parseFloDate(String dateStr) {
    try {
      // Try dd.MM.yyyy format
      if (dateStr.contains('.')) {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
      
      // Try MM/dd/yyyy format
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }
      
      // Try ISO format
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }
  
  /// Merge cycles avoiding duplicates
  static List<PeriodCycle> _mergeCycles(
    List<PeriodCycle> existing, 
    List<PeriodCycle> imported
  ) {
    final merged = List<PeriodCycle>.from(existing);
    
    for (final importedCycle in imported) {
      // Check if this cycle already exists
      final exists = merged.any((c) =>
        c.startDate.day == importedCycle.startDate.day &&
        c.startDate.month == importedCycle.startDate.month &&
        c.startDate.year == importedCycle.startDate.year
      );
      
      if (!exists) {
        merged.add(importedCycle);
      }
    }
    
    // Sort by date
    merged.sort((a, b) => a.startDate.compareTo(b.startDate));
    return merged;
  }
  
  /// Clear all cycle data (start from 0)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cycleDataKey);
    debugPrint('All period tracker data cleared');
  }
}

/// Represents a single period cycle
class PeriodCycle {
  final DateTime startDate;
  final int periodLength;
  final DateTime? endDate;
  final String? notes;
  final List<String>? symptoms;

  PeriodCycle({
    required this.startDate,
    this.periodLength = PeriodTrackerService.defaultPeriodLength,
    this.endDate,
    this.notes,
    this.symptoms,
  });

  factory PeriodCycle.fromJson(Map<String, dynamic> json) {
    return PeriodCycle(
      startDate: DateTime.parse(json['startDate']),
      periodLength: json['periodLength'] ?? PeriodTrackerService.defaultPeriodLength,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      notes: json['notes'],
      symptoms: json['symptoms'] != null 
          ? List<String>.from(json['symptoms']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'periodLength': periodLength,
      'endDate': endDate?.toIso8601String(),
      'notes': notes,
      'symptoms': symptoms,
    };
  }

  DateTime get expectedEndDate => startDate.add(Duration(days: periodLength - 1));
}

/// Prediction for next period
class PeriodPrediction {
  final DateTime nextPeriodDate;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final int daysUntilPeriod;
  final int averageCycleLength;

  PeriodPrediction({
    required this.nextPeriodDate,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.daysUntilPeriod,
    required this.averageCycleLength,
  });

  bool get isInFertileWindow {
    final now = DateTime.now();
    return now.isAfter(fertileWindowStart) && now.isBefore(fertileWindowEnd);
  }

  String get fertileWindowText {
    return '${PeriodTrackerService.formatDate(fertileWindowStart)} - ${PeriodTrackerService.formatDate(fertileWindowEnd)}';
  }
}
