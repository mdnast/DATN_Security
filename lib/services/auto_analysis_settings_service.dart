import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AutoAnalysisSettingsService {
  static const String _legacyAutoAnalysisKey = 'auto_analysis_enabled';
  static const String _autoAnalysisKeyPrefix = 'auto_analysis_enabled_';

  Future<String> _getStorageKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      try {
        final Map<String, dynamic> userData = jsonDecode(userDataString);
        final String uid = (userData['uid'] ?? userData['email'] ?? 'guest').toString();
        final key = '$_autoAnalysisKeyPrefix$uid';

        if (!prefs.containsKey(key) && prefs.containsKey(_legacyAutoAnalysisKey)) {
          final legacy = prefs.getBool(_legacyAutoAnalysisKey);
          if (legacy != null) {
            await prefs.setBool(key, legacy);
          }
          await prefs.remove(_legacyAutoAnalysisKey);
        }

        return key;
      } catch (_) {
        // Fallback to legacy key if parsing fails
      }
    }

    return _legacyAutoAnalysisKey;
  }

  Future<bool> isAutoAnalysisEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    return prefs.getBool(storageKey) ?? true;
  }

  Future<void> setAutoAnalysisEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    await prefs.setBool(storageKey, enabled);
  }
}
