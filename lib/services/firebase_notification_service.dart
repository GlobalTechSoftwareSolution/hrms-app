import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

// Top-level function for background message handling
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  await FirebaseNotificationService._handleBackgroundMessage(message);
}

class FirebaseNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static const String _notificationsKey = 'stored_notifications';
  static const String _fcmTokenKey = 'fcm_token';
  
  // Notification channels
  static const AndroidNotificationChannel _ticketChannel = AndroidNotificationChannel(
    'ticket_notifications',
    'Ticket Notifications',
    description: 'Notifications for ticket updates',
    importance: Importance.high,
  );
  
  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'general_notifications',
    'General Notifications',
    description: 'General HRMS notifications',
    importance: Importance.defaultImportance,
  );

  // Initialize Firebase Messaging
  static Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get and store FCM token
    await _updateFCMToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_ticketChannel);
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_generalChannel);
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    final notification = NotificationModel.fromFirebaseMessage(message);
    await _storeNotification(notification);
    await _showLocalNotification(notification);
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');
    
    final notification = NotificationModel.fromFirebaseMessage(message);
    await _storeNotification(notification);
  }

  // Handle notification tap
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.messageId}');
    
    final notification = NotificationModel.fromFirebaseMessage(message);
    await _markNotificationAsRead(notification.id);
    
    // Handle navigation based on notification type
    await _handleNotificationNavigation(notification);
  }

  // Handle local notification tap
  static Future<void> _onLocalNotificationTap(NotificationResponse response) async {
    print('Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      final notificationData = jsonDecode(response.payload!);
      final notification = NotificationModel.fromJson(notificationData);
      await _markNotificationAsRead(notification.id);
      await _handleNotificationNavigation(notification);
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(NotificationModel notification) async {
    final channel = notification.type == NotificationType.ticketAssigned ||
                   notification.type == NotificationType.ticketUpdated ||
                   notification.type == NotificationType.ticketClosed
        ? _ticketChannel
        : _generalChannel;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      showWhen: true,
      when: notification.timestamp.millisecondsSinceEpoch,
      styleInformation: BigTextStyleInformation(
        notification.body,
        contentTitle: notification.title,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(notification.toJson()),
    );
  }

  // Store notification locally
  static Future<void> _storeNotification(NotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getStoredNotifications();
    
    // Add new notification to the beginning of the list
    notifications.insert(0, notification);
    
    // Keep only the last 100 notifications
    if (notifications.length > 100) {
      notifications.removeRange(100, notifications.length);
    }
    
    final notificationsJson = notifications.map((n) => n.toJson()).toList();
    await prefs.setString(_notificationsKey, jsonEncode(notificationsJson));
  }

  // Get stored notifications
  static Future<List<NotificationModel>> getStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsString = prefs.getString(_notificationsKey);
    
    if (notificationsString == null) return [];
    
    final List<dynamic> notificationsJson = jsonDecode(notificationsString);
    return notificationsJson
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  // Mark notification as read
  static Future<void> _markNotificationAsRead(String notificationId) async {
    final notifications = await getStoredNotifications();
    final index = notifications.indexWhere((n) => n.id == notificationId);
    
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, jsonEncode(notificationsJson));
    }
  }

  // Mark all notifications as read
  static Future<void> markAllNotificationsAsRead() async {
    final notifications = await getStoredNotifications();
    final updatedNotifications = notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = updatedNotifications.map((n) => n.toJson()).toList();
    await prefs.setString(_notificationsKey, jsonEncode(notificationsJson));
  }

  // Get unread notification count
  static Future<int> getUnreadNotificationCount() async {
    final notifications = await getStoredNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // Handle notification navigation
  static Future<void> _handleNotificationNavigation(NotificationModel notification) async {
    // This will be implemented based on your app's navigation structure
    // For now, we'll just print the action
    print('Navigate to: ${notification.type.displayName}');
    
    if (notification.ticketId != null) {
      print('Open ticket: ${notification.ticketId}');
    }
    
    if (notification.actionUrl != null) {
      print('Open URL: ${notification.actionUrl}');
    }
  }

  // Get FCM token
  static Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Update FCM token
  static Future<void> _updateFCMToken() async {
    final token = await getFCMToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      
      // Send token to your backend server
      await _sendTokenToServer(token);
    }
  }

  // Handle token refresh
  static Future<void> _onTokenRefresh(String token) async {
    print('FCM Token refreshed: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
    
    // Send updated token to your backend server
    await _sendTokenToServer(token);
  }

  // Send token to server
  static Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: Implement API call to send token to your Django backend
      // This should include the user's email/ID and the FCM token
      print('Sending FCM token to server: $token');
      
      // Example implementation:
      // final response = await http.post(
      //   Uri.parse('${ApiConfig.apiUrl}/notifications/register-token/'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'token': token,
      //     'user_email': await _getUserEmail(),
      //     'platform': Platform.isAndroid ? 'android' : 'ios',
      //   }),
      // );
    } catch (e) {
      print('Error sending token to server: $e');
    }
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await _localNotifications.cancelAll();
  }

  // Get user email for token registration
  static Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return userInfo['email']?.toString().toLowerCase();
    }
    return null;
  }
}
