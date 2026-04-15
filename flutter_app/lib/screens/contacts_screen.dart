import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../crypto/key_store.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'saved_messages_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<AppUser> _myContacts = [];
  List<AppUser> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMyContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final token = await KeyStore.getAuthToken();
      if (token == null) return;

      final results = await ApiService.searchUsers(token, query);
      setState(() => _searchResults = results);
    } catch (e) {
      print('❌ Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMyContacts() async {
    setState(() => _isLoading = true);
    try {
      final token = await KeyStore.getAuthToken();
      final currentUserId = await KeyStore.getUserId();
      if (token == null || currentUserId == null) return;

      final allUsers = await ApiService.getUsers(token);
      final onlineUsers = await ApiService.getOnlineUsers(token);
      final onlineIndex = {for (var u in onlineUsers) u.userId: true};

      setState(() {
        _myContacts = allUsers
            .where((u) => u.userId != currentUserId)
            .map((u) => AppUser(
                  userId: u.userId,
                  username: u.username,
                  publicKey: u.publicKey,
                  lastSeen: u.lastSeen,
                  online: onlineIndex[u.userId] == true,
                ))
            .toList();
      });
    } catch (e) {
      print('❌ Load contacts error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(AppUser user) async {
    try {
      final token = await KeyStore.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      final publicKey = await ApiService.getPublicKey(user.userId, token);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              contact: user,
              peerId: user.userId,
              peerName: user.username,
              peerPublicKeyBase64: publicKey,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    // Disconnect socket first
    SocketService.disconnect();
    
    // Clear all stored data
    await KeyStore.clear();
    
    if (mounted) {
      // Navigate to login and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.white),
            tooltip: 'Saved Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedMessagesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: Column(
          children: [
            // Search Bar
            Container(
              color: AppTheme.primaryPurple,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _searchUsers,
              ),
            ),
            // Contact List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContactList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList() {
    final users = _searchController.text.isNotEmpty ? _searchResults : _myContacts;
    
    if (users.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isNotEmpty 
              ? 'No users found' 
              : 'No contacts yet',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final contact = users[index];
        final avatarColor = AppTheme.getAvatarColor(contact.userId);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: avatarColor,
              child: Text(
                contact.username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            title: Text(
              contact.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: contact.online ? AppTheme.primaryTeal : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  contact.online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: contact.online ? AppTheme.primaryTeal : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => _startChat(contact),
          ),
        );
      },
    );
  }
}
