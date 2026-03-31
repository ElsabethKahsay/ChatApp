import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../services/api_service.dart';
import 'contacts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      // Check if user already exists in secure storage
      final hasIdentity = await KeyStore.hasIdentity();
      
      if (hasIdentity) {
        // User exists - skip login and go to contacts
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        }
      }
      // If no session found, stay on login screen
    } catch (e) {
      // If error checking session, stay on login screen
      print('Session check error: $e');
    }
  }

  Future<void> _register() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final displayName = _displayNameController.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty || displayName.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      // 1. Generate userId from names
      final userId = '${firstName.toLowerCase()}_${lastName.toLowerCase()}';
      
      // 2. Generate X25519 key pair
      final keyPair = await CryptoService.generateKeyPair();
      await KeyStore.saveKeyPair(keyPair);
      
      // 3. Export public key
      final publicKey = await CryptoService.exportPublicKey(keyPair);
      
      // 4. Register with backend
      await ApiService.register(
        userId: userId,
        username: displayName,
        publicKey: publicKey,
        bday: DateTime.now(),
      );
      
      // 5. Save identity locally
      await KeyStore.saveIdentity(userId: userId, username: displayName);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Join the girls'),
            ),
          ],
        ),
      ),
    );
  }
}
