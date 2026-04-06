import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    final displayName = _displayNameController.text;
    final password = _passwordController.text;

    if (displayName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both display name and password')),
      );
      return;
    }

    try {
      final response = await ApiService.login(displayName, password);
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful!')),
        );
        // Navigate to the next screen
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(labelText: 'Display Name'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
