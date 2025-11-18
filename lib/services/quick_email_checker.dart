import 'gmail_service.dart';
import 'email_analysis_service.dart';
import 'notification_service.dart';
import 'scan_history_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auto_analysis_settings_service.dart';
import '../models/email_message.dart';
import 'dart:convert';

/// Service để check và phân tích email ngay lập tức (on-demand)
class QuickEmailChecker {
  final GmailService _gmailService = GmailService();
  final EmailAnalysisService _analysisService = EmailAnalysisService();
  final NotificationService _notificationService = NotificationService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AutoAnalysisSettingsService _autoAnalysisSettings = AutoAnalysisSettingsService();

  static const String _emailIdsKey = 'quick_check_email_ids';

  /// Check và phân tích email mới NGAY LẬP TỨC
  /// Trả về số lượng emails mới tìm thấy
  Future<int> checkAndAnalyzeNow() async {
    print('=== QUICK CHECK & ANALYZE START ===');
    
    try {
      // Fetch 10 emails mới nhất
      print('Fetching emails...');
      final emails = await _gmailService.fetchEmails(maxResults: 10);
      
      if (emails.isEmpty) {
        print('No emails found');
        return 0;
      }

      print('Found ${emails.length} emails total');

      // Danh sách ID hiện tại
      final currentIds = emails.map((e) => e.id).toList();

      // Load danh sách email IDs đã check
      final previousIdsJson = await _storage.read(key: _emailIdsKey);

      // Lần đầu chạy: chỉ lưu baseline, KHÔNG phân tích các email cũ
      if (previousIdsJson == null || previousIdsJson.isEmpty) {
        await _storage.write(
          key: _emailIdsKey,
          value: currentIds.join(','),
        );
        print(
            'First quick check - initialized baseline with ${currentIds.length} emails, no analysis to avoid scanning old emails.');
        return 0;
      }

      final previousIds = previousIdsJson.split(',');

      // Lọc emails mới
      final newEmails = emails
          .where((email) => !previousIds.contains(email.id))
          .toList();

      if (newEmails.isEmpty) {
        print('No new emails');
        return 0;
      }

      print('🆕 Found ${newEmails.length} NEW email(s)!');

      // Phân tích từng email mới
      int analyzed = 0;
      for (var email in newEmails) {
        try {
          await _analyzeAndNotify(email);
          analyzed++;
        } catch (e) {
          print('❌ Error analyzing email ${email.id}: $e');
        }
      }

      // Cập nhật danh sách IDs với snapshot hiện tại
      await _storage.write(
        key: _emailIdsKey,
        value: currentIds.join(','),
      );

      print('✅ Quick check completed: $analyzed/${newEmails.length} analyzed');
      return newEmails.length;
    } catch (e) {
      print('❌ Quick check failed: $e');
      rethrow;
    }
  }

