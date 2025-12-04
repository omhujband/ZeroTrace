import 'package:flutter/material.dart';
import 'providers/theme_provider.dart';
import 'config/app_themes.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  runApp(ZeroTraceApp(themeProvider: themeProvider));
}

class ZeroTraceApp extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ZeroTraceApp({super.key, required this.themeProvider});

  @override
  State<ZeroTraceApp> createState() => _ZeroTraceAppState();

  /// Static method to access theme provider from anywhere
  static _ZeroTraceAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ZeroTraceAppState>();
  }
}

class _ZeroTraceAppState extends State<ZeroTraceApp> {
  late ThemeProvider _themeProvider;

  ThemeProvider get themeProvider => _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = widget.themeProvider;
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroTrace',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: _themeProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
