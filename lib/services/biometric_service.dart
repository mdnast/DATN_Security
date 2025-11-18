import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _legacyBiometricEnabledKey = 'biometric_enabled';
  static const String _biometricEnabledKeyPrefix = 'biometric_enabled_';
  DateTime? _lastAuthTime;
  static const int _sessionTimeoutSeconds = 30;

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<BiometricAuthResult> authenticate({bool skipSessionCheck = false}) async {
    try {
      // Check if recently authenticated
      if (!skipSessionCheck && _lastAuthTime != null) {
        final timeSinceAuth = DateTime.now().difference(_lastAuthTime!);
        if (timeSinceAuth.inSeconds < _sessionTimeoutSeconds) {
          return BiometricAuthResult(success: true);
        }
      }

      final availableBiometrics = await getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'Vui lòng thiết lập vân tay hoặc PIN trong Cài đặt của điện thoại',
        );
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Vui lòng xác thực để tiếp tục',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      
      if (didAuthenticate) {
        _lastAuthTime = DateTime.now();
      }
      
      return BiometricAuthResult(
        success: didAuthenticate,
        errorMessage: didAuthenticate ? null : 'Xác thực thất bại',
      );
    } on PlatformException catch (e) {
      String errorMessage = 'Có lỗi xảy ra';
      
      if (e.code == auth_error.notAvailable) {
        errorMessage = 'Thiết bị không hỗ trợ xác thực sinh trắc học';
      } else if (e.code == auth_error.notEnrolled) {
        errorMessage = 'Chưa thiết lập vân tay hoặc PIN. Vui lòng thiết lập trong Cài đặt';
      } else if (e.code == auth_error.lockedOut || e.code == auth_error.permanentlyLockedOut) {
        errorMessage = 'Quá nhiều lần thử thất bại. Vui lòng thử lại sau';
      } else {
        errorMessage = e.message ?? 'Xác thực thất bại';
      }
      
      return BiometricAuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Lỗi: ${e.toString()}',
      );
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey(prefs);
    return prefs.getBool(storageKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey(prefs);
    await prefs.setBool(storageKey, enabled);
  }

  Future<bool> toggleBiometric() async {
    final currentState = await isBiometricEnabled();
    await setBiometricEnabled(!currentState);
    return !currentState;
  }

  void clearSession() {
    _lastAuthTime = null;
  }

  bool isSessionActive() {
    if (_lastAuthTime == null) return false;
    final timeSinceAuth = DateTime.now().difference(_lastAuthTime!);
    return timeSinceAuth.inSeconds < _sessionTimeoutSeconds;
  }

  Future<String> _getStorageKey(SharedPreferences prefs) async {
    final userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      try {
        final Map<String, dynamic> userData = jsonDecode(userDataString);
        final String uid = (userData['uid'] ?? userData['email'] ?? 'guest').toString();
        final key = '$_biometricEnabledKeyPrefix$uid';

        if (!prefs.containsKey(key) && prefs.containsKey(_legacyBiometricEnabledKey)) {
          final legacy = prefs.getBool(_legacyBiometricEnabledKey);
          if (legacy != null) {
            await prefs.setBool(key, legacy);
          }
          await prefs.remove(_legacyBiometricEnabledKey);
        }

        return key;
      } catch (_) {
        // Fallback to legacy key if parsing fails
      }
    }

    return _legacyBiometricEnabledKey;
  }
}

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });
}