  /// Phân tích email và hiển thị notification với kết quả
  Future<void> _analyzeAndNotify(EmailMessage email) async {
    print('🔍 Analyzing: ${email.subject}');
    
    try {
      final autoEnabled = await _autoAnalysisSettings.isAutoAnalysisEnabled();

      if (!autoEnabled) {
        print('ℹ️ Auto analysis disabled - sending new email notification only');
        await _notificationService.showNotification(
          title: '📧 Email mới',
          body: 'Từ ${_extractSenderName(email.from)}: "${_truncate(email.subject, 60)}"',
          type: 'new_email',
          data: {
            'email_id': email.id,
            'from': email.from,
            'subject': email.subject,
            'snippet': email.snippet,
            'body': email.body ?? '',
            'date': email.date.toIso8601String(),
            'action': 'open_email_detail',
          },
        );
        await _saveEmailCache(email);
        return;
      }
      
      // Nếu email đã được phân tích (và không phải unknown) thì bỏ qua để tiết kiệm token
      final latestScan = await _scanHistoryService.getLatestScanForEmail(email.id);
      if (latestScan != null && latestScan.result != 'unknown') {
        print('ℹ️ Email already analyzed (quick check), skipping AI: ${email.subject}');
        return;
      }
      
      // Phân tích email bằng AI
      final result = await _analysisService.analyzeEmail(email);
      
      // ✅ LƯU KẾT QUẢ PHÂN TÍCH VÀO SCAN HISTORY
      await _scanHistoryService.saveScanResult(result);
      print('✅ Analysis result saved to history');
      
      // Lưu email cache để navigate từ notification
      await _saveEmailCache(email);
      
      // Tạo notification dựa trên kết quả
      String title;
      String body;
      String type;
      
      if (result.isPhishing) {
        // PHISHING - Nguy hiểm cao
        title = '🚨 CẢNH BÁO PHISHING!';
        body = 'Email từ ${_extractSenderName(email.from)}\n'
               '⚠️ Độ nguy hiểm: ${(result.confidenceScore * 100).toInt()}%\n'
               '"${_truncate(email.subject, 50)}"';
        type = 'phishing';
        
        print('⚠️ PHISHING: ${email.subject}');
      } else if (result.isSuspicious) {
        // SUSPICIOUS - Cần cẩn thận
        title = '⚠️ Email nghi ngờ';
        body = 'Từ ${_extractSenderName(email.from)}\n'
               '🔍 Mức nghi ngờ: ${(result.confidenceScore * 100).toInt()}%\n'
               '"${_truncate(email.subject, 50)}"';
        type = 'suspicious';
        
        print('⚠️ SUSPICIOUS: ${email.subject}');
      } else {
        // SAFE - An toàn
        title = '✅ Email an toàn';
        body = 'Từ ${_extractSenderName(email.from)}\n'
               '✓ Độ an toàn: ${(result.confidenceScore * 100).toInt()}%\n'
               '"${_truncate(email.subject, 50)}"';
        type = 'safe';
        
        print('✅ SAFE: ${email.subject}');
      }

      // Hiển thị notification với đầy đủ thông tin để navigate
      await _notificationService.showNotification(
        title: title,
        body: body,
        type: type,
        data: {
          'email_id': email.id,
          'from': email.from,
          'subject': email.subject,
          'snippet': email.snippet,
          'body': email.body ?? '',
          'date': email.date.toIso8601String(),
          'classification': result.result,
          'risk_score': result.confidenceScore.toString(),
          'timestamp': email.date.toIso8601String(),
          'action': 'open_email_detail', // Flag để navigation
        },
      );

      print('✅ Notification sent with analysis result');
    } catch (e) {
      print('❌ Analysis error: $e');
      
      // Lưu email cache ngay cả khi phân tích lỗi
      await _saveEmailCache(email);
      
      // Nếu phân tích lỗi, vẫn thông báo email mới
      await _notificationService.showNotification(
        title: '📧 Email mới (chưa phân tích)',
        body: 'Từ ${_extractSenderName(email.from)}: "${_truncate(email.subject, 60)}"',
        type: 'new_email',
        data: {
          'email_id': email.id,
          'from': email.from,
          'subject': email.subject,
          'snippet': email.snippet,
          'body': email.body ?? '',
          'date': email.date.toIso8601String(),
          'action': 'open_email_detail',
        },
      );
    }
  }

  /// Lưu email cache để có thể truy cập từ notification
  Future<void> _saveEmailCache(EmailMessage email) async {
    try {
      final emailJson = jsonEncode({
        'id': email.id,
        'from': email.from,
        'subject': email.subject,
        'snippet': email.snippet,
        'body': email.body ?? '',
        'date': email.date.toIso8601String(),
      });
      
      await _storage.write(key: 'email_cache_${email.id}', value: emailJson);
      print('Email cache saved for ${email.id}');
    } catch (e) {
      print('Error saving email cache: $e');
    }
  }

  /// Trích xuất tên người gửi
  String _extractSenderName(String from) {
    final nameMatch = RegExp(r'^"?([^"<]+)"?\s*<').firstMatch(from);
    if (nameMatch != null) {
      return nameMatch.group(1)?.trim() ?? from;
    }
    
    final emailMatch = RegExp(r'^([^@<\s]+)').firstMatch(from);
    return emailMatch?.group(1) ?? from;
  }

  /// Cắt ngắn text
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Reset data (để test lại)
  Future<void> reset() async {
    await _storage.delete(key: _emailIdsKey);
    print('Quick checker data reset');
  }
}
