import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/notification_model.dart';
import '../models/email_message.dart';
import '../screens/email_detail_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _notificationsKey = 'notifications';
  static const String _notifiedEmailIdsKey = 'notified_email_ids';
  List<NotificationModel> _notifications = [];
  Set<String> _notifiedEmailIds = <String>{};
  
  // GlobalKey để navigate từ notification
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Set navigator key để có thể navigate từ notification
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await _loadNotifications();
    await _loadNotifiedEmailIds();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'phishing_alerts',
      'Phishing Alerts',
      description: 'Thông báo về email phishing và bảo mật',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    showNotification(
      title: message.notification?.title ?? 'Thông báo',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
      data: message.data,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Notification opened: ${message.messageId}');
  }

  Future<void> _showLocalNotification(NotificationModel notification) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'phishing_alerts',
      'Phishing Alerts',
      channelDescription: 'Thông báo về email phishing và bảo mật',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // Encode notification data as payload
    final payload = notification.data != null 
        ? jsonEncode(notification.data)
        : null;

    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  void _onNotificationTapped(NotificationResponse response) async {
    print('=== NOTIFICATION TAPPED ===');
    print('Payload: ${response.payload}');
    
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        final action = data['action'];
        
        if (action == 'open_email_detail') {
          await _navigateToEmailDetail(data);
        }
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  /// Navigate đến email detail screen khi tap notification
  Future<void> _navigateToEmailDetail(Map<String, dynamic> data) async {
    try {
      final emailId = data['email_id'];
      if (emailId == null) {
        print('No email_id in notification data');
        return;
      }

      // Load email từ cache
      final emailCacheJson = await _storage.read(key: 'email_cache_$emailId');
      
      EmailMessage? email;
      if (emailCacheJson != null) {
        final emailData = jsonDecode(emailCacheJson);
        email = EmailMessage(
          id: emailData['id'],
          from: emailData['from'],
          subject: emailData['subject'],
          snippet: emailData['snippet'],
          body: emailData['body'],
          date: DateTime.parse(emailData['date']),
        );
      } else {
        // Fallback: tạo email từ notification data
        email = EmailMessage(
          id: emailId,
          from: data['from'] ?? 'Unknown',
          subject: data['subject'] ?? 'No subject',
          snippet: data['snippet'] ?? '',
          body: data['body'] ?? '',
          date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
        );
      }

      // Navigate đến EmailDetailScreen
      if (_navigatorKey?.currentContext != null) {
        await Navigator.push(
          _navigatorKey!.currentContext!,
          MaterialPageRoute(
            builder: (context) => EmailDetailScreen(email: email!),
          ),
        );
        print('✅ Navigated to email detail: $emailId');
      } else {
        print('⚠️ Navigator context is null');
      }
    } catch (e) {
      print('Error navigating to email detail: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = await _getCurrentUserId();
      final String key = userId != null
          ? '${_notificationsKey}_$userId'
          : _notificationsKey;

      final notificationsJson = prefs.getStringList(key) ?? [];
      
      _notifications = notificationsJson
          .map((json) => NotificationModel.fromJson(jsonDecode(json)))
          .toList();
      
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      print('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> _loadNotifiedEmailIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = await _getCurrentUserId();
      final String key = userId != null
          ? '${_notifiedEmailIdsKey}_$userId'
          : _notifiedEmailIdsKey;

      final ids = prefs.getStringList(key) ?? [];
      _notifiedEmailIds = ids.toSet();
    } catch (e) {
      print('Error loading notified email ids: $e');
      _notifiedEmailIds = <String>{};
    }
  }

  Future<void> _saveNotifiedEmailIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = await _getCurrentUserId();
      final String key = userId != null
          ? '${_notifiedEmailIdsKey}_$userId'
          : _notifiedEmailIdsKey;

      await prefs.setStringList(key, _notifiedEmailIds.toList());
    } catch (e) {
      print('Error saving notified email ids: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _notifications
          .map((notification) => jsonEncode(notification.toJson()))
          .toList();

      final String? userId = await _getCurrentUserId();
      final String key = userId != null
          ? '${_notificationsKey}_$userId'
          : _notificationsKey;

      await prefs.setStringList(key, notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  Future<void> addNotification(NotificationModel notification) async {
    _notifications.insert(0, notification);
    
    if (_notifications.length > 50) {
      _notifications = _notifications.sublist(0, 50);
    }
    
    await _saveNotifications();
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    // Nếu notification gắn với 1 email cụ thể, đảm bảo chỉ gửi 1 lần cho mỗi email_id
    String? emailId;
    if (data != null) {
      final dynamic rawId = data['email_id'] ?? data['emailId'];
      if (rawId is String && rawId.isNotEmpty) {
        emailId = rawId;
        if (_notifiedEmailIds.contains(emailId)) {
          print('⏭️ Skip duplicate notification for email: $emailId');
          return;
        }
        _notifiedEmailIds.add(emailId);
        await _saveNotifiedEmailIds();
      }
    }

    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );

    await addNotification(notification);
    await _showLocalNotification(notification);
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications
        .map((notification) => notification.copyWith(isRead: true))
        .toList();
    await _saveNotifications();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
  }

  List<NotificationModel> getNotifications() {
    return List.unmodifiable(_notifications);
  }

  int getUnreadCount() {
    return _notifications.where((n) => !n.isRead).length;
  }

  Stream<List<NotificationModel>> get notificationsStream async* {
    yield _notifications;
  }

  /// Lấy userId hiện tại từ SharedPreferences (đã được AuthService lưu)
  Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return null;

      final Map<String, dynamic> userData =
          jsonDecode(userDataString) as Map<String, dynamic>;
      final dynamic uid = userData['uid'];

      if (uid is String && uid.isNotEmpty) {
        return uid;
      }
    } catch (e) {
      print('Error getting current user id for notifications: $e');
    }
    return null;
  }
}
