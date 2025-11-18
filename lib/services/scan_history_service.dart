import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';

class ScanHistoryService {
  static const String _legacyScanHistoryKey = 'scan_history';
  static const String _scanHistoryKeyPrefix = 'scan_history_';

  Future<String> _getStorageKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      try {
        final Map<String, dynamic> userData = jsonDecode(userDataString);
        final String uid = (userData['uid'] ?? userData['email'] ?? 'guest').toString();
        final key = '$_scanHistoryKeyPrefix$uid';

        if (!prefs.containsKey(key) && prefs.containsKey(_legacyScanHistoryKey)) {
          final legacyJson = prefs.getString(_legacyScanHistoryKey);
          if (legacyJson != null) {
            await prefs.setString(key, legacyJson);
          }
          await prefs.remove(_legacyScanHistoryKey);
        }

        return key;
      } catch (_) {
        // Fallback to legacy key if parsing fails
      }
    }

    return _legacyScanHistoryKey;
  }

  Future<void> saveScanResult(ScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    final history = await getScanHistory();
    history.add(result);
    
    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(storageKey, jsonEncode(jsonList));
  }

  Future<List<ScanResult>> getScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    final jsonString = prefs.getString(storageKey);
    
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ScanResult.fromJson(json)).toList();
  }

  /// Lấy lần phân tích mới nhất cho một email theo emailId
  Future<ScanResult?> getLatestScanForEmail(String emailId) async {
    final history = await getScanHistory();
    final scansForEmail = history.where((r) => r.emailId == emailId).toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    if (scansForEmail.isEmpty) return null;
    return scansForEmail.first;
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final history = await getScanHistory();
    
    if (history.isEmpty) {
      return {
        'totalScanned': 0,
        'phishingCount': 0,
        'suspiciousCount': 0,
        'safeCount': 0,
        'phishingPercentage': 0.0,
        'suspiciousPercentage': 0.0,
        'safePercentage': 0.0,
        'recentScans': [],
        'threatTrends': {},
      };
    }

    final phishingCount = history.where((r) => r.isPhishing).length;
    final suspiciousCount = history.where((r) => r.isSuspicious).length;
    final safeCount = history.where((r) => r.isSafe).length;
    final total = history.length;

    final recentScans = history
      .toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    
    final last7Days = recentScans
        .where((r) => DateTime.now().difference(r.scanDate).inDays <= 7)
        .toList();

    final threatTrends = _calculateThreatTrends(history);

    return {
      'totalScanned': total,
      'phishingCount': phishingCount,
      'suspiciousCount': suspiciousCount,
      'safeCount': safeCount,
      'phishingPercentage': (phishingCount / total * 100),
      'suspiciousPercentage': (suspiciousCount / total * 100),
      'safePercentage': (safeCount / total * 100),
      'recentScans': recentScans.take(10).toList(),
      'last7DaysScans': last7Days,
      'threatTrends': threatTrends,
      'averageConfidence': _calculateAverageConfidence(history),
    };
  }

  Map<String, int> _calculateThreatTrends(List<ScanResult> history) {
    final trends = <String, int>{};
    
    for (var result in history) {
      for (var threat in result.detectedThreats) {
        trends[threat] = (trends[threat] ?? 0) + 1;
      }
    }
    
    return Map.fromEntries(
      trends.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
  }

  double _calculateAverageConfidence(List<ScanResult> history) {
    if (history.isEmpty) return 0.0;
    final sum = history.fold<double>(0, (sum, r) => sum + r.confidenceScore);
    return sum / history.length;
  }

  Future<List<ScanResult>> getPhishingEmails() async {
    final history = await getScanHistory();
    return history.where((r) => r.isPhishing).toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
  }

  Future<List<ScanResult>> getSuspiciousEmails() async {
    final history = await getScanHistory();
    return history.where((r) => r.isSuspicious).toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
  }

  Future<Map<String, List<ScanResult>>> getEmailsByDate() async {
    final history = await getScanHistory();
    final Map<String, List<ScanResult>> grouped = {};

    for (var result in history) {
      final dateKey = '${result.scanDate.year}-${result.scanDate.month.toString().padLeft(2, '0')}-${result.scanDate.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(result);
    }

    return grouped;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    await prefs.remove(storageKey);
  }
}
