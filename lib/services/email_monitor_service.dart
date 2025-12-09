import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'gmail_service.dart';
import 'notification_service.dart';
import 'email_analysis_service.dart';
import 'scan_history_service.dart';
import '../models/email_message.dart';
import 'auto_analysis_settings_service.dart';
import 'locale_service.dart';
import '../localization/app_localizations.dart';

/// Service theo dõi email mới và hiển thị thông báo
class EmailMonitorService {
  static final EmailMonitorService _instance = EmailMonitorService._internal();
  factory EmailMonitorService() => _instance;
  EmailMonitorService._internal();

  final GmailService _gmailService = GmailService();
  final NotificationService _notificationService = NotificationService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _monitorTimer;
  List<String> _previousEmailIds = [];
  bool _isMonitoring = false;

  static const String _lastCheckKey = 'email_monitor_last_check';
  static const String _emailIdsKey = 'email_monitor_ids';
  static const int _checkIntervalSeconds =
      30; // ✅ Check mỗi 1 PHÚT (nhanh và hợp lý)

  /// Bắt đầu theo dõi email mới
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      print('Email monitor is already running');
      return;
    }

    print('=== STARTING EMAIL MONITOR ===');
    _isMonitoring = true;

    // Load danh sách email cũ
    await _loadPreviousEmailIds();

    // Check ngay lần đầu
    await _checkForNewEmails();

    // Setup timer để check định kỳ
    _monitorTimer = Timer.periodic(
      Duration(seconds: _checkIntervalSeconds),
      (timer) => _checkForNewEmails(),
    );

    print(
      'Email monitor started - checking every ${_checkIntervalSeconds ~/ 60} minutes',
    );
  }

  /// Dừng theo dõi email
  void stopMonitoring() {
    if (_monitorTimer != null) {
      _monitorTimer!.cancel();
      _monitorTimer = null;
      _isMonitoring = false;
      print('Email monitor stopped');
    }
  }

  /// Check email mới
  Future<void> _checkForNewEmails() async {
    try {
      print('Checking for new emails...');

      // Fetch emails mới nhất (chỉ lấy 20 email để tối ưu)
      final emails = await _gmailService.fetchEmails(maxResults: 20);

      if (emails.isEmpty) {
        print('No emails found');
        return;
      }

      // Lọc ra emails mới (chưa có trong danh sách cũ)
      final newEmails = emails
          .where((email) => !_previousEmailIds.contains(email.id))
          .toList();

      if (newEmails.isNotEmpty) {
        print('Found ${newEmails.length} new email(s)!');

        for (var email in newEmails) {
          await _showNewEmailNotification(email);
        }

        // Cập nhật danh sách email ids
        _previousEmailIds = emails.map((e) => e.id).toList();
        await _savePreviousEmailIds();
      } else {
        print('No new emails');
      }

      // Lưu thời gian check cuối
      await _storage.write(
        key: _lastCheckKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error checking for new emails: $e');
      // Không throw error để timer tiếp tục chạy
    }
  }

  /// Hiển thị thông báo NHANH cho email mới + phân tích NGẦM
  /// Gửi notification NGAY, phân tích sau (không blocking)
  Future<void> _showNewEmailNotification(EmailMessage email) async {
    final title = '📧 Email mới từ ${_extractSenderName(email.from)}';
    final body = email.subject.isNotEmpty ? email.subject : 'Không có tiêu đề';

    // ✅ GỬI NOTIFICATION NGAY (không đợi phân tích)
    await _notificationService.showNotification(
      title: title,
      body: body,
      type: 'new_email',
      data: {
        'email_id': email.id,
        'from': email.from,
        'subject': email.subject,
        'snippet': email.snippet,
        'body': email.body ?? email.snippet,
        'date': email.date.toIso8601String(),
        'action': 'open_email_detail',
      },
    );

    print('✅ Notification sent INSTANTLY for: ${email.subject}');

    // ✅ PHÂN TÍCH NGẦM (async, không blocking, không hiện UI)
    _analyzeEmailSilently(email);
  }

  /// Phân tích email NGẦM (không blocking, không hiện gì trên UI)
  Future<void> _analyzeEmailSilently(EmailMessage email) async {
    try {
      print('🔍 Silent analysis started for: ${email.subject}');

      final autoSettings = AutoAnalysisSettingsService();
      final autoEnabled = await autoSettings.isAutoAnalysisEnabled();
      if (!autoEnabled) {
        print(
          'ℹ️ Auto analysis disabled - skipping silent analysis for ${email.subject}',
        );
        return;
      }

      final analysisService = EmailAnalysisService();
      final scanHistoryService = ScanHistoryService();
      final storage = const FlutterSecureStorage();

      // Nếu email đã được phân tích (và không phải unknown) thì bỏ qua để tiết kiệm token
      final latestScan = await scanHistoryService.getLatestScanForEmail(
        email.id,
      );
      if (latestScan != null && latestScan.result != 'unknown') {
        print(
          'ℹ️ Email already analyzed, skipping silent AI: ${email.subject}',
        );
        return;
      }

      // Phân tích AI (chạy ngầm)
      // FIX: Fetch full email content before analyzing
      // Email received from list mostly contains snippet only
      print('Fetching full content for accurate analysis...');
      final fullEmail = await _gmailService.fetchEmailDetails(email.id);

      final result = await analysisService.analyzeEmail(fullEmail ?? email);

      // Lưu kết quả vào database
      await scanHistoryService.saveScanResult(result);
      print('✅ Analysis saved silently: ${result.result}');

      // Lưu email cache
      final emailJson = jsonEncode({
        'id': email.id,
        'from': email.from,
        'subject': email.subject,
        'snippet': email.snippet,
        'body': email.body ?? email.snippet,
        'date': email.date.toIso8601String(),
      });
      await storage.write(key: 'email_cache_${email.id}', value: emailJson);

      // Gửi thêm một thông báo kết quả phân tích để user biết email đó
      // nguy hiểm / nghi ngờ / an toàn là email nào.
      final data = {
        'email_id': email.id,
        'from': email.from,
        'subject': email.subject,
        'snippet': email.snippet,
        'body': email.body ?? email.snippet,
        'date': email.date.toIso8601String(),
        'action': 'open_email_detail',
      };

      if (result.isPhishing) {
        // Use current app locale for notification text
        final locale = LocaleService().locale.value ?? const Locale('vi');
        final l = AppLocalizations(locale);
        await _notificationService.showNotification(
          title: l.t('notif_phishing_title'),
          body: l.t('notif_phishing_body').replaceFirst('{from}', email.from),
          type: 'phishing',
          data: data,
        );
      } else if (result.isSuspicious) {
        final locale = LocaleService().locale.value ?? const Locale('vi');
        final l = AppLocalizations(locale);
        await _notificationService.showNotification(
          title: l.t('notif_suspicious_title'),
          body: l.t('notif_suspicious_body').replaceFirst('{from}', email.from),
          type: 'security',
          data: data,
        );
      } else if (result.isSafe) {
        final locale = LocaleService().locale.value ?? const Locale('vi');
        final l = AppLocalizations(locale);
        await _notificationService.showNotification(
          title: l.t('notif_safe_title'),
          body: l.t('notif_safe_body').replaceFirst('{from}', email.from),
          type: 'safe',
          data: data,
        );
      }
    } catch (e) {
      print('⚠️ Silent analysis failed (not critical): $e');
      // Không hiển thị lỗi cho user, chỉ log
    }
  }

  /// Trích xuất tên người gửi từ email address
  String _extractSenderName(String from) {
    // Format: "John Doe <john@example.com>" or "john@example.com"
    final nameMatch = RegExp(r'^"?([^"<]+)"?\s*<').firstMatch(from);
    if (nameMatch != null) {
      return nameMatch.group(1)?.trim() ?? from;
    }

    // Nếu chỉ có email, lấy phần trước @
    final emailMatch = RegExp(r'^([^@<\s]+)').firstMatch(from);
    return emailMatch?.group(1) ?? from;
  }

  /// Load danh sách email IDs đã check trước đó
  Future<void> _loadPreviousEmailIds() async {
    try {
      final idsJson = await _storage.read(key: _emailIdsKey);
      if (idsJson != null && idsJson.isNotEmpty) {
        _previousEmailIds = idsJson.split(',');
        print('Loaded ${_previousEmailIds.length} previous email IDs');
      } else {
        // Lần đầu tiên chạy, fetch emails hiện tại để làm baseline
        final emails = await _gmailService.fetchEmails(maxResults: 10);
        _previousEmailIds = emails.map((e) => e.id).toList();
        await _savePreviousEmailIds();
        print('Initialized with ${_previousEmailIds.length} current emails');
      }
    } catch (e) {
      print('Error loading previous email IDs: $e');
      _previousEmailIds = [];
    }
  }

  /// Lưu danh sách email IDs
  Future<void> _savePreviousEmailIds() async {
    try {
      final idsJson = _previousEmailIds.join(',');
      await _storage.write(key: _emailIdsKey, value: idsJson);
    } catch (e) {
      print('Error saving email IDs: $e');
    }
  }

  /// Lấy thời gian check cuối cùng
  Future<DateTime?> getLastCheckTime() async {
    try {
      final timeStr = await _storage.read(key: _lastCheckKey);
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
    } catch (e) {
      print('Error getting last check time: $e');
    }
    return null;
  }

  /// Reset monitor (xóa dữ liệu cũ)
  Future<void> reset() async {
    stopMonitoring();
    _previousEmailIds = [];
    await _storage.delete(key: _emailIdsKey);
    await _storage.delete(key: _lastCheckKey);
    print('Email monitor reset');
  }

  /// Check xem có đang monitoring không
  bool get isMonitoring => _isMonitoring;

  /// Check email ngay lập tức (không đợi timer)
  /// Được gọi từ UI button
  Future<void> checkNow() async {
    print('=== MANUAL CHECK TRIGGERED ===');
    await _checkForNewEmails();
  }
}
