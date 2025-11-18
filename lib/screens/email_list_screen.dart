import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email_message.dart';
import '../services/gmail_service.dart';
import '../services/auth_service.dart';
import '../services/scan_history_service.dart';
import '../models/scan_result.dart';
import 'imap_setup_screen.dart';
import 'email_detail_screen.dart';
import 'gmail_ai_chat_screen.dart';
import 'compose_email_screen.dart';

class EmailListScreen extends StatefulWidget {
  const EmailListScreen({super.key});

  @override
  State<EmailListScreen> createState() => _EmailListScreenState();
}

class _EmailListScreenState extends State<EmailListScreen> {
  final GmailService _gmailService = GmailService();
  final AuthService _authService = AuthService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  final TextEditingController _searchController = TextEditingController();
  List<EmailMessage> _emails = [];
  List<EmailMessage> _filteredEmails = [];
  Map<String, ScanResult> _scanResults = {}; // Map emailId -> ScanResult
  bool _isLoading = false;
  String? _errorMessage;
  String? _loginMethod;
  String _selectedFolder = 'inbox'; // inbox, sent, trash
  bool _selectionMode = false;
  final Set<String> _selectedEmailIds = <String>{};
  String _searchQuery = '';
  final List<String> _gmailSuggestedQuestions = const [
    'Làm sao nhận diện email lừa đảo trong Gmail?',
    'Khi nhận email đáng ngờ tôi nên làm gì?',
    'Hướng dẫn bảo vệ tài khoản Gmail khỏi bị hack.',
    'Giải thích cách báo cáo spam/phishing trong Gmail.',
  ];

  static const String _emailCacheKeyPrefix = 'email_list_cache_';
  final Map<String, List<EmailMessage>> _folderMemoryCache = {
    'inbox': <EmailMessage>[],
    'sent': <EmailMessage>[],
    'trash': <EmailMessage>[],
  };

