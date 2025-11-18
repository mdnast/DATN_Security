import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'gmail_service.dart';
import 'email_analysis_service.dart';
import 'notification_service.dart';
import 'scan_history_service.dart';
import '../models/email_message.dart';
import 'dart:convert';
import 'auto_analysis_settings_service.dart';

/// Background service để check email và phân tích ngay cả khi app đóng
class BackgroundEmailService {
  static const String _taskName = 'emailCheckTask';
  static const String _emailIdsKey = 'background_email_ids';
  
  /// Khởi tạo WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Bật logs để debug, tắt khi release
    );
  }

  /// Đăng ký periodic task - CHECK MỖI 15 PHÚT (minimum Android)
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15), // ✅ 15 PHÚT (minimum Android cho phép)
      constraints: Constraints(
        networkType: NetworkType.connected, // Cần internet
        requiresBatteryNotLow: false, // Chạy kể cả pin yếu
        requiresCharging: false, // Không cần sạc
      ),
      initialDelay: const Duration(minutes: 1), // Chạy lần đầu sau 1 phút
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    
    print('✅ Background email check registered - runs every 15 minutes');
    print('💡 15 phút là minimum Android cho phép');
  }

  /// Hủy task
  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(_taskName);
    print('❌ Background email check cancelled');
  }

  /// Hủy tất cả tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    print('❌ All background tasks cancelled');
  }
}

/// Callback chạy trong background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('=== BACKGROUND TASK STARTED ===');
    print('Task: $task');
    print('Time: ${DateTime.now()}');

    try {
      // Check và phân tích emails mới
      await _checkAndAnalyzeEmails();
      
      print('✅ Background task completed successfully');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Logic chính: Check emails và tự động phân tích
Future<void> _checkAndAnalyzeEmails() async {
  final storage = const FlutterSecureStorage();
  final gmailService = GmailService();
  final analysisService = EmailAnalysisService();
  final notificationService = NotificationService();
  final scanHistoryService = ScanHistoryService();

  // Initialize notification service
  await notificationService.initialize();

  try {
    print('Fetching latest emails...');
    
    // Fetch 5 emails mới nhất (giảm xuống để tối ưu background task)
    final emails = await gmailService.fetchEmails(maxResults: 5);
    
    if (emails.isEmpty) {
      print('No emails found');
      return;
    }

    // Danh sách ID hiện tại
    final currentIds = emails.map((e) => e.id).toList();

    // Load danh sách email IDs đã check
    final previousIdsJson =
        await storage.read(key: BackgroundEmailService._emailIdsKey);

    // Lần đầu chạy: chỉ lưu baseline, KHÔNG phân tích các email cũ
    if (previousIdsJson == null || previousIdsJson.isEmpty) {
      await storage.write(
        key: BackgroundEmailService._emailIdsKey,
        value: currentIds.join(','),
      );
      print(
          'First background check - initialized baseline with ${currentIds.length} emails, no analysis to avoid scanning old emails.');
      return;
    }

    final previousIds = previousIdsJson.split(',');

    // Lọc emails mới
    final newEmails = emails
        .where((email) => !previousIds.contains(email.id))
        .toList();

    if (newEmails.isEmpty) {
      print('No new emails');
      return;
    }

    print('Found ${newEmails.length} new email(s)!');

    final autoSettings = AutoAnalysisSettingsService();
    final autoEnabled = await autoSettings.isAutoAnalysisEnabled();

    if (!autoEnabled) {
      print('ℹ️ Auto analysis disabled - sending new email notifications only');
      for (var email in newEmails) {
        await notificationService.showNotification(
          title: '📧 Email mới',
          body: 'Từ ${_extractSenderName(email.from)}: "${email.subject}"',
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
        await _saveEmailCache(storage, email);
      }
    } else {
      // Phân tích từng email mới
      for (var email in newEmails) {
        await _analyzeAndNotify(
          email,
          analysisService,
          notificationService,
          scanHistoryService,
          storage,
        );
      }
    }

    // Cập nhật danh sách IDs với snapshot hiện tại
    await storage.write(
      key: BackgroundEmailService._emailIdsKey,
      value: currentIds.join(','),
    );

    print('Updated email IDs list');
  } catch (e) {
    print('Error in background check: $e');
    // Không throw để task không fail
  }
}

/// Phân tích email và hiển thị notification với kết quả
Future<void> _analyzeAndNotify(
  EmailMessage email,
  EmailAnalysisService analysisService,
  NotificationService notificationService,
  ScanHistoryService scanHistoryService,
  FlutterSecureStorage storage,
) async {
  try {
    print('Analyzing email: ${email.subject}');
    
    // Nếu email đã được phân tích (và không phải unknown) thì bỏ qua để tiết kiệm token
    final latestScan = await scanHistoryService.getLatestScanForEmail(email.id);
    if (latestScan != null && latestScan.result != 'unknown') {
      print('ℹ️ Email already analyzed (background), skipping AI: ${email.subject}');
      return;
    }
    
    // Phân tích email bằng AI
    final result = await analysisService.analyzeEmail(email);
    
    // ✅ LƯU KẾT QUẢ PHÂN TÍCH VÀO SCAN HISTORY
    await scanHistoryService.saveScanResult(result);
    print('✅ Analysis result saved to history');
    
    // Lưu thông tin email để có thể truy cập khi tap notification
    await _saveEmailCache(storage, email);
    
    // Tạo notification dựa trên kết quả phân tích
    String title;
    String body;
    String type;
    
    if (result.isPhishing) {
      // Email nguy hiểm - PHISHING
      title = '🚨 CẢNH BÁO: Email phishing!';
      body = 'Từ ${_extractSenderName(email.from)}: "${email.subject}"\n'
             '⚠️ Độ nguy hiểm: ${(result.confidenceScore * 100).toInt()}%';
      type = 'phishing';
      
      print('⚠️ PHISHING DETECTED: ${email.subject}');
    } else if (result.isSuspicious) {
      // Email nghi ngờ - SUSPICIOUS
      title = '⚠️ Email nghi ngờ';
      body = 'Từ ${_extractSenderName(email.from)}: "${email.subject}"\n'
             '🔍 Mức độ nghi ngờ: ${(result.confidenceScore * 100).toInt()}%';
      type = 'suspicious';
      
      print('⚠️ SUSPICIOUS EMAIL: ${email.subject}');
    } else {
      // Email an toàn - SAFE
      title = '✅ Email an toàn';
      body = 'Từ ${_extractSenderName(email.from)}: "${email.subject}"\n'
             '✓ Độ an toàn: ${(result.confidenceScore * 100).toInt()}%';
      type = 'safe';
      
      print('✅ SAFE EMAIL: ${email.subject}');
    }

    // Hiển thị notification với đầy đủ thông tin để navigate
    await notificationService.showNotification(
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

    print('✅ Notification sent');
  } catch (e) {
    print('Error analyzing email: $e');
    
    // Lưu email cache ngay cả khi phân tích lỗi
    await _saveEmailCache(storage, email);
    
    // Nếu phân tích lỗi, vẫn thông báo có email mới
    await notificationService.showNotification(
      title: '📧 Email mới',
      body: 'Từ ${_extractSenderName(email.from)}: "${email.subject}"',
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

/// Lưu cache email để có thể truy cập từ notification
Future<void> _saveEmailCache(FlutterSecureStorage storage, EmailMessage email) async {
  try {
    final emailJson = jsonEncode({
      'id': email.id,
      'from': email.from,
      'subject': email.subject,
      'snippet': email.snippet,
      'body': email.body ?? '',
      'date': email.date.toIso8601String(),
    });
    
    // Lưu với key là email_id
    await storage.write(key: 'email_cache_${email.id}', value: emailJson);
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
