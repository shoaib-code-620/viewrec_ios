import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

/// Special follows the phone: the airy look by day and the glassy look at night.
enum AppThemeMode { light, dark, special }

/// Holds the user's theme choice, follows the phone when set to System,
/// and remembers the choice between launches.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';
  AppThemeMode mode = AppThemeMode.special;

  bool get isDark => switch (mode) {
        AppThemeMode.special => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
        AppThemeMode.light => false,
        AppThemeMode.dark => true,
      };

  void _apply() {
    C.dark = isDark;
    C.special = mode == AppThemeMode.special;
  }

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      // People who had Automatic get Special, which also follows the phone.
      mode = AppThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => AppThemeMode.special);
    } catch (_) {
      mode = AppThemeMode.special;
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
    if (mode == AppThemeMode.special) {
      _apply();
      notifyListeners();
    }
  }
}
