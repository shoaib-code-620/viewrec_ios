import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

enum AppThemeMode { system, light, dark }

/// Holds the user's theme choice, follows the phone when set to System,
/// and remembers the choice between launches.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';
  AppThemeMode mode = AppThemeMode.system;

  bool get isDark => switch (mode) {
        AppThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
        AppThemeMode.light => false,
        AppThemeMode.dark => true,
      };

  void _apply() => C.dark = isDark;

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode = AppThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => AppThemeMode.system);
    } catch (_) {
      mode = AppThemeMode.system;
    }
    _apply();
  }

  Future<void> setMode(AppThemeMode m) async {
    mode = m;
    _apply();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, m.name);
    } catch (_) {}
  }

  /// Quick toggle for the top-bar button: flips what the user is looking at now.
  void toggle() => setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);

  @override
  void didChangePlatformBrightness() {
    if (mode == AppThemeMode.system) {
      _apply();
      notifyListeners();
    }
  }
}
