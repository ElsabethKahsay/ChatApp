import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/theme.dart';
import '../services/period_tracker_service.dart';

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  List<PeriodCycle> _cycles = [];
  PeriodPrediction? _prediction;
  bool _isLoading = true;
  bool _isEnabled = false;
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final enabled = await PeriodTrackerService.isEnabled();
      final cycles = await PeriodTrackerService.getCycleData();
      final prediction = await PeriodTrackerService.predictNextPeriod();
      
      setState(() {
        _isEnabled = enabled;
        _cycles = cycles;
        _prediction = prediction;
      });
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEnabled() async {
    setState(() => _isEnabled = !_isEnabled);
    await PeriodTrackerService.setEnabled(_isEnabled);
    if (_isEnabled) {
      _showSuccess('Period tracker enabled!');
    }
  }

  Future<void> _logPeriod(DateTime date) async {
    final notesCtrl = TextEditingController();
    final symptomsCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Period — ${PeriodTrackerService.formatDate(date)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Cramps, headaches, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symptomsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Symptoms (comma-separated)',
                  hintText: 'fatigue, bloating, cravings',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'notes': notesCtrl.text.trim(),
              'symptoms': symptomsCtrl.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
            ),
            child: const Text('Log Period'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      final symptoms = result['symptoms']?.isNotEmpty == true
          ? result['symptoms']!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      await PeriodTrackerService.logPeriodStart(
        date,
        notes: result['notes'],
        symptoms: symptoms,
      );
      await _loadData();
      _showSuccess('Period logged!');
    } catch (e) {
      _showError('Failed to log period: $e');
    }
  }

  Future<void> _deleteCycle(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This will remove the period log for this date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await PeriodTrackerService.deleteCycle(date);
        await _loadData();
        _showSuccess('Cycle deleted');
      } catch (e) {
        _showError('Failed to delete cycle: $e');
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showImportDialog() {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from Flo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your Flo CSV export data below:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Open Flo app\n2. Go to Profile → Export data\n3. Copy the CSV content\n4. Paste it here',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Date,Flow,...\n01.01.2024,Heavy,...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final csvData = textController.text.trim();
                if (csvData.isEmpty) {
                  _showError('Please paste CSV data');
                  return;
                }
                final imported = await PeriodTrackerService.importFromFlo(csvData);
                await _loadData();
                _showSuccess('Imported $imported cycles from Flo!');
              } catch (e) {
                _showError('Import failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your period tracking data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PeriodTrackerService.clearAllData();
                await _loadData();
                _showSuccess('All data cleared. Starting fresh!');
              } catch (e) {
                _showError('Failed to clear data: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Period Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryPurple,
        actions: [
          if (_isEnabled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'import') {
                  _showImportDialog();
                } else if (value == 'clear') {
                  _showClearDataDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, color: AppTheme.primaryPurple),
                      SizedBox(width: 8),
                      Text('Import from Flo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear All Data'),
                    ],
                  ),
                ),
              ],
            ),
          Switch(
            value: _isEnabled,
            onChanged: (_) => _toggleEnabled(),
            activeThumbColor: Colors.white,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_isEnabled
                ? _buildDisabledView()
                : _buildTrackerView(),
      ),
    );
  }

  Widget _buildDisabledView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Period Tracker is Disabled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.isDarkMode ? AppTheme.darkText : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Enable it using the toggle in the top right. Your data is stored securely on your device only.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Prediction Card
        if (_prediction != null) _buildPredictionCard(),
        
        const SizedBox(height: 16),
        
        // Calendar
        Card(
          color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarStyle: CalendarStyle(
                    markersMaxCount: 3,
                    markerDecoration: BoxDecoration(
                      color: AppTheme.isDarkMode ? AppTheme.primaryCoral : AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.isDarkMode ? AppTheme.darkCard : AppTheme.lightPurple,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                    weekendTextStyle: TextStyle(
                      color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[600],
                    ),
                    defaultTextStyle: TextStyle(
                      color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleTextStyle: TextStyle(
                      color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                    ),
                  ),
                  eventLoader: (day) {
                    // Mark period days
                    for (final cycle in _cycles) {
                      final endDate = cycle.expectedEndDate;
                      if (day.isAfter(cycle.startDate.subtract(const Duration(days: 1))) &&
                          day.isBefore(endDate.add(const Duration(days: 1)))) {
                        return ['Period'];
                      }
                    }
                    return [];
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _logPeriod(_selectedDay!),
                        icon: const Icon(Icons.add),
                        label: const Text('Log Period Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // History
        if (_cycles.isNotEmpty) _buildHistorySection(),
        
        const SizedBox(height: 32),
        
        // Privacy notice
        Card(
          color: AppTheme.isDarkMode ? AppTheme.darkSurface : Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lock, color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your period data is encrypted and stored only on your device. It never leaves your phone.',
                    style: TextStyle(fontSize: 12, color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard() {
    final isUpcoming = _prediction!.daysUntilPeriod >= 0 && _prediction!.daysUntilPeriod <= 7;
    
    return Card(
      color: isUpcoming
          ? (AppTheme.isDarkMode ? Colors.pink.withValues(alpha: 0.15) : Colors.pink[50])
          : (AppTheme.isDarkMode ? AppTheme.darkSurface : null),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: isUpcoming ? Colors.pink : AppTheme.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Next Period',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isUpcoming
                        ? Colors.pink
                        : (AppTheme.isDarkMode ? AppTheme.darkText : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
              Text(
                _prediction!.daysUntilPeriod < 0
                    ? 'Period is ${_prediction!.daysUntilPeriod.abs()} days late'
                    : _prediction!.daysUntilPeriod == 0
                        ? 'Period expected today'
                        : '${_prediction!.daysUntilPeriod} days until next period',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isUpcoming ? Colors.pink : (AppTheme.isDarkMode ? AppTheme.darkText : null),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expected: ${PeriodTrackerService.formatDate(_prediction!.nextPeriodDate)}',
              style: TextStyle(color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite, size: 16, color: AppTheme.isDarkMode ? Colors.pink[200] : Colors.pink[300]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fertile window: ${_prediction!.fertileWindowText}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.show_chart, size: 16, color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  'Average cycle: ${_prediction!.averageCycleLength} days',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  'History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._cycles.reversed.take(6).map((cycle) {
              return ListTile(
                dense: true,
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  PeriodTrackerService.formatDate(cycle.startDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                  ),
                ),
                subtitle: Text(
                  '${cycle.periodLength} days',
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteCycle(cycle.startDate),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
