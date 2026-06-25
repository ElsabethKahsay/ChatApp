import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'services/screenshot_service.dart';

class SecureChatApp extends StatefulWidget {
  const SecureChatApp({super.key});

  @override
  State<SecureChatApp> createState() => SecureChatAppState();
}

class SecureChatAppState extends State<SecureChatApp> with WidgetsBindingObserver {
  static SecureChatAppState? _instance;
  static SecureChatAppState? get instance => _instance;

  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    ScreenshotService().enableScreenshotPrevention();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    await AppTheme.loadThemePreference();
    if (mounted) setState(() => _themeLoaded = true);
  }

  static void refreshTheme() {
    _instance?._rebuild();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ScreenshotService().disableScreenshotPrevention();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ScreenshotService().didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MaterialApp(
        title: 'SecureChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeLoaded
            ? (AppTheme.isDarkMode ? ThemeMode.dark : ThemeMode.light)
            : ThemeMode.light,
        home: const LoginScreen(),
      ),
    );
  }
}
