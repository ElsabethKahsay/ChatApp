import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import 'contacts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Validation patterns
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    setState(() => _errorMessage = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final username = value.trim();
    if (username.length < minUsernameLength) {
      return 'Username must be at least $minUsernameLength characters';
    }
    if (username.length > maxUsernameLength) {
      return 'Username must be at most $maxUsernameLength characters';
    }
    if (!_usernameRegex.hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isRegistering) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _passwordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  Future<void> _handleAuth() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String userId;

      if (_isRegistering) {
        // 1. Generate E2E Key Pair
        final keyPair = await CryptoService.generateKeyPair();
        final publicKeyB64 = await CryptoService.exportPublicKey(keyPair);
        userId = const Uuid().v4();

        // 2. Register on Server
        await ApiService.register(
          userId: userId,
          username: username,
          publicKey: publicKeyB64,
          password: password,
        );

        // 3. Save Keys and Identity Locally
        await KeyStore.saveKeyPair(keyPair);
        await KeyStore.saveIdentity(userId: userId, username: username);
      } else {
        // For login, we don't know userId yet - login will return it
        userId = '';
      }

      // 4. Perform Login
      final loginData = await ApiService.login(username, password);
      final String token = loginData['token'];
      userId = loginData['userId'];

      // 5. Persist Session
      await KeyStore.saveAuthToken(token);
      await KeyStore.saveIdentity(userId: userId, username: username);

      // 6. Connect Socket
      await SocketService.connect(userId, token);

      // 7. Initialize push notifications
      try {
        await PushNotificationService.init();
      } catch (e) {
        debugPrint('Push notification init failed (expected on web): $e');
      }

      if (mounted) {
        _showSuccess(_isRegistering ? 'Account created! Welcome, $username!' : 'Welcome back, $username!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Clean up error message
      if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
      }
      _showError(errorMsg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = null;
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SecureChat',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering ? 'Create a new account' : 'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter your username',
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                      helperText: _isRegistering
                          ? '$minUsernameLength-$maxUsernameLength chars, letters, numbers, underscores'
                          : null,
                    ),
                    validator: _validateUsername,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      border: const OutlineInputBorder(),
                      helperText: _isRegistering
                          ? 'At least $minPasswordLength characters'
                          : null,
                    ),
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    textInputAction: _isRegistering
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: _isRegistering ? null : (_) => _handleAuth(),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Confirm password field (register only)
                  if (_isRegistering)
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: _validateConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleAuth(),
                      enabled: !_isLoading,
                    ),

                  if (_isRegistering) const SizedBox(height: 16),

                  // Error message display
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_errorMessage != null) const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isRegistering ? 'Create Account' : 'Sign In',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle mode button
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Create one',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
