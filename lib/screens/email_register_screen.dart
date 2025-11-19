import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/recaptcha_service.dart';
import '../widgets/guardmail_logo.dart';
import '../localization/app_localizations.dart';

class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _recaptchaToken;
  String? _errorMessage;
  double _passwordStrength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String value) {
    if (value.isEmpty) {
      _passwordStrength = 0;
      return;
    }

    int strength = 0;
    if (value.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(value)) strength++;
    if (RegExp(r'[a-z]').hasMatch(value)) strength++;
    if (RegExp(r'[0-9]').hasMatch(value)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) strength++;

    _passwordStrength = (strength / 5).clamp(0, 1).toDouble();
  }

  Future<void> _handleRegister() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_recaptchaToken == null || _recaptchaToken!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.t('recaptcha_not_verified_snackbar')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (result != null && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/email-verification',
          arguments: _emailController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = l.t('error_generic');
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = l.t('error_email_already_in_use');
          break;
        case 'invalid-email':
          errorMsg = l.t('error_invalid_email');
          break;
        case 'weak-password':
          errorMsg = l.t('error_weak_password');
          break;
        default:
          errorMsg = l
              .t('error_with_message')
              .replaceFirst('{message}', e.message ?? '');
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = l
              .t('error_with_message')
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
    final l = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFillColor = isDark
        ? theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface
        : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.appBarTheme.iconTheme?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(
                    child: GuardMailLogo(
                      size: 72,
                      showTitle: true,
                      titleFontSize: 22,
                      spacing: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('register_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color
                          ?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
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
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l.t('name_field'),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: theme.iconTheme.color?.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l.t('validation_enter_name');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.t('email_field'),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: theme.iconTheme.color?.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l.t('validation_enter_email');
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return l.t('validation_email_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l.t('password_field'),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: theme.iconTheme.color?.withOpacity(0.8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: theme.iconTheme.color?.withOpacity(0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _updatePasswordStrength(value);
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l.t('validation_enter_password');
                      }
                      if (value.length < 8) {
                        return l.t('validation_password_min_length');
                      }
                      final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
                      final hasLower = RegExp(r'[a-z]').hasMatch(value);
                      final hasDigit = RegExp(r'[0-9]').hasMatch(value);
                      final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value);

                      if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
                        return l.t('validation_password_requirements');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      // Chỉ hiển thị thanh độ mạnh khi người dùng đã nhập mật khẩu
                      if (_passwordController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      Color color;
                      String label;

                      if (_passwordStrength < 0.4) {
                        color = Colors.red;
                        label = l.t('password_strength_weak');
                      } else if (_passwordStrength < 0.8) {
                        color = Colors.orange;
                        label = l.t('password_strength_medium');
                      } else {
                        color = Colors.green;
                        label = l.t('password_strength_strong');
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _passwordStrength == 0 ? 0.05 : _passwordStrength,
                              minHeight: 6,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(fontSize: 12, color: color),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: l.t('confirm_password_field'),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: theme.iconTheme.color?.withOpacity(0.8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: theme.iconTheme.color?.withOpacity(0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l.t('validation_enter_password_confirm');
                      }
                      if (value != _passwordController.text) {
                        return l.t('validation_password_mismatch');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  RecaptchaWidget(
                    onVerified: (token) {
                      setState(() {
                        _recaptchaToken = token;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
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
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l.t('register_button'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l.t('has_account'),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/email-login');
                        },
                        child: Text(
                          l.t('login_here'),
                          style: const TextStyle(
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
