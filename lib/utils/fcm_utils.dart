import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';

class FCMUtils {
  /// Register FCM token with backend after successful login
  static Future<void> registerFCMTokenAfterLogin() async {
    try {
      // Get the user's email from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userInfoStr = prefs.getString('user_info');

      if (userInfoStr != null && userInfoStr.isNotEmpty) {
        final userInfo = jsonDecode(userInfoStr) as Map<String, dynamic>;
        final email = userInfo['email'] as String?;

        if (email != null && email.isNotEmpty) {
          // Get FCM token
          final fcmToken = await FCMService().getFCMToken();

          if (fcmToken != null) {
            // Register token with backend
            await FCMService().registerTokenWithBackend(email, fcmToken);
          }
        }
      }
    } catch (e) {
      print('Error registering FCM token after login: $e');
    }
  }

  /// Unregister FCM token with backend during logout
  static Future<void> unregisterFCMTokenAtLogout() async {
    try {
      // Get the user's email from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userInfoStr = prefs.getString('user_info');

      if (userInfoStr != null && userInfoStr.isNotEmpty) {
        final userInfo = jsonDecode(userInfoStr) as Map<String, dynamic>;
        final email = userInfo['email'] as String?;

        if (email != null && email.isNotEmpty) {
          // Get FCM token
          final fcmToken = await FCMService().getFCMToken();

          if (fcmToken != null) {
            // Unregister token with backend
            await FCMService().unregisterTokenWithBackend(email, fcmToken);
          }
        }
      }
    } catch (e) {
      print('Error unregistering FCM token at logout: $e');
    }
  }
}
