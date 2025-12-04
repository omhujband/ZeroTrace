import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  bool get isLightMode {
    return _themeMode == ThemeMode.light;
  }

  bool get isSystemMode {
    return _themeMode == ThemeMode.system;
  }

  /// Initialize theme from saved preference
  Future<void> initialize() async {
    _themeMode = await ThemeService.loadThemeMode();
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await ThemeService.saveThemeMode(mode);
    notifyListeners();
  }

  /// Toggle between light and dark
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
