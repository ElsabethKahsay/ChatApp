import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<AppUser> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    // TODO: Load users from API
    await Future.delayed(const Duration(seconds: 1));
    
    // Placeholder data
    _users = [
      AppUser(userId: 'alice', username: 'Alice'),
      AppUser(userId: 'bob', username: 'Bob'),
      AppUser(userId: 'charlie', username: 'Charlie'),
    ];
    
    setState(() => _isLoading = false);
  }

  Future<void> _startChat(AppUser user) async {
    // TODO: Navigate to chat with proper encryption setup
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: user.userId,
          peerName: user.username,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // TODO: Clear session and navigate to login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user.username),
                  subtitle: Text(user.userId),
                  onTap: () => _startChat(user),
                );
              },
            ),
    );
  }
}
