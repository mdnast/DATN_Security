import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/notification_model.dart';
import '../models/email_message.dart';
import '../services/notification_service.dart';
import '../services/gmail_service.dart';
import 'email_detail_screen.dart';
import '../localization/app_localizations.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final GmailService _gmailService = GmailService();
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = _notificationService.getNotifications();
    });
  }

  Future<void> _handleMarkAsRead(String id) async {
    await _notificationService.markAsRead(id);
    _loadNotifications();
  }

  Future<void> _handleDelete(String id) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.t('notifications_delete_title')),
        content: Text(l.t('notifications_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('notifications_action_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.t('notifications_action_delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.deleteNotification(id);
      _loadNotifications();
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    await _notificationService.markAllAsRead();
    _loadNotifications();
  }

  /// ✅ NAVIGATE ĐẾN EMAIL DETAIL KHI TAP NOTIFICATION
  Future<void> _handleNotificationTap(NotificationModel notification) async {
    try {
      print('=== NOTIFICATION TAPPED IN LIST ===');
      print('Type: ${notification.type}');
      print('Data: ${notification.data}');
      
      // Kiểm tra xem notification có email data không
      if (notification.data == null || notification.data!['email_id'] == null) {
        print('⚠️ No email data in notification');
        _showErrorSnackbar(
          AppLocalizations.of(context)
              .t('email_list_error_cannot_open_email'),
        );
        return;
      }

      final emailId = notification.data!['email_id'];
      print('Email ID: $emailId');
      
      // Hiển thị loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      EmailMessage? email;
      
      // 1. Thử load từ cache trước
      final emailCacheJson = await _storage.read(key: 'email_cache_$emailId');
      
      if (emailCacheJson != null) {
        print('✅ Email found in cache');
        final emailData = jsonDecode(emailCacheJson);
        email = EmailMessage(
          id: emailData['id'],
          from: emailData['from'],
          subject: emailData['subject'],
          snippet: emailData['snippet'] ?? '',
          body: emailData['body'] ?? emailData['snippet'] ?? '',
          date: DateTime.parse(emailData['date']),
          photoUrl: emailData['photoUrl'],
        );
      } else {
        print('⚠️ Email not in cache, fetching from Gmail...');
        
        // 2. Nếu không có cache, fetch từ Gmail
        try {
          final gmailEmails = await _gmailService.fetchEmails(maxResults: 50);
          final foundEmail = gmailEmails.where((e) => e.id == emailId).firstOrNull;
          
          if (foundEmail != null) {
            print('✅ Email fetched from Gmail');
            email = foundEmail;
            
            // Lưu vào cache cho lần sau
            final emailJson = jsonEncode({
              'id': email.id,
              'from': email.from,
              'subject': email.subject,
              'snippet': email.snippet,
              'body': email.body ?? email.snippet,
              'date': email.date.toIso8601String(),
              'photoUrl': email.photoUrl,
            });
            await _storage.write(key: 'email_cache_$emailId', value: emailJson);
            print('Email cached for future use');
          } else {
            print('❌ Email not found in Gmail');
            // 3. Fallback cuối cùng: tạo từ notification data
            email = EmailMessage(
              id: emailId,
              from: notification.data!['from'] ?? 'Unknown',
              subject: notification.data!['subject'] ?? 'No subject',
              snippet: notification.data!['snippet'] ?? notification.body,
              body: notification.data!['body'] ?? notification.data!['snippet'] ?? '',
              date: DateTime.parse(
                notification.data!['date'] ?? 
                notification.data!['timestamp'] ?? 
                DateTime.now().toIso8601String()
              ),
              photoUrl: notification.data!['photoUrl'],
            );
            print('⚠️ Using notification data as fallback');
          }
        } catch (gmailError) {
          print('❌ Gmail fetch error: $gmailError');
          // Fallback: dùng notification data
          email = EmailMessage(
            id: emailId,
            from: notification.data!['from'] ?? 'Unknown',
            subject: notification.data!['subject'] ?? 'No subject',
            snippet: notification.data!['snippet'] ?? notification.body,
            body: notification.data!['body'] ?? notification.data!['snippet'] ?? '',
            date: DateTime.parse(
              notification.data!['date'] ?? 
              notification.data!['timestamp'] ?? 
              DateTime.now().toIso8601String()
            ),
            photoUrl: notification.data!['photoUrl'],
          );
          print('Using notification data after Gmail error');
        }
      }

      // Đóng loading
      if (mounted) {
        Navigator.pop(context);
      }

      print('✅ Navigating to EmailDetailScreen...');
      
      // Navigate đến EmailDetailScreen
      if (mounted && email != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailDetailScreen(email: email!),
          ),
        );
        print('✅ Navigation completed');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling notification tap: $e');
      print('Stack trace: $stackTrace');
      
      // Đóng loading nếu đang mở
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      _showErrorSnackbar(
        AppLocalizations.of(context)
            .t('notifications_error_open_email')
            .replaceFirst('{error}', e.toString()),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleClearAll() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.t('notifications_delete_all_title')),
        content: Text(l.t('notifications_delete_all_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('notifications_action_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.t('notifications_action_delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAll();
      _loadNotifications();
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'phishing':
        return Icons.warning;
      case 'safe':
        return Icons.check_circle;
      case 'scan_complete':
        return Icons.done_all;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'phishing':
        return Colors.red;
      case 'safe':
        return Colors.green;
      case 'scan_complete':
        return Colors.blue;
      case 'security':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRelativeTime(DateTime timestamp) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return l.t('notifications_relative_just_now');
    } else if (difference.inHours < 1) {
      return l
          .t('notifications_relative_minutes_ago')
          .replaceFirst('{minutes}', difference.inMinutes.toString());
    } else if (difference.inDays < 1) {
      return l
          .t('notifications_relative_hours_ago')
          .replaceFirst('{hours}', difference.inHours.toString());
    } else if (difference.inDays < 7) {
      return l
          .t('notifications_relative_days_ago')
          .replaceFirst('{days}', difference.inDays.toString());
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('notifications_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (unreadCount > 0)
              Text(
                l
                    .t('notifications_unread_count')
                    .replaceFirst('{count}', unreadCount.toString()),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            if (unreadCount > 0)
              TextButton(
                onPressed: _handleMarkAllAsRead,
                child: Text(l.t('notifications_action_mark_read')),
              ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text(l.t('notifications_action_clear_all')),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'clear') {
                  _handleClearAll();
                }
              },
            ),
          ],
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: theme.colorScheme.onBackground.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                l.t('notifications_empty_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                l.t('notifications_empty_body'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _loadNotifications();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final color = _getColorForType(notification.type);
                  final icon = _getIconForType(notification.type);

                  return Dismissible(
                    key: Key(notification.id),
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        await _handleMarkAsRead(notification.id);
                        return false;
                      } else {
                        return true;
                      }
                    },
                    onDismissed: (direction) {
                      _notificationService.deleteNotification(notification.id);
                      _loadNotifications();
                    },
                    child: Card(
                      elevation: notification.isRead ? 0 : 2,
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      color: notification.isRead
                          ? theme.cardColor
                          : (isDark
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.blue[50]),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: notification.isRead
                              ? theme.dividerColor
                              : (isDark
                                  ? theme.colorScheme.primary
                                  : Colors.blue[100]!),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () async {
                          // Mark as read
                          if (!notification.isRead) {
                            await _handleMarkAsRead(notification.id);
                          }
                          
                          // ✅ NAVIGATE ĐẾN EMAIL DETAIL
                          await _handleNotificationTap(notification);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: notification.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.bold,
                                              color: theme
                                                  .textTheme.titleSmall?.color,
                                            ),
                                          ),
                                        ),
                                        if (!notification.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.8),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _getRelativeTime(
                                              notification.timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color
                                                ?.withOpacity(0.7),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 20),
                                          color: theme.iconTheme.color
                                              ?.withOpacity(0.7),
                                          onPressed: () =>
                                              _handleDelete(notification.id),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}