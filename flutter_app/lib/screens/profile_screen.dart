import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../app.dart';
import '../core/constants.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../services/anniversary_service.dart';
import '../services/goodnight_service.dart';
import '../services/panic_mode_service.dart';
import '../services/profile_service.dart';
import '../services/water_reminder_service.dart';
import 'period_tracker_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Controllers
  final _cityController = TextEditingController();
  
  // Values
  DateTime? _birthday;
  String _mood = '😊';
  Color _auraColor = const Color(0xFFF5A6D4);
  
  final List<String> _moodOptions = ['😊', '😀', '😍', '🥳', '🤔', '😴', '😢', '😡', '🥰', '🤗'];
  
  // Water reminder settings
  bool _waterReminderEnabled = false;
  int _waterReminderInterval = 2;
  
  // Anniversary settings
  DateTime? _anniversaryDate;
  String _anniversaryLabel = 'Friendship Anniversary';
  
  // Goodnight settings
  bool _goodnightEnabled = false;
  int _goodnightStartHour = 21;
  int _goodnightBedtimeHour = 23;
  
  // Panic mode
  bool _panicModeEnabled = false;

  // Server URL
  String _serverUrl = Constants.serverUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAnniversarySettings();
    _loadGoodnightSettings();
    _loadPanicModeSettings();
    setState(() => _serverUrl = Constants.serverUrl);
  }
  
  Future<void> _loadAnniversarySettings() async {
    final date = await AnniversaryService.getSpecialDate();
    final label = await AnniversaryService.getSpecialDateLabel();
    setState(() {
      _anniversaryDate = date;
      _anniversaryLabel = label;
    });
  }
  
  Future<void> _setAnniversaryDate(DateTime date) async {
    await AnniversaryService.setSpecialDate(date, _anniversaryLabel);
    setState(() => _anniversaryDate = date);
    _showSuccess('Anniversary date saved!');
  }
  
  Future<void> _loadGoodnightSettings() async {
    final enabled = await GoodnightService.isEnabled();
    final startHour = await GoodnightService.getDimmingStartHour();
    final bedtimeHour = await GoodnightService.getBedtimeHour();
    setState(() {
      _goodnightEnabled = enabled;
      _goodnightStartHour = startHour;
      _goodnightBedtimeHour = bedtimeHour;
    });
  }
  
  Future<void> _loadPanicModeSettings() async {
    final enabled = await PanicModeService.isPanicModeEnabled();
    setState(() => _panicModeEnabled = enabled);
  }
  
  Future<void> _togglePanicMode(bool enabled) async {
    if (enabled) {
      await PanicModeService.enablePanicMode();
      _showSuccess('Panic mode enabled! Triple tap anywhere to switch to decoy app.');
    } else {
      await PanicModeService.disablePanicMode();
      _showSuccess('Panic mode disabled.');
    }
    setState(() => _panicModeEnabled = enabled);
  }
  
  Future<void> _toggleGoodnight(bool enabled) async {
    await GoodnightService.setEnabled(enabled);
    setState(() => _goodnightEnabled = enabled);
    _showSuccess(enabled ? 'Goodnight mode enabled!' : 'Goodnight mode disabled');
  }

  Future<void> _showServerUrlDialog() async {
    final controller = TextEditingController(text: _serverUrl);
    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x:3000',
            labelText: 'Server URL',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Constants.setServerUrl(controller.text.trim());
              setState(() => _serverUrl = Constants.serverUrl);
              if (mounted) Navigator.pop(context);
              _showSuccess('Server URL updated. Reconnect to apply.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileService.getProfile();
      final waterEnabled = await WaterReminderService.isEnabled();
      final waterInterval = await WaterReminderService.getIntervalHours();
      setState(() {
        _profile = profile;
        _mood = profile['mood'] ?? '😊';
        _cityController.text = profile['city'] ?? '';
        if (profile['auraColor'] != null) {
          _auraColor = _hexToColor(profile['auraColor']);
        }
        if (profile['bday'] != null) {
          _birthday = DateTime.parse(profile['bday']);
        }
        _waterReminderEnabled = waterEnabled;
        _waterReminderInterval = waterInterval;
      });
    } catch (e) {
      _showError('Failed to load profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _updateBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _birthday = picked);
      await _save(() => ProfileService.updateBirthday(picked));
    }
  }

  Future<void> _updateMood(String mood) async {
    setState(() => _mood = mood);
    await _save(() => ProfileService.updateMood(mood));
  }

  Future<void> _updateAuraColor(Color color) async {
    setState(() => _auraColor = color);
    await _save(() => ProfileService.updateAuraColor(_colorToHex(color)));
  }

  Future<void> _updateCity() async {
    if (_cityController.text.isNotEmpty) {
      await _save(() => ProfileService.updateCity(_cityController.text));
    }
  }

  Future<void> _save(Future<void> Function() saveFunc) async {
    setState(() => _isSaving = true);
    try {
      await saveFunc();
      _showSuccess('Saved!');
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick your aura color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _auraColor,
            onColorChanged: (color) {
              setState(() => _auraColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateAuraColor(_auraColor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryPurple,
        actions: [
          if (_isSaving)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // User Info Card
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: _auraColor,
                            child: Text(
                              (_profile?['username'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _profile?['username'] ?? 'User',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '@${_profile?['userId'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Aura Color
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _auraColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                      title: const Text('Aura Color'),
                      subtitle: Text(_colorToHex(_auraColor)),
                      trailing: const Icon(Icons.edit),
                      onTap: _showColorPicker,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mood Selector
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: _moodOptions.map((mood) {
                              final isSelected = mood == _mood;
                              return ChoiceChip(
                                label: Text(mood, style: const TextStyle(fontSize: 24)),
                                selected: isSelected,
                                onSelected: (_) => _updateMood(mood),
                                backgroundColor: Colors.grey[200],
                                selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Birthday
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: ListTile(
                      leading: const Icon(Icons.cake, color: AppTheme.primaryPurple),
                      title: const Text('Birthday'),
                      subtitle: Text(
                        _birthday != null
                            ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: _updateBirthday,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // City (for weather)
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'City (for /weather command)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              hintText: 'Enter your city',
                              prefixIcon: const Icon(Icons.location_city),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.save),
                                onPressed: _updateCity,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _updateCity(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Period Tracker Card
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.favorite,
                        color: Colors.pink,
                      ),
                      title: const Text(
                        'Period Tracker',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Private cycle tracking'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          RouteTransitions.slideRight(const PeriodTrackerScreen()),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Water Reminder Card
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.water_drop,
                                color: Colors.blue[400],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Water Reminder',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _waterReminderEnabled,
                                onChanged: (value) async {
                                  setState(() => _waterReminderEnabled = value);
                                  await WaterReminderService.setEnabled(value);
                                  if (value) {
                                    _showSuccess('Water reminders enabled!');
                                  } else {
                                    _showInfo('Water reminders disabled');
                                  }
                                },
                                activeThumbColor: AppTheme.primaryPurple,
                              ),
                            ],
                          ),
                          if (_waterReminderEnabled) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Remind me every:',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _waterReminderInterval.toDouble(),
                                    min: 1,
                                    max: 4,
                                    divisions: 3,
                                    label: '$_waterReminderInterval hours',
                                    onChanged: (value) {
                                      setState(() {
                                        _waterReminderInterval = value.round();
                                      });
                                    },
                                    onChangeEnd: (value) async {
                                      await WaterReminderService.setIntervalHours(
                                        value.round(),
                                      );
                                      _showSuccess('Interval updated!');
                                    },
                                  ),
                                ),
                                Text(
                                  '$_waterReminderInterval hours',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await WaterReminderService.showTestNotification();
                                _showSuccess('Test notification sent!');
                              },
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Test Notification'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Anniversary Settings
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: ListTile(
                      leading: const Icon(Icons.celebration, color: Colors.amber),
                      title: Text(
                        'Special Anniversary',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                        ),
                      ),
                      subtitle: Text(
                        _anniversaryDate != null
                            ? '${_anniversaryLabel}: ${_anniversaryDate!.day}/${_anniversaryDate!.month}/${_anniversaryDate!.year}'
                            : 'Set a special date',
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : null,
                        ),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _anniversaryDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          await _setAnniversaryDate(picked);
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Theme Toggle
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: SwitchListTile(
                      secondary: Icon(
                        AppTheme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: AppTheme.isDarkMode ? Colors.amber : Colors.orange,
                      ),
                      title: const Text(
                        'Dark Theme',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(AppTheme.isDarkMode ? 'Dark mode active' : 'Light mode active'),
                      value: AppTheme.isDarkMode,
                      onChanged: (value) async {
                        await AppTheme.setThemeMode(value);
                        SecureChatAppState.refreshTheme();
                        setState(() {});
                      },
                      activeThumbColor: AppTheme.primaryPurple,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Panic Mode
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.emergency, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Panic Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _panicModeEnabled,
                                onChanged: _togglePanicMode,
                                activeThumbColor: Colors.red,
                              ),
                            ],
                          ),
                          if (_panicModeEnabled) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Triple tap anywhere to instantly switch to decoy app and clear messages',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Server Configuration
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: ListTile(
                      leading: const Icon(Icons.dns, color: Colors.blue),
                      title: Text(
                        'Server URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                        ),
                      ),
                      subtitle: Text(
                        _serverUrl,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _showServerUrlDialog(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Goodnight Autofade Settings
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.nightlight_round, color: Colors.indigo[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Goodnight Autofade',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _goodnightEnabled,
                                onChanged: _toggleGoodnight,
                                activeThumbColor: AppTheme.primaryPurple,
                              ),
                            ],
                          ),
                          if (_goodnightEnabled) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Dimming starts: ${GoodnightService.formatHour(_goodnightStartHour)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              'Full dim at: ${GoodnightService.formatHour(_goodnightBedtimeHour)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(hour: _goodnightStartHour, minute: 0),
                                      );
                                      if (time != null) {
                                        await GoodnightService.setDimmingStartHour(time.hour);
                                        await _loadGoodnightSettings();
                                      }
                                    },
                                    child: const Text('Set Start Time'),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(hour: _goodnightBedtimeHour, minute: 0),
                                      );
                                      if (time != null) {
                                        await GoodnightService.setBedtimeHour(time.hour);
                                        await _loadGoodnightSettings();
                                      }
                                    },
                                    child: const Text('Set Bedtime'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Card
                  Card(
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Tips',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.isDarkMode ? AppTheme.darkText : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Your aura color customizes your chat bubbles\n'
                            '• Pet mood appears next to your avatar\n'
                            '• Birthday lets friends get notifications\n'
                            '• City enables the /weather command\n'
                            '• /fact and /weather commands work in chat',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
