import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/guardmail_logo.dart';
import '../localization/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (mounted) {
        setState(() {
          _errorMessage = l.t('login_cancelled');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = l
              .t('login_error_with_message')
              .replaceFirst('{message}', error.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;

    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                if (!_isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.t('settings_language_title'),
                            icon: const Icon(Icons.language),
                            onPressed: () {
                              final currentCode =
                                  Localizations.localeOf(context).languageCode;
                              final nextLocale = currentCode == 'vi'
                                  ? const Locale('en')
                                  : const Locale('vi');
                              LocaleService().setLocale(nextLocale);
                            },
                          ),
                          IconButton(
                            tooltip: isDark
                                ? l.t('theme_toggle_to_light')
                                : l.t('theme_toggle_to_dark'),
                            icon: Icon(
                              isDark ? Icons.light_mode : Icons.dark_mode,
                            ),
                            onPressed: () async {
                              // Toggle trực tiếp giữa sáng/tối
                              await ThemeService().toggleDark(!isDark);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                const GuardMailLogo(
                  size: 80,
                  showTitle: true,
                  titleFontSize: 26,
                  spacing: 14,
                ),
                const SizedBox(height: 8),
                Text(
                  l.t('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.red.withOpacity(0.15)
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.red[700]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.red[200]
                                  : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF4285F4))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Nút đăng nhập Google (ưu tiên)
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? theme.dividerColor
                                    : const Color(0xFFDADCE0),
                                width: 1,
                              ),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _handleGoogleSignIn,
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                height: 22,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.g_mobiledata_rounded,
                                      size: 24, color: Color(0xFF4285F4));
                                },
                              ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${l.t('login_with')} ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF3C4043),
                                    ),
                                  ),
                                  Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                  Text(
                                    'o',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEA4335),
                                    ),
                                  ),
                                  Text(
                                    'o',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFBBC05),
                                    ),
                                  ),
                                  Text(
                                    'g',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                  Text(
                                    'l',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF34A853),
                                    ),
                                  ),
                                  Text(
                                    'e',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEA4335),
                                    ),
                                  ),
                                ],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: surfaceColor,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  l.t('login_or'),
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Nút đăng nhập bằng Email (phụ)
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4285F4).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/email-login');
                              },
                              icon: const Icon(Icons.email_outlined, color: Colors.white),
                              label: Text(
                                l.t('login_email'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l.t('login_no_account'),
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/email-register');
                                },
                                child: Text(
                                  l.t('login_register_email'),
                                  style: const TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}