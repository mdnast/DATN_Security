import 'package:flutter/material.dart';
import '../models/email_message.dart';
import '../services/gmail_service.dart';
import '../services/auth_service.dart';
import '../services/scan_history_service.dart';
import '../models/scan_result.dart';
import 'imap_setup_screen.dart';
import 'email_detail_screen.dart';
import 'gmail_ai_chat_screen.dart';

class EmailListScreen extends StatefulWidget {
  const EmailListScreen({super.key});

  @override
  State<EmailListScreen> createState() => _EmailListScreenState();
}

class _EmailListScreenState extends State<EmailListScreen> {
  final GmailService _gmailService = GmailService();
  final AuthService _authService = AuthService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  List<EmailMessage> _emails = [];
  Map<String, ScanResult> _scanResults = {}; // Map emailId -> ScanResult
  bool _isLoading = false;
  String? _errorMessage;
  String? _loginMethod;
  final List<String> _gmailSuggestedQuestions = const [
    'Làm sao nhận diện email lừa đảo trong Gmail?',
    'Khi nhận email đáng ngờ tôi nên làm gì?',
    'Hướng dẫn bảo vệ tài khoản Gmail khỏi bị hack.',
    'Giải thích cách báo cáo spam/phishing trong Gmail.',
  ];

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _loginMethod = await _authService.getLoginMethod();

      // Check if IMAP credentials are needed
      if (_loginMethod == 'email') {
        final hasCredentials = await _gmailService.hasImapCredentials();
        if (!hasCredentials) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'need_setup';
          });
          return;
        }
      }

      final emails = await _gmailService.fetchEmails(maxResults: 20);
      
      // Load scan history to show colors
      final scanHistory = await _scanHistoryService.getScanHistory();
      final scanMap = <String, ScanResult>{};
      for (var scan in scanHistory) {
        scanMap[scan.emailId] = scan;
      }
      
      if (mounted) {
        setState(() {
          _emails = emails;
          _scanResults = scanMap;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToSetup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImapSetupScreen()),
    );

    if (result == true) {
      _loadEmails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Hộp thư Gmail',
          style: TextStyle(
            color: Color(0xFF202124),
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Chat AI Gmail',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GmailAiChatScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: _isLoading ? Colors.grey : const Color(0xFF4285F4),
            ),
            onPressed: _isLoading ? null : _loadEmails,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage == 'need_setup') {
      return _buildSetupRequired();
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    if (_emails.isEmpty) {
      return _buildEmpty();
    }

    return _buildEmailList();
  }

  Widget _buildSetupRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mail_outline,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Kết nối Gmail',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Để đọc email từ Gmail, bạn cần cấu hình App Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text(
                  'Cấu hình ngay',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'Lỗi tải email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: SelectableText(
                _errorMessage ?? 'Đã xảy ra lỗi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red[900],
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadEmails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Thử lại',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (_loginMethod == 'email') ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _navigateToSetup,
                    icon: const Icon(Icons.settings),
                    label: const Text('Cấu hình lại'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            'Không có email',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList() {
    return RefreshIndicator(
      onRefresh: _loadEmails,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _emails.length + 1,
        separatorBuilder: (context, index) {
          if (index == 0) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildGmailSuggestions();
          }
          final email = _emails[index - 1];
          return _buildEmailItem(email);
        },
      ),
    );
  }

  Widget _buildGmailSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Gợi ý hỏi AI về Gmail',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _gmailSuggestedQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final q = _gmailSuggestedQuestions[index];
              return ActionChip(
                label: Text(
                  q,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GmailAiChatScreen(
                        initialQuestion: q,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmailItem(EmailMessage email) {
    // Kiểm tra email đã được scan chưa
    final scanResult = _scanResults[email.id];
    
    // Xác định màu sắc dựa trên kết quả scan
    Color? borderColor;
    Color? bgColor;
    IconData? statusIcon;
    
    if (scanResult != null) {
      // ✅ FIX: Tính toán lại màu dựa vào riskScore thay vì tin vào result string cũ
      // Lấy riskScore từ analysisDetails (0-1 scale)
      final riskScore = scanResult.analysisDetails['riskScore'] as double? ?? 0.5;
      final riskScorePercent = riskScore * 100; // Convert sang 0-100
      
      // Phân loại lại theo logic mới: 0-25 = safe, 26-50 = suspicious, 51-100 = phishing
      if (riskScorePercent < 26) {
        // AN TOÀN - Xanh lá
        borderColor = const Color(0xFF34A853);
        bgColor = const Color(0xFFE8F5E9);
        statusIcon = Icons.check_circle;
      } else if (riskScorePercent < 51) {
        // NGHI NGỜ - Vàng
        borderColor = const Color(0xFFFBBC04);
        bgColor = const Color(0xFFFFFAE6);
        statusIcon = Icons.warning_amber;
      } else {
        // NGUY HIỂM - Đỏ
        borderColor = const Color(0xFFEA4335);
        bgColor = const Color(0xFFFEF3F2);
        statusIcon = Icons.dangerous;
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null 
            ? Border.all(color: borderColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? Colors.black).withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor:
                  borderColor?.withValues(alpha: 0.15) ?? const Color(0xFFE8F0FE),
              child: Text(
                email.from.isNotEmpty ? email.from[0].toUpperCase() : '?',
                style: TextStyle(
                  color: borderColor ?? const Color(0xFF4285F4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (statusIcon != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    size: 14,
                    color: borderColor,
                  ),
                ),
              ),
          ],
        ),
      title: Text(
        email.subject,
        style: TextStyle(
          fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            email.from,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email.snippet,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(email.date),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (!email.isRead) ...[
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4285F4),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailDetailScreen(email: email),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
