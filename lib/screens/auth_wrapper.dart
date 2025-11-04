import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'google_login_screen.dart';
import 'home_screen.dart';
import 'email_verification_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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

        if (snapshot.hasData) {
          final user = snapshot.data!;
          
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
