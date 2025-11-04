import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'google_login_screen.dart';
import 'home_screen.dart';
import 'email_verification_screen.dart';
import 'biometric_lock_screen.dart';
import '../services/biometric_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService();
  bool _shouldShowBiometric = false;
  bool _isCheckingBiometric = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !_biometricService.isSessionActive()) {
        _checkBiometricRequirement(user);
      }
    } else if (state == AppLifecycleState.paused) {
      _biometricService.clearSession();
      if (mounted) {
        setState(() {
          _shouldShowBiometric = false;
        });
      }
    }
  }

  Future<void> _checkBiometricRequirement(User? user) async {
    if (user != null) {
      final biometricEnabled = await _biometricService.isBiometricEnabled();
      final sessionActive = _biometricService.isSessionActive();
      
      if (mounted) {
        setState(() {
          _shouldShowBiometric = biometricEnabled && !sessionActive;
          _isCheckingBiometric = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _shouldShowBiometric = false;
          _isCheckingBiometric = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.deepPurple,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Schedule biometric check AFTER build completes
        if (snapshot.connectionState == ConnectionState.active && _isCheckingBiometric) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkBiometricRequirement(snapshot.data);
          });
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          if (_shouldShowBiometric) {
            return const BiometricLockScreen();
          }
          
          if (user.emailVerified || user.providerData.any((info) => info.providerId == 'google.com')) {
            return const HomeScreen();
          } else {
            return const EmailVerificationScreen();
          }
        }

        return const GoogleLoginScreen();
      },
    );
  }
}
