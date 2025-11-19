import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email_message.dart';
import '../services/gmail_service.dart';
import '../services/auth_service.dart';
import '../services/scan_history_service.dart';
import '../models/scan_result.dart';
import '../localization/app_localizations.dart';
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
  final List<String> _gmailSuggestedQuestionKeys = const [
    'gmail_ai_suggestion_1',
    'gmail_ai_suggestion_2',
    'gmail_ai_suggestion_3',
    'gmail_ai_suggestion_4',
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
    super.dispose();
  }

  Color _avatarColorFor(String from) {
    // Tạo màu avatar mềm kiểu Gmail dựa trên email người gửi
    const colors = <Color>[
      Color(0xFF1E88E5),
      Color(0xFFD81B60),
      Color(0xFF8E24AA),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF6D4C41),
      Color(0xFF3949AB),
      Color(0xFF00897B),
    ];

    if (from.isEmpty) return const Color(0xFF4285F4);

    final hash = from.codeUnits.fold<int>(0, (prev, code) => prev + code);
    return colors[hash % colors.length];
  }

  String _decodeHtmlEntities(String input) {
    if (input.isEmpty) return input;

    var result = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        try {
          final code = int.parse(m.group(1)!);
          return String.fromCharCode(code);
        } catch (_) {
          return m.group(0)!;
        }
      },
    );

    return result;
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
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF202124);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.t('app_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 6),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF1877F2),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: onSurface.withOpacity(0.6),
            onTap: changeFolderByTabIndex,
            tabs: [
              Tab(text: l.t('email_list_tab_inbox')),
              Tab(text: l.t('email_list_tab_sent')),
              Tab(text: l.t('email_list_tab_trash')),
            ],
          ),
          actions: [
            if (_selectedFolder == 'trash' && _selectionMode) ...[
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: l.t('email_list_restore_selected'),
                onPressed: _restoreSelectedEmails,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l.t('email_list_exit_selection'),
                onPressed: exitSelectionMode,
              ),
            ] else if (_selectedFolder == 'trash') ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l.t('email_list_trash_select'),
                onPressed: enterSelectionMode,
              ),
            ] else if (_selectedFolder == 'inbox' && _selectionMode) ...[
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: l.t('email_list_delete_selected'),
                onPressed: _deleteSelectedEmails,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l.t('email_list_exit_selection'),
                onPressed: exitSelectionMode,
              ),
            ] else if (_selectedFolder == 'inbox') ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l.t('email_list_inbox_select'),
                onPressed: enterSelectionMode,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: l.t('gmail_ai_chat_title'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GmailAiChatScreen(),
                  ),
                );
              },
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

  // Public API để HomeScreen điều khiển tìm kiếm, folder và thao tác chọn
  String get selectedFolder => _selectedFolder;
  bool get selectionMode => _selectionMode;
  bool get isLoading => _isLoading;

  void updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
      _filteredEmails = _filterEmails(_emails);
    });
  }

  Future<void> refreshEmails() async {
    await _loadEmails();
  }

  void changeFolderByTabIndex(int index) {
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

        final cached = _folderMemoryCache[folder] ?? <EmailMessage>[];
        _emails = cached;
        _filteredEmails = _filterEmails(cached);
        _isLoading = cached.isEmpty;
        _errorMessage = null;
      });

      if ((_folderMemoryCache[folder] ?? const <EmailMessage>[]).isEmpty) {
        _loadCachedEmails();
      }

      _loadEmails();
    }
  }

  void enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedEmailIds.clear();
    });
  }

  void exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedEmailIds.clear();
    });
  }

  Future<void> deleteSelectedEmailsFromOutside() async {
    await _deleteSelectedEmails();
  }

  Future<void> restoreSelectedEmailsFromOutside() async {
    await _restoreSelectedEmails();
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
    final l = AppLocalizations.of(context);
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
            Text(
              l.t('email_list_setup_title'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.t('email_list_setup_description'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                label: Text(
                  l.t('email_list_setup_button'),
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final l = AppLocalizations.of(context);
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
            Text(
              l.t('email_list_error_title'),
              style: const TextStyle(
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
                  label: Text(
                    l.t('email_list_error_retry'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (_loginMethod == 'email') ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _navigateToSetup,
                    icon: const Icon(Icons.settings),
                    label: Text(l.t('email_list_error_reconfigure')),
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
    final l = AppLocalizations.of(context);
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
          Text(
            l.t('email_list_empty_title'),
            style: const TextStyle(
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
    final l = AppLocalizations.of(context);

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
                  title: Text(l.t('email_list_delete_confirm_title')),
                  content: Text(l.t('email_list_delete_confirm_message')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.t('common_cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.t('common_ok')),
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
                      SnackBar(
                        content: Text(
                          l.t('email_list_snackbar_moved_to_trash'),
                        ),
                      ),
                    );
                  }
                  return true;
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l
                              .t('email_list_snackbar_delete_error')
                              .replaceFirst('{error}', e.toString()),
                        ),
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
    final l = AppLocalizations.of(context);
    if (_selectedEmailIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('email_list_snackbar_no_selected_restore'))),
      );
      return;
    }

    if (_loginMethod != 'google') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(l.t('email_list_snackbar_restore_google_only')),
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
          SnackBar(content: Text(l.t('email_list_snackbar_restored'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedEmails() async {
    final l = AppLocalizations.of(context);
    if (_selectedEmailIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('email_list_snackbar_no_selected_delete'))),
      );
      return;
    }

    if (_loginMethod != 'google') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(l.t('email_list_snackbar_delete_google_only')),
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
          SnackBar(content: Text(l.t('email_list_snackbar_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l
                  .t('email_list_snackbar_delete_error')
                  .replaceFirst('{error}', e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGmailSuggestions() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l.t('gmail_ai_suggestions_title'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _gmailSuggestedQuestionKeys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final key = _gmailSuggestedQuestionKeys[index];
              final q = l.t(key);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

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
        if (!isDark) {
          bgColor = const Color(0xFFE8F5E9);
        }
        statusIcon = Icons.check_circle;
      } else if (riskScorePercent < 51) {
        // NGHI NGỜ - Vàng
        borderColor = const Color(0xFFFBBC04);
        if (!isDark) {
          bgColor = const Color(0xFFFFFAE6);
        }
        statusIcon = Icons.warning_amber;
      } else {
        // NGUY HIỂM - Đỏ
        borderColor = const Color(0xFFEA4335);
        if (!isDark) {
          bgColor = const Color(0xFFFEF3F2);
        }
        statusIcon = Icons.dangerous;
      }
    }

    final baseAvatarColor = _avatarColorFor(email.from);
    
    final bool isSelected = _selectedEmailIds.contains(email.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? theme.colorScheme.surface,
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
            : _SenderAvatar(
                email: email,
                borderColor: borderColor,
                baseAvatarColor: baseAvatarColor,
                statusIcon: statusIcon,
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
            _decodeHtmlEntities(email.snippet),
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
              tooltip: l.t('email_detail_reanalyze'),
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
    final l = AppLocalizations.of(context);
    final scanResult = _scanResults[email.id];

    String riskLabel = 'Chưa có đánh giá';
    Color riskColor = Colors.grey;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        color: isDark ? Colors.transparent : riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: riskColor),
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
                      _decodeHtmlEntities(email.snippet),
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
                      child: Text(l.t('email_list_preview_open_detail')),
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
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return l.t('email_list_date_yesterday');
    } else if (difference.inDays < 7) {
      return l
          .t('email_list_date_days_ago')
          .replaceFirst('{days}', difference.inDays.toString());
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

class _SenderAvatar extends StatefulWidget {
  final EmailMessage email;
  final Color? borderColor;
  final Color baseAvatarColor;
  final IconData? statusIcon;

  const _SenderAvatar({
    required this.email,
    required this.borderColor,
    required this.baseAvatarColor,
    required this.statusIcon,
  });

  @override
  State<_SenderAvatar> createState() => _SenderAvatarState();
}

class _SenderAvatarState extends State<_SenderAvatar> {
  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColor;
    final baseColor = widget.baseAvatarColor;
    final statusIcon = widget.statusIcon;

    final backgroundColor =
        borderColor?.withValues(alpha: 0.16) ?? baseColor.withValues(alpha: 0.16);

    final avatar = CircleAvatar(
      backgroundColor: backgroundColor,
      child: Text(
        widget.email.from.isNotEmpty
            ? widget.email.from[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: borderColor ?? baseColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return Stack(
      children: [
        avatar,
        if (statusIcon != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
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
    );
  }
}