  @override
  void initState() {
    super.initState();
    _loadCachedEmails();
    _loadEmails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _buildCacheKey() async {
    final loginMethod = await _authService.getLoginMethod();
    final method = loginMethod ?? 'unknown';
    return '$_emailCacheKeyPrefix${method}_$_selectedFolder';
  }

  Future<void> _loadCachedEmails() async {
    try {
      final currentFolder = _selectedFolder;

      // Ưu tiên cache trong RAM cho cảm giác chuyển tab tức thì
      final memoryEmails = _folderMemoryCache[currentFolder];
      if (memoryEmails != null && memoryEmails.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _emails = memoryEmails;
          _filteredEmails = _filterEmails(memoryEmails);
        });
        return;
      }

      // Nếu RAM trống, fallback đọc từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = await _buildCacheKey();
      final cached = prefs.getStringList(key);
      if (cached == null || !mounted) return;

      final emails = cached
          .map((e) => EmailMessage.fromJson(jsonDecode(e)))
          .toList();

      // Load scan history để giữ màu phân tích đồng bộ với danh sách cache
      final scanHistory = await _scanHistoryService.getScanHistory();
      final scanMap = <String, ScanResult>{};
      for (var scan in scanHistory) {
        scanMap[scan.emailId] = scan;
      }

      if (!mounted) return;
      setState(() {
        _folderMemoryCache[currentFolder] = emails;
        _emails = emails;
        _filteredEmails = _filterEmails(emails);
        _scanResults = scanMap;
      });
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _saveEmailsToCache(List<EmailMessage> emails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _buildCacheKey();
      final data = emails
          .map((e) => jsonEncode(e.toJson()))
          .toList();
      await prefs.setStringList(key, data);
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _loadEmails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Future<void> doFetch() async {
      final folder = _selectedFolder;

      _loginMethod = await _authService.getLoginMethod();

      if (_loginMethod == 'email') {
        final hasCredentials = await _gmailService.hasImapCredentials();
        if (!hasCredentials) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'need_setup';
            });
          }
          return;
        }
      }

      final emails = await _gmailService.fetchEmails(
        maxResults: 20,
        folder: folder,
      );

      final scanHistory = await _scanHistoryService.getScanHistory();
      final scanMap = <String, ScanResult>{};
      for (var scan in scanHistory) {
        scanMap[scan.emailId] = scan;
      }

      if (mounted && _selectedFolder == folder) {
        setState(() {
          _folderMemoryCache[folder] = emails;
          _emails = emails;
          _filteredEmails = _filterEmails(emails);
          _scanResults = scanMap;
          _isLoading = false;
        });
      } else {
        // Nếu user đã chuyển folder trong lúc load, chỉ update cache RAM
        _folderMemoryCache[folder] = emails;
      }

      await _saveEmailsToCache(emails);
    }

    try {
      await doFetch();
    } catch (error) {
      final msg = error.toString();

      if (msg.contains('No access token available')) {
        try {
          await doFetch();
          return;
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = e.toString();
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = msg;
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

    if (!mounted) return;

    if (result == true) {
      _loadEmails();
    }
  }

  List<EmailMessage> _filterEmails(List<EmailMessage> source) {
    final trimmed = _searchQuery.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return List<EmailMessage>.from(source);
    }

    return source.where((email) {
      final subject = email.subject.toLowerCase();
      final from = email.from.toLowerCase();
      return subject.contains(trimmed) || from.contains(trimmed);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container
          (
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm trong email',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF5F6368)),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filteredEmails = _filterEmails(_emails);
                });
              },
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        bottom: TabBar(
          indicatorColor: const Color(0xFF4285F4),
          labelColor: const Color(0xFF4285F4),
          unselectedLabelColor: Colors.grey,
          onTap: (index) {
            String folder;
            switch (index) {
              case 1:
                folder = 'sent';
                break;
              case 2:
                folder = 'trash';
                break;
              default:
                folder = 'inbox';
            }
            if (folder != _selectedFolder) {
              setState(() {
                _selectedFolder = folder;
                _selectionMode = false;
                _selectedEmailIds.clear();

                // Lấy dữ liệu theo folder mới từ cache RAM nếu có
                final cached = _folderMemoryCache[folder] ?? <EmailMessage>[];
                _emails = cached;
                _filteredEmails = _filterEmails(cached);
                _isLoading = cached.isEmpty; // chỉ show loading full nếu chưa có data
                _errorMessage = null;
              });
              // Nếu chưa có trong RAM, thử load nhanh từ SharedPreferences
              if ((_folderMemoryCache[folder] ?? const <EmailMessage>[]).isEmpty) {
                _loadCachedEmails();
              }
              // Luôn refresh nền để lấy dữ liệu mới nhất
              _loadEmails();
            }
          },
          tabs: const [
            Tab(text: 'Hộp thư đến'),
            Tab(text: 'Đã gửi'),
            Tab(text: 'Thùng rác'),
          ],
        ),
        actions: [
          if (_selectedFolder == 'trash' && _selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Khôi phục email đã chọn',
              onPressed: _restoreSelectedEmails,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Thoát chế độ chọn',
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedEmailIds.clear();
                });
              },
            ),
          ] else if (_selectedFolder == 'trash') ...[
            IconButton(
              icon: const Icon(Icons.check_box),
              tooltip: 'Chọn email trong Thùng rác',
              onPressed: () {
                setState(() {
                  _selectionMode = true;
                  _selectedEmailIds.clear();
                });
              },
            ),
          ] else if (_selectedFolder == 'inbox' && _selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Xóa email đã chọn',
              onPressed: _deleteSelectedEmails,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Thoát chế độ chọn',
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedEmailIds.clear();
                });
              },
            ),
          ] else if (_selectedFolder == 'inbox') ...[
            IconButton(
              icon: const Icon(Icons.check_box),
              tooltip: 'Chọn email trong Hộp thư đến',
              onPressed: () {
                setState(() {
                  _selectionMode = true;
                  _selectedEmailIds.clear();
                });
              },
            ),
          ],
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
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final sent = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
            );

            if (!mounted) return;

            if (sent == true) {
              _loadEmails();
            }
          },
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Chỉ hiển thị loading full màn khi chưa có dữ liệu nào
    if (_isLoading && _emails.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage == 'need_setup') {
      return _buildSetupRequired();
    }

    // Chỉ hiển thị màn lỗi nếu không có email nào để show
    if (_errorMessage != null && _emails.isEmpty) {
      return _buildError();
    }

    if (_emails.isEmpty) {
      return _buildEmpty();
    }

    return Column(
      children: [
        Expanded(child: _buildEmailList()),
      ],
    );
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
    final String displayMessage = _buildFriendlyErrorMessage();

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
                displayMessage,
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
    final displayedEmails = _filteredEmails;

    return RefreshIndicator(
      onRefresh: _loadEmails,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: displayedEmails.length + 1,
        separatorBuilder: (context, index) {
          if (index == 0) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildGmailSuggestions();
          }
          final email = displayedEmails[index - 1];
          if (_selectedFolder == 'trash') {
            // Trong Thùng rác: chỉ xem, không vuốt xóa tiếp
            return _buildEmailItem(email);
          }

          return Dismissible(
            key: ValueKey(email.id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Chuyển vào Thùng rác?'),
                  content: const Text('Email sẽ được chuyển vào Thùng rác trong Gmail.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await _gmailService.moveToTrash(email.id);
                  if (mounted) {
                    setState(() {
                      _emails.removeWhere((e) => e.id == email.id);
                      _filteredEmails.removeWhere((e) => e.id == email.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã chuyển email vào Thùng rác'),
                      ),
                    );
                  }
                  return true;
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi xóa email: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return false;
                }
              }
              return false;
            },
            child: _buildEmailItem(email),
          );
        },
      ),
    );
  }

  Future<void> _restoreSelectedEmails() async {
    if (_selectedEmailIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn email nào để khôi phục')),
      );
      return;
    }

    if (_loginMethod != 'google') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khôi phục Thùng rác hiện chỉ hỗ trợ tài khoản Google'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      for (final id in _selectedEmailIds) {
        await _gmailService.restoreFromTrash(id);
      }

      if (mounted) {
        setState(() {
          _emails.removeWhere((e) => _selectedEmailIds.contains(e.id));
          _filteredEmails.removeWhere((e) => _selectedEmailIds.contains(e.id));
          _selectionMode = false;
          _selectedEmailIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã khôi phục email về Hộp thư đến')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khôi phục email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedEmails() async {
    if (_selectedEmailIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn email nào để xóa')),
      );
      return;
    }

    if (_loginMethod != 'google') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xóa nhiều email chỉ hỗ trợ tài khoản Google'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      for (final id in _selectedEmailIds) {
        await _gmailService.moveToTrash(id);
      }

      if (mounted) {
        setState(() {
          _emails.removeWhere((e) => _selectedEmailIds.contains(e.id));
          _filteredEmails.removeWhere((e) => _selectedEmailIds.contains(e.id));
          _selectionMode = false;
          _selectedEmailIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chuyển email vào Thùng rác')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    
    final bool isSelected = _selectedEmailIds.contains(email.id);

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
        leading: _selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedEmailIds.add(email.id);
                    } else {
                      _selectedEmailIds.remove(email.id);
                    }
                  });
                },
              )
            : Stack(
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
        mainAxisSize: MainAxisSize.min,
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
          if (scanResult != null && scanResult.result == 'unknown') ...[
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: Colors.orange[700],
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Phân tích lại email',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailDetailScreen(email: email),
                  ),
                );
              },
            ),
          ],
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
          if (_selectionMode) {
            setState(() {
              if (isSelected) {
                _selectedEmailIds.remove(email.id);
              } else {
                _selectedEmailIds.add(email.id);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailDetailScreen(email: email),
              ),
            );
          }
        },
        onLongPress: () {
          if (_selectionMode) {
            setState(() {
              if (isSelected) {
                _selectedEmailIds.remove(email.id);
              } else {
                _selectedEmailIds.add(email.id);
              }
            });
          } else {
            _showEmailPreview(email);
          }
        },
      ),
    );
  }

  void _showEmailPreview(EmailMessage email) {
    final scanResult = _scanResults[email.id];

    String riskLabel = 'Chưa có đánh giá';
    Color riskColor = Colors.grey;

    if (scanResult != null) {
      if (scanResult.isPhishing) {
        riskLabel = 'NGUY HIỂM';
        riskColor = const Color(0xFFEA4335);
      } else if (scanResult.isSuspicious) {
        riskLabel = 'NGHI NGỜ';
        riskColor = const Color(0xFFFBBC04);
      } else if (scanResult.isSafe) {
        riskLabel = 'AN TOÀN';
        riskColor = const Color(0xFF34A853);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email.subject,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email.from,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(email.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        riskLabel,
                        style: TextStyle(fontSize: 11, color: riskColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Text(
                      email.snippet,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailDetailScreen(email: email),
                          ),
                        );
                      },
                      child: const Text('Mở chi tiết'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  String _buildFriendlyErrorMessage() {
    if (_errorMessage == null) {
      return 'Đã xảy ra lỗi khi tải email. Vui lòng thử lại.';
    }

    final msg = _errorMessage!;

    if (msg.contains('No access token available')) {
      if (_loginMethod == 'google') {
        return 'Không thể lấy quyền truy cập Gmail (token không khả dụng).\n'
            'Có thể do mạng không ổn định hoặc phiên đăng nhập Google đã hết hạn.\n'
            'Vui lòng kiểm tra kết nối, bấm "Thử lại" và nếu vẫn lỗi hãy đăng nhập lại tài khoản Google.';
      }
      return 'Không thể truy cập hộp thư Gmail. Vui lòng thử lại hoặc đăng nhập lại.';
    }

    if (msg.contains('SocketException') ||
        msg.contains('HandshakeException') ||
        msg.contains('Failed host lookup')) {
      return 'Không thể kết nối tới máy chủ email.\n'
          'Có thể kết nối mạng đang yếu hoặc mất. Hãy kiểm tra Internet rồi bấm "Thử lại".';
    }

    return 'Đã xảy ra lỗi khi tải email. Vui lòng thử lại sau.\nChi tiết: $msg';
  }
}
