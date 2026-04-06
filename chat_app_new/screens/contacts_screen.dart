import 'package:flutter/material.dart';
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

  Future<void> _startChat(AppUser user) async {
    try {
      // Fetch peer's public key before starting chat
      final token = 'placeholder_token'; // Replace with actual token retrieval logic.
      final publicKey = await ApiService.getPublicKey(user.userId, token);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              contact: user,
              peerId: user.userId,
              peerName: user.username,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _myContacts.length,
                itemBuilder: (context, index) {
                  final contact = _myContacts[index];
                  return ListTile(
                    title: Text(contact.username),
                    subtitle: Text(contact.online ? 'Online' : 'Offline'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          contact: contact,
                          peerId: contact.userId,
                          peerName: contact.username,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
