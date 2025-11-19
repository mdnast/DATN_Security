import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  LocaleService._internal();
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;

  static const String _localeKey = 'app_locale_code';

  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  Future<String> _resolveLocaleKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString == null) {
      return _localeKey;
    }

    try {
      final Map<String, dynamic> userData =
          jsonDecode(userDataString) as Map<String, dynamic>;
      final dynamic uid = userData['uid'];
      if (uid is String && uid.isNotEmpty) {
        return '${_localeKey}_$uid';
      }
    } catch (_) {
      // fallback to global key on parse error
    }

    return _localeKey;
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveLocaleKey();
    final code = prefs.getString(key);
    if (code == null || code.isEmpty) {
      locale.value = null; // follow system
    } else {
      locale.value = Locale(code);
    }
  }

  Future<void> setLocale(Locale? newLocale) async {
    locale.value = newLocale;
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveLocaleKey();
    if (newLocale == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, newLocale.languageCode);
    }
  }
}
