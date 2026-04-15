import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/saved_message.dart';
import '../services/saved_messages_service.dart';

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final SavedMessagesService _service = SavedMessagesService();
  List<SavedMessage> _savedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _service.fetchSavedMessages();
      setState(() {
        _savedItems = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load vault: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewDecryptedMessage(SavedMessage msg) async {
    try {
      final plaintext = await _service.decryptSavedMessage(msg);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(msg.label ?? 'Decrypted Message'),
          content: SelectableText(plaintext),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decryption failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Private Vault'),
        backgroundColor: AppTheme.primaryPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _savedItems.isEmpty
                ? const Center(child: Text('Your vault is empty.'))
                : ListView.builder(
                    itemCount: _savedItems.length,
                    itemBuilder: (context, index) {
                      final msg = _savedItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.lock_person, color: AppTheme.primaryPurple),
                          title: Text(msg.label ?? 'Secret Note'),
                          subtitle: Text('Saved on ${msg.createdAt.toString().split('.')[0]}'),
                          trailing: const Icon(Icons.visibility),
                          onTap: () => _viewDecryptedMessage(msg),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}