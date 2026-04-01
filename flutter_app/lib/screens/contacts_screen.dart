import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../crypto/key_store.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  List<AppUser> _myContacts = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadMyContacts();
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

  Future<void> _addUserByUsername() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isSearching = true);
    
    try {
      // Try to find user by their userId (username format)
      final allUsers = await ApiService.getUsers();
      final foundUser = allUsers.firstWhere(
        (user) => user.userId == username.toLowerCase(),
        orElse: () => throw Exception('User "$username" not found'),
      );

      // Check if already in contacts
      if (_myContacts.any((contact) => contact.userId == foundUser.userId)) {
        throw Exception('Already in contacts');
      }

      // Get their public key
      final publicKey = await ApiService.getPublicKey(foundUser.userId);
      
      // Add to contacts
      setState(() {
        _myContacts.add(foundUser);
      });
      
      _searchController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${foundUser.username} to contacts')),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startChat(AppUser user) async {
    try {
      // Fetch peer's public key before starting chat
      final publicKey = await ApiService.getPublicKey(user.userId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
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
    await KeyStore.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add user by username section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter their username (e.g. "alice_smith")',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Username...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addUserByUsername(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSearching ? null : _addUserByUsername,
                      icon: _isSearching 
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.person_add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          
          // My contacts section
          Expanded(
            child: _myContacts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No contacts yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add friends using their username',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _myContacts.length,
                    itemBuilder: (context, index) {
                      final user = _myContacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.username[0].toUpperCase()),
                        ),
                        title: Text(user.username),
                        subtitle: Text('@${user.userId}'),
                        trailing: const Icon(Icons.chat),
                        onTap: () => _startChat(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
