import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._internal();
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;

  static const String _themeKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Lấy key lưu theme theo từng user. Nếu chưa có user, dùng key chung.
  Future<String> _resolveThemeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString == null) {
      return _themeKey;
    }

    try {
      final Map<String, dynamic> userData =
          jsonDecode(userDataString) as Map<String, dynamic>;
      final dynamic uid = userData['uid'];
      if (uid is String && uid.isNotEmpty) {
        return '$_themeKey$uid';
      }
    } catch (_) {
      // Nếu parse lỗi thì fallback về key chung
    }

    return _themeKey;
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveThemeKey();
    final stored = prefs.getString(key);
    switch (stored) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveThemeKey();
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
      default:
        value = 'system';
        break;
    }
    await prefs.setString(key, value);
  }

  Future<void> toggleDark(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
