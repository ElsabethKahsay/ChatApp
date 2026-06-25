import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import 'contacts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    final token = await KeyStore.getAuthToken();
    final userId = await KeyStore.getUserId();

    if (token != null && userId != null) {
      if (_isConnecting) return;
      _isConnecting = true;
      debugPrint('Auto-logging in user: $userId');
      setState(() => _isLoading = true);
      try {
        var keyPair = await KeyStore.loadKeyPair(userId: userId);
        if (keyPair == null) {
          debugPrint('No key pair found during auto-login — generating new keys');
          keyPair = await CryptoService.generateKeyPair();
          // NOTE: Cannot update server key during auto-login (no password available).
          // Key pair is saved locally; server update deferred to next manual login.
          await KeyStore.saveKeyPair(keyPair, userId: userId);
        }

        await SocketService.connect(userId, token);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            RouteTransitions.fadeThrough(const ContactsScreen()),
          );
        }
      } catch (e) {
        debugPrint('Auto-login failed: $e');
        setState(() => _isLoading = false);
      } finally {
        _isConnecting = false;
      }
    }
  }

  Future<void> _handleAuth() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) return;
    if (_isConnecting) return;
    _isConnecting = true;

    setState(() => _isLoading = true);

    try {
      String userId;
      if (_isRegistering) {
        final keyPair = await CryptoService.generateKeyPair();
        final publicKey = await CryptoService.exportPublicKey(keyPair);
        userId = const Uuid().v4();

        await ApiService.register(
          userId: userId,
          username: username,
          publicKey: publicKey,
          password: password,
        );
        await KeyStore.saveKeyPair(keyPair, userId: userId);
      }

      final loginData = await ApiService.login(username, password);
      final token = loginData['token'];
      userId = loginData['userId'];

      await KeyStore.saveAuthToken(token, userId: userId);
      await KeyStore.saveIdentity(userId: userId, username: username);

      // Ensure key pair exists (may be a returning user on a new device)
      var keyPair = await KeyStore.loadKeyPair(userId: userId);
      if (keyPair == null) {
        debugPrint('No key pair found on login — generating new keys');
        keyPair = await CryptoService.generateKeyPair();
        final newPubKey = await CryptoService.exportPublicKey(keyPair);
        try {
          await ApiService.updatePublicKey(token, newPubKey, password: password);
          await KeyStore.saveKeyPair(keyPair, userId: userId);
        } catch (e) {
          debugPrint('Could not upload new public key: $e');
        }
      }

      await SocketService.connect(userId, token);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          RouteTransitions.fadeThrough(const ContactsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isConnecting = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryPurple),
                SizedBox(height: 16),
                Text(
                  'Signing in...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
          gradient: AppTheme.isDarkMode
              ? LinearGradient(
                  colors: [AppTheme.darkBg, AppTheme.darkSurface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : AppTheme.bgGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo / Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SecureChat',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDarkMode ? AppTheme.darkText : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering ? 'Create your account' : 'Welcome back',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Card
                  Card(
                    elevation: 0,
                    color: AppTheme.isDarkMode ? AppTheme.darkSurface : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: AppTheme.isDarkMode ? AppTheme.darkCard : AppTheme.softWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                            ),
                            textCapitalization: TextCapitalization.none,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: AppTheme.isDarkMode ? AppTheme.darkCard : AppTheme.softWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? AppTheme.darkText : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _handleAuth,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _isRegistering ? 'Create Account' : 'Sign In',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isRegistering = !_isRegistering),
                    child: Text(
                      _isRegistering ? 'Already have an account? Sign In' : "Don't have an account? Create one",
                      style: TextStyle(
                        color: AppTheme.isDarkMode ? AppTheme.primaryCoral : AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          ),
          // Server settings button (accessible before login)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppTheme.isDarkMode ? AppTheme.darkTextMuted : AppTheme.textMuted,
              onPressed: _showServerUrlDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: Constants.serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'http://192.168.1.114:3000',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Constants.setServerUrl(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Server URL updated'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
