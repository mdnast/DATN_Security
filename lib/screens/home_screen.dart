import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/email_monitor_service.dart';
import '../services/background_email_service.dart';
import '../services/quick_email_checker.dart';
import '../services/auto_analysis_settings_service.dart';
import 'email_list_screen.dart';
import 'notification_screen.dart';
import 'statistics_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final NotificationService _notificationService = NotificationService();
  final EmailMonitorService _emailMonitorService = EmailMonitorService();
  final QuickEmailChecker _quickChecker = QuickEmailChecker();
  final AutoAnalysisSettingsService _autoAnalysisSettings = AutoAnalysisSettingsService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _autoAnalysisEnabled = true;
  int _unreadNotificationCount = 0;
  bool _isChecking = false; // Track checking state
  bool _isDisposed = false; // ✅ Track dispose state

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationCount();
    _startEmailMonitoring();
    
    // ✅ CHECK 1 LẦN KHI MỞ APP (sau 5 giây)
    // Đây là lần check duy nhất khi app mở
    // Sau đó chỉ có background monitoring (30 phút) hoặc manual check
    Future.delayed(const Duration(seconds: 5), () {
      // ✅ Double check: mounted và not disposed
      if (mounted && !_isDisposed) {
        print('🔄 Checking emails once on app open...');
        _checkEmailsNow();
      } else {
        print('⚠️ HomeScreen disposed before check');
      }
    });
  }

  @override
  void dispose() {
    print('🔴 HomeScreen disposing...');
    _isDisposed = true; // ✅ Mark as disposed
    
    // ✅ Stop foreground monitoring khi thoát
    _emailMonitorService.stopMonitoring();
    
    super.dispose();
    print('🔴 HomeScreen disposed');
  }

  /// Bật monitoring email mới - NHANH & NGẦM (1 phút + 15 phút)
  Future<void> _startEmailMonitoring() async {
    print('==========================================');
    print('🚀 STARTING EMAIL MONITORING');
    print('==========================================');
    
    try {
      // ✅ Foreground: Check mỗi 1 PHÚT
      // → Notification NHANH
      // → Phân tích ngầm (không hiện UI)
      
      print('📱 Starting foreground monitoring (1 min interval)...');
      await _emailMonitorService.startMonitoring();
      print('✅ Foreground: Check mỗi 1 PHÚT (notification nhanh)');
      
      // Background monitoring - check mỗi 15 PHÚT
      print('🌙 Registering background monitoring...');
      await BackgroundEmailService.registerPeriodicTask();
      print('✅ Background: Check mỗi 15 PHÚT (khi app đóng)');
      
      print('==========================================');
      print('🎉 MONITORING STARTED');
      print('📌 Notification: NHANH | Phân tích: NGẦM');
      print('==========================================');
      
    } catch (e) {
      print('==========================================');
      print('❌ FAILED TO START MONITORING');
      print('Error: $e');
      print('Stack trace:');
      print(StackTrace.current);
      print('==========================================');
      
      // Chỉ thông báo khi có lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Lỗi khởi động monitoring: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Check emails ngay lập tức với AI analysis
  Future<void> _checkEmailsNow() async {
    // ✅ Safety check trước khi bắt đầu
    if (!mounted || _isDisposed) {
      print('⚠️ HomeScreen not mounted, skipping check');
      return;
    }
    
    if (_isChecking) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Đang check email, vui lòng đợi...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // ✅ Safe setState
    if (mounted && !_isDisposed) {
      setState(() => _isChecking = true);
    }

    // ❌ KHÔNG HIỆN SNACKBAR - phân tích ngầm
    // User sẽ nhận notification trực tiếp

    try {
      print('=== CHECKING EMAILS NOW ===');
      final newEmailCount = await _quickChecker.checkAndAnalyzeNow();
      print('Found $newEmailCount new emails');
      
      // ✅ Check again after async operation
      if (mounted && !_isDisposed) {
        if (newEmailCount > 0) {
          // ✅ Chỉ reload notification count, KHÔNG hiện SnackBar
          _loadNotificationCount();
          print('✅ $newEmailCount email mới - notification đã gửi');
        } else {
          print('✓ Không có email mới');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error checking emails: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // ✅ Safe setState in finally
      if (mounted && !_isDisposed) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _loadNotificationCount() {
    if (!mounted || _isDisposed) return; // ✅ Safety check
    
    setState(() {
      _unreadNotificationCount = _notificationService.getUnreadCount();
    });
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getCurrentUser();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final autoAnalysisEnabled = await _autoAnalysisSettings.isAutoAnalysisEnabled();
    
    // ✅ Safety check: mounted và not disposed
    if (mounted && !_isDisposed) {
      setState(() {
        _userData = data;
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
        _autoAnalysisEnabled = autoAnalysisEnabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAutoAnalysis(bool value) async {
    await _autoAnalysisSettings.setAutoAnalysisEnabled(value);

    if (mounted && !_isDisposed) {
      setState(() {
        _autoAnalysisEnabled = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Đã bật tự động phân tích email mới'
                : 'Đã tắt tự động phân tích email mới',
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final result = await _biometricService.authenticate();
      if (!result.success) {
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Xác thực thất bại'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    await _biometricService.setBiometricEnabled(value);
    
    // ✅ Safety check
    if (mounted && !_isDisposed) {
      setState(() {
        _biometricEnabled = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Đã bật xác thực vân tay'
                : 'Đã tắt xác thực vân tay',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      await _authService.signOut();
    }
  }

  void _showTestNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Thông báo'),
        content: const Text('Chọn loại thông báo để test:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.showNotification(
                title: '🚨 Phát hiện email phishing!',
                body: 'Email từ unknown@suspicious.com có dấu hiệu lừa đảo',
                type: 'phishing',
              );
              _loadNotificationCount();
            },
            child: const Text('Phishing'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.showNotification(
                title: '✅ Email an toàn',
                body: 'Email từ support@google.com đã được kiểm tra và an toàn',
                type: 'safe',
              );
              _loadNotificationCount();
            },
            child: const Text('An toàn'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.showNotification(
                title: '📧 Hoàn thành kiểm tra',
                body: 'Đã kiểm tra 5 email mới, phát hiện 1 email nguy hiểm',
                type: 'scan_complete',
              );
              _loadNotificationCount();
            },
            child: const Text('Hoàn thành'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.showNotification(
                title: '🔐 Cảnh báo bảo mật',
                body: 'Phát hiện hoạt động đăng nhập bất thường từ thiết bị mới',
                type: 'security',
              );
              _loadNotificationCount();
            },
            child: const Text('Bảo mật'),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Cài đặt',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_biometricAvailable) ...[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.fingerprint,
                        color:
                            _biometricEnabled ? Colors.deepPurple : Colors.grey,
                        size: 28,
                      ),
                      title: const Text(
                        'Xác thực vân tay',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _biometricEnabled
                            ? 'Bật bảo mật vân tay'
                            : 'Tắt bảo mật vân tay',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      value: _biometricEnabled,
                      onChanged: (value) {
                        _toggleBiometric(value);
                        Navigator.pop(context);
                      },
                      activeColor: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.auto_awesome,
                      color:
                          _autoAnalysisEnabled ? Colors.green[700] : Colors.grey,
                      size: 28,
                    ),
                    title: const Text(
                      'Tự động phân tích email mới',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _autoAnalysisEnabled
                          ? 'Email mới sẽ được AI phân tích ngầm và lưu thống kê'
                          : 'Chỉ nhận thông báo email mới, không phân tích tự động',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    value: _autoAnalysisEnabled,
                    onChanged: (value) {
                      _toggleAutoAnalysis(value);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                // Check Email Ngay button - WITH AI ANALYSIS
                ListTile(
                  leading: Icon(
                    Icons.refresh,
                    color: Colors.green[700],
                  ),
                  title: const Text(
                    'Check Email Ngay',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Tìm email mới và phân tích bằng AI',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _checkEmailsNow();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.green[100]!),
                  ),
                ),
                const SizedBox(height: 12),
                // Test notification button
                ListTile(
                  leading: Icon(
                    Icons.notifications_active,
                    color: Colors.blue[700],
                  ),
                  title: const Text(
                    'Test thông báo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Gửi thông báo thử nghiệm',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _emailMonitorService.testNotification();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã gửi thông báo test!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue[100]!),
                  ),
                ),
                const SizedBox(height: 12),
                // Logout button
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Đăng xuất',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleSignOut();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red[100]!),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Container(
            //   padding: const EdgeInsets.all(6),
            //   decoration: BoxDecoration(
            //     gradient: const LinearGradient(
            //       colors: [Color(0xFF4285F4), Color(0xFF34A853)],
            //     ),
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: const Icon(Icons.shield, color: Colors.white, size: 18),
            // ),
            // const SizedBox(width: 10),
            // const Flexible(
            //   child: Text(
            //     'Phát hiện Phishing',
            //     style: TextStyle(
            //       color: Color(0xFF202124),
            //       fontWeight: FontWeight.w600,
            //       fontSize: 18,
            //     ),
            //     overflow: TextOverflow.ellipsis,
            //   ),
            // ),
          ],
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                  _loadNotificationCount();
                },
                tooltip: 'Thông báo',
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 9
                          ? '9+'
                          : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showSettingsBottomSheet,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4285F4),
                backgroundImage: _userData?['photoUrl'] != null
                    ? NetworkImage(_userData!['photoUrl'])
                    : null,
                child: _userData?['photoUrl'] == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4285F4), // Google Blue
                    Color(0xFF34A853), // Google Green
                  ],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _userData?['photoUrl'] != null
                    ? NetworkImage(_userData!['photoUrl'])
                    : null,
                child: _userData?['photoUrl'] == null
                    ? const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF4285F4),
                      )
                    : null,
              ),
              accountName: Text(
                _userData?['displayName'] ?? 'Người dùng',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _userData?['email'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Phân tích Email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Color(0xFF4285F4)),
                    title: const Text(
                      'Kiểm tra Phishing',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    selected: true,
                    selectedTileColor: Color(0xFFE8F0FE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart, color: Color(0xFF34A853)),
                    title: const Text('Thống kê'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: Color(0xFFFBBC04)),
                    title: const Text('Báo cáo chi tiết'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ReportsScreen()),
                      );
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Cài đặt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: Color(0xFF34A853)),
                    title: const Text('Bảo mật'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsBottomSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.grey),
                    title: const Text('Giới thiệu'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Colors.grey),
                    title: const Text('Trợ giúp'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report, color: Colors.orange),
                    title: const Text('Test Thông báo'),
                    onTap: () {
                      Navigator.pop(context);
                      _showTestNotificationDialog();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: const EmailListScreen(),
      floatingActionButton: null,
    );
  }


}