import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/message_store.dart';
import '../services/socket_service.dart';
import '../services/profile_service.dart';
import '../crypto/key_store.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'saved_messages_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<AppUser> _myContacts = [];
  Map<String, Map<String, dynamic>> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  bool _isLoading = false;
  
  // Custom features
  String _weatherText = '';
  String _factText = '';
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // Real-time UI refresh for previews
    _msgSub = SocketService.messageStream.listen((_) => _refreshPreviews());
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _loadContacts();
    await _refreshPreviews();
    _loadWeatherAndFact();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshPreviews() async {
    if (_myContacts.isEmpty) return;
    final ids = _myContacts.map((c) => c.userId).toList();
    final lastMsgs = await MessageStore.getLastMessages(ids);
    final unreads = await MessageStore.getUnreadCounts(ids);
    if (mounted) {
      setState(() {
        _lastMessages = lastMsgs;
        _unreadCounts = unreads;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      final token = await KeyStore.getAuthToken();
      if (token == null) return;
      final users = await ApiService.getUsers(token);
      final myId = await KeyStore.getUserId();
      setState(() {
        _myContacts = users.where((u) => u.userId != myId).toList();
      });
    } catch (e) {
      debugPrint('Load Error: $e');
    }
  }

  Future<void> _loadWeatherAndFact() async {
    try {
      final profile = await ProfileService.getProfile();
      String city = profile['city'] ?? 'Addis Ababa';
      if (city.isEmpty) city = 'Addis Ababa';
      final w = await ProfileService.fetchWeather(city);
      setState(() => _weatherText = '${ProfileService.getWeatherEmoji(w['weatherCode'])} ${w['temperature']}°');
      final f = await ProfileService.fetchRandomFact();
      setState(() => _factText = f);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
            ? LinearGradient(colors: [AppTheme.darkBg, AppTheme.darkSurface.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : AppTheme.bgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildHeader(),
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _myContacts.length,
                      itemBuilder: (context, i) => _buildContactItem(_myContacts[i]),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const Spacer(),
          Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Private Vault',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await KeyStore.clear();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final textColor = AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_factText.isEmpty ? 'Loading mystery...' : _factText,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(_weatherText.isEmpty ? '--' : _weatherText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(AppUser contact) {
    final lastMsg = _lastMessages[contact.userId]?['text'] ?? 'No messages yet';
    final unread = _unreadCounts[contact.userId] ?? 0;

    final bool isDark = AppTheme.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.getAvatarColor(contact.userId),
          child: Text(contact.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        title: Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unread > 0)
              CircleAvatar(radius: 10, backgroundColor: AppTheme.primaryCoral,
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10))),
            const SizedBox(height: 4),
            Icon(Icons.circle, size: 10, color: contact.online ? Colors.green : Colors.grey),
          ],
        ),
        onTap: () {
          MessageStore.markAsRead(contact.userId);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
            peerId: contact.userId,
            peerName: contact.username,
            peerPublicKeyBase64: contact.publicKey,
          ))).then((_) => _loadAllData());
        },
      ),
    );
  }
}
