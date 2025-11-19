import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/email_monitor_service.dart';
import '../services/background_email_service.dart';
import '../services/auto_analysis_settings_service.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/guardmail_logo.dart';
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
  final AutoAnalysisSettingsService _autoAnalysisSettings = AutoAnalysisSettingsService();
  final GlobalKey _emailListKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
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
  }

  @override
  void dispose() {
    print('🔴 HomeScreen disposing...');
    _isDisposed = true; // ✅ Mark as disposed
    _searchController.dispose();
    
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
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l
                  .t('monitoring_start_error')
                  .replaceFirst('{error}', e.toString()),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // _checkEmailsNow và QuickEmailChecker đã được loại bỏ theo yêu cầu

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
                ? AppLocalizations.of(context)
                    .t('auto_analysis_enabled_snackbar')
                : AppLocalizations.of(context)
                    .t('auto_analysis_disabled_snackbar'),
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
              content: Text(
                result.errorMessage ??
                    AppLocalizations.of(context).t('biometric_auth_failed'),
              ),
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
                ? AppLocalizations.of(context)
                    .t('biometric_enabled_snackbar')
                : AppLocalizations.of(context)
                    .t('biometric_disabled_snackbar'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.t('logout_confirm_title')),
        content: Text(l.t('logout_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.t('common_logout')),
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
  }

  void _showSettingsBottomSheet() {
    final l = AppLocalizations.of(context);

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, size: 26, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        l.t('settings_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.t('settings_description'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                // Auto analysis first
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.auto_awesome,
                      color:
                          _autoAnalysisEnabled ? Colors.green[700] : Colors.grey,
                      size: 28,
                    ),
                    title: Text(
                      l.t('settings_auto_analysis_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _autoAnalysisEnabled
                          ? l.t('settings_auto_analysis_on')
                          : l.t('settings_auto_analysis_off'),
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
                // Then biometric
                if (_biometricAvailable) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.fingerprint,
                        color:
                            _biometricEnabled ? Colors.deepPurple : Colors.grey,
                        size: 28,
                      ),
                      title: Text(
                        l.t('settings_biometric_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _biometricEnabled
                            ? l.t('settings_biometric_on')
                            : l.t('settings_biometric_off'),
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.brightness_6_rounded,
                            color: Color(0xFF5F6368)),
                        title: Text(
                          l.t('settings_theme_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          l.t('settings_theme_subtitle'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Divider(height: 1),
                      _ThemeModeTile(mode: ThemeMode.system, labelKey: 'settings_theme_system'),
                      _ThemeModeTile(mode: ThemeMode.light, labelKey: 'settings_theme_light'),
                      _ThemeModeTile(mode: ThemeMode.dark, labelKey: 'settings_theme_dark'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Language selection
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language, color: Color(0xFF5F6368)),
                        title: Text(
                          l.t('settings_language_title'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1),
                      _LanguageTile(
                        locale: const Locale('vi'),
                        labelKey: 'settings_language_vi',
                      ),
                      _LanguageTile(
                        locale: const Locale('en'),
                        labelKey: 'settings_language_en',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Logout button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red[100]!),
                    color: Colors.red.withValues(alpha: 0.03),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      l.t('settings_logout'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _handleSignOut();
                    },
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
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.t('home_search_hint'),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5F6368)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                final dynamic state = _emailListKey.currentState;
                state?.updateSearchQuery(value);
              },
            ),
          ),
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
                tooltip: l.t('home_notifications_tooltip'),
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
                    Color(0xFF4285F4),
                    Color(0xFF34A853),
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
                _userData?['displayName'] ??
                    AppLocalizations.of(context)
                        .t('user_default_display_name'),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      l.t('drawer_section_analysis'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(
                      l.t('drawer_check_phishing'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    selected: true,
                    selectedTileColor: Color(0xFFE8F0FE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: Text(l.t('drawer_statistics')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l.t('drawer_reports')),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Text(
                      l.t('drawer_settings_section'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: Text(
                      l.t('drawer_security'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsBottomSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      l.t('drawer_about'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showIntroSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(
                      l.t('drawer_help'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpSheet();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(
                l.t('common_logout'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
      body: EmailListScreen(key: _emailListKey),
    );
  }


  void _showIntroSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                    const GuardMailLogo(
                  size: 80,
                  titleFontSize: 24,
                  spacing: 12,
                ),
                const SizedBox(height: 16),
                Text(
                  l.t('intro_description'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('intro_what_can_do_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _IntroBullet(
                        icon: Icons.shield_outlined,
                        title: 'intro_feature_scan_title',
                        description: 'intro_feature_scan_desc',
                      ),
                      const SizedBox(height: 10),
                      _IntroBullet(
                        icon: Icons.notifications_active_outlined,
                        title: 'intro_feature_notify_title',
                        description: 'intro_feature_notify_desc',
                      ),
                      const SizedBox(height: 10),
                      _IntroBullet(
                        icon: Icons.bar_chart_outlined,
                        title: 'intro_feature_stats_title',
                        description: 'intro_feature_stats_desc',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l.t('intro_tip_auto_analysis'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('help_quick_title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _HelpSection(
                  title: l.t('help_section1_title'),
                  content: l.t('help_section1_content'),
                ),
                const SizedBox(height: 16),
                _HelpSection(
                  title: l.t('help_section2_title'),
                  content: l.t('help_section2_content'),
                ),
                const SizedBox(height: 16),
                _HelpSection(
                  title: l.t('help_section3_title'),
                  content: l.t('help_section3_content'),
                ),
                const SizedBox(height: 16),
                _HelpSection(
                  title: l.t('help_section4_title'),
                  content: l.t('help_section4_content'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _IntroBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF4285F4)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t(title),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t(description),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String content;

  const _HelpSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

}

class _ThemeModeTile extends StatelessWidget {
  final ThemeMode mode;
  final String labelKey;

  const _ThemeModeTile({required this.mode, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = ThemeService().themeMode.value;

    IconData icon;
    switch (mode) {
      case ThemeMode.light:
        icon = Icons.light_mode;
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        break;
      case ThemeMode.system:
      default:
        icon = Icons.settings_suggest;
        break;
    }

    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: current,
      onChanged: (value) async {
        if (value == null) return;
        await ThemeService().setThemeMode(value);
      },
      dense: true,
      title: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5F6368)),
          const SizedBox(width: 8),
          Text(
            l.t(labelKey),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Locale locale;
  final String labelKey;

  const _LanguageTile({
    required this.locale,
    required this.labelKey,
  });

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    final l = AppLocalizations.of(context);

    return RadioListTile<String>(
      value: locale.languageCode,
      groupValue: current,
      onChanged: (value) async {
        if (value == null) return;
        await LocaleService().setLocale(Locale(value));
      },
      dense: true,
      title: Text(l.t(labelKey)),
    );
  }
}