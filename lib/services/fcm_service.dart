import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';

/// Helper method to determine notification type from data
NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
  final String? notificationType = data['notification_type'];
  switch (notificationType) {
    case 'ticketAssigned':
      return NotificationType.ticketAssigned;
    case 'ticketUpdated':
      return NotificationType.ticketUpdated;
    case 'ticketClosed':
      return NotificationType.ticketClosed;
    case 'leaveApproved':
      return NotificationType.leaveApproved;
    case 'leaveRejected':
      return NotificationType.leaveRejected;
    case 'attendanceReminder':
      return NotificationType.attendanceReminder;
    case 'announcement':
      return NotificationType.announcement;
    default:
      return NotificationType.general;
  }
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print("Message data: ${message.data}");
  }

  // Handle background notification
  // Note: This runs in a separate isolate, so limited operations are available
  // Save the notification to shared preferences for display when app opens
  try {
    // Create a notification model
    final notificationModel = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? 'You have a new notification',
      timestamp: DateTime.now(),
      isRead: false,
      type: _getNotificationTypeFromData(message.data),
      data: message.data,
    );

    // Save to shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('background_notifications') ?? [];

      // Add new notification to the list
      notificationsJson.add(jsonEncode(notificationModel.toJson()));

      // Keep only the last 50 notifications to prevent storage bloat
      if (notificationsJson.length > 50) {
        notificationsJson.removeRange(0, notificationsJson.length - 50);
      }

      await prefs.setStringList('background_notifications', notificationsJson);

      if (kDebugMode) {
        print("Background notification saved to shared preferences");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error saving background notification: $e");
      }
    }

    if (kDebugMode) {
      print("Background notification processed: ${notificationModel.title}");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error handling background message: $e");
    }
  }
}

// Add local notifications plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  late FirebaseMessaging _firebaseMessaging;
  StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;

  // Add a stream controller for notifications to be added to the provider
  static final StreamController<NotificationModel>
  _notificationStreamController =
      StreamController<NotificationModel>.broadcast();
  static Stream<NotificationModel> get notificationStream =>
      _notificationStreamController.stream;

  bool _initialized = false;

  /// Initialize FCM
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            announcement: false,
          );

      if (kDebugMode) {
        print(
          'Notification permissions status: ${settings.authorizationStatus}',
        );
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }

        if (message.notification != null) {
          if (kDebugMode) {
            print(
              'Message also contained a notification: ${message.notification}',
            );
          }
        }

        // Show local notification
        _showLocalNotification(message);

        // Add to stream for UI to handle
        _messageStreamController.add(message);

        // Show in-app notification or update UI
        _handleForegroundNotification(message);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle when app is opened from terminated state via notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened via notification: ${message.data}');
        }
        _handleNotificationTap(message);
      });

      // Get initial message (when app is opened from terminated state)
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        // TODO: Re-register with backend when token is refreshed
        // This would typically be done after user login
      });

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing FCM: $e');
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // MUST MATCH THE CHANNEL ID ABOVE
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing local notification: $e');
      }
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Register device token with HRMS backend
  Future<bool> registerTokenWithBackend(String email, String fcmToken) async {
    try {
      // Debug: Print what we're sending
      final requestData = <String, dynamic>{
        'email': email,
        'token':
            fcmToken, // Changed from 'fcm_token' to 'token' to match backend
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'device_name': 'Flutter App', // Optional
      };

      if (kDebugMode) {
        print('Sending FCM registration data to backend:');
        print('URL: ${ApiService.baseUrl}/accounts/fcm/register/');
        print('Data: $requestData');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/accounts/fcm/register/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestData),
      );

      if (kDebugMode) {
        print('FCM registration response status: ${response.statusCode}');
        print('FCM registration response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Device token registered successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to register device token: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering device token: $e');
      }
      return false;
    }
  }

  /// Unregister device token with HRMS backend
  Future<bool> unregisterTokenWithBackend(String email, String fcmToken) async {
    try {
      final requestData = <String, dynamic>{
        'email': email,
        'token':
            fcmToken, // Changed from 'fcm_token' to 'token' to match backend
      };

      if (kDebugMode) {
        print('Sending FCM unregistration data to backend:');
        print('URL: ${ApiService.baseUrl}/accounts/fcm/unregister/');
        print('Data: $requestData');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/accounts/fcm/unregister/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestData),
      );

      if (kDebugMode) {
        print('FCM unregistration response status: ${response.statusCode}');
        print('FCM unregistration response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Device token unregistered successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to unregister device token: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering device token: $e');
      }
      return false;
    }
  }

  /// Handle foreground notification
  void _handleForegroundNotification(RemoteMessage message) {
    // Extract notification data
    final String? title = message.notification?.title;
    final String? body = message.notification?.body;
    final Map<String, dynamic> data = message.data;

    // Show in-app notification or update UI
    // You can use packages like flutter_local_notifications for this
    if (kDebugMode) {
      print('Showing foreground notification: $title - $body');
      print('Notification data: $data');
    }

    // Create a notification model and add it directly to the provider
    if (title != null && body != null) {
      final notification = NotificationModel(
        id:
            message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        isRead: false,
        type: _getNotificationTypeFromData(data),
        data: data,
      );

      if (kDebugMode) {
        print('FCM SERVICE: Creating notification: ${notification.title}');
      }

      // Add notification directly to the provider using global accessor
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final provider = NotificationProvider.instance;
          if (provider != null) {
            if (kDebugMode) {
              print(
                'FCM SERVICE: Adding notification to provider: ${notification.title}',
              );
              print(
                'FCM SERVICE: Provider before add has ${provider.notifications.length} notifications',
              );
            }

            provider.addNotification(notification);

            if (kDebugMode) {
              print(
                'FCM SERVICE: Notification added successfully. Total notifications: ${provider.notifications.length}',
              );
            }
          } else {
            if (kDebugMode) {
              print(
                'FCM SERVICE: ERROR - Notification provider instance is null!',
              );
              print(
                'FCM SERVICE: This means the provider has not been initialized yet.',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('FCM SERVICE: ERROR adding notification to provider: $e');
          }
        }
      });

      // Also emit to stream for any other listeners
      if (kDebugMode) {
        print(
          'FCM SERVICE: Emitting notification to stream: ${notification.title}',
        );
      }
      _notificationStreamController.add(notification);
    } else {
      if (kDebugMode) {
        print('FCM SERVICE: Skipping notification - title or body is null');
      }
    }

    // Example: Navigate based on notification type
    final String? notificationType = data['notification_type'];
    switch (notificationType) {
      case 'leave':
        // Navigate to leave screen
        if (kDebugMode) {
          print('Navigate to leave screen');
        }
        break;
      case 'payroll':
        // Navigate to payroll screen
        if (kDebugMode) {
          print('Navigate to payroll screen');
        }
        break;
      case 'task':
        // Navigate to task screen
        if (kDebugMode) {
          print('Navigate to task screen');
        }
        break;
      case 'attendance':
        // Navigate to attendance screen
        if (kDebugMode) {
          print('Navigate to attendance screen');
        }
        break;
      default:
        // Handle general notification
        if (kDebugMode) {
          print('Handle general notification');
        }
    }
  }

  /// Helper method to determine notification type from data
  NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final String? notificationType = data['notification_type'];
    switch (notificationType) {
      case 'ticketAssigned':
        return NotificationType.ticketAssigned;
      case 'ticketUpdated':
        return NotificationType.ticketUpdated;
      case 'ticketClosed':
        return NotificationType.ticketClosed;
      case 'leaveApproved':
        return NotificationType.leaveApproved;
      case 'leaveRejected':
        return NotificationType.leaveRejected;
      case 'attendanceReminder':
        return NotificationType.attendanceReminder;
      case 'announcement':
        return NotificationType.announcement;
      default:
        return NotificationType.general;
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String? notificationType = data['notification_type'];
    final String? itemId = data['item_id']; // ID of the item to navigate to

    if (kDebugMode) {
      print('Handling notification tap for type: $notificationType');
    }

    // Handle navigation based on notification type
    switch (notificationType) {
      case 'ticketAssigned':
      case 'ticketUpdated':
      case 'ticketClosed':
        // Navigate to tickets screen
        if (kDebugMode) {
          print('Navigate to tickets screen with ticket ID: $itemId');
        }
        // TODO: Implement actual navigation to tickets screen
        break;
      case 'leaveApproved':
      case 'leaveRejected':
        // Navigate to leaves screen
        if (kDebugMode) {
          print('Navigate to leaves screen with leave ID: $itemId');
        }
        // TODO: Implement actual navigation to leaves screen
        break;
      case 'attendanceReminder':
        // Navigate to attendance screen
        if (kDebugMode) {
          print('Navigate to attendance screen');
        }
        // TODO: Implement actual navigation to attendance screen
        break;
      case 'announcement':
        // Navigate to announcements screen
        if (kDebugMode) {
          print(
            'Navigate to announcements screen with announcement ID: $itemId',
          );
        }
        // TODO: Implement actual navigation to announcements screen
        break;
      default:
        // Handle general notification
        if (kDebugMode) {
          print('Handle general notification tap');
        }
    }
  }

  /// Send notification to a specific user
  Future<bool> sendNotificationToUser({
    required String email,
    required String title,
    required String message,
    String? notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/accounts/fcm/send_to_user/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'title': title,
          'message': message,
          'notification_type': notificationType,
          'data': data ?? {},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification to user: $e');
      }
      return false;
    }
  }

  /// Send notification to multiple users
  Future<bool> sendNotificationToUsers({
    required List<String> emails,
    required String title,
    required String message,
    String? notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/accounts/fcm/send_to_users/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'emails': emails,
          'title': title,
          'message': message,
          'notification_type': notificationType,
          'data': data ?? {},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification to users: $e');
      }
      return false;
    }
  }

  /// Send broadcast notification to all users
  Future<bool> sendBroadcastNotification({
    required String title,
    required String message,
    String? notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/accounts/fcm/send_broadcast/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'title': title,
          'message': message,
          'notification_type': notificationType,
          'data': data ?? {},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending broadcast notification: $e');
      }
      return false;
    }
  }

  /// Retrieve background notifications saved in shared preferences
  Future<List<NotificationModel>> getBackgroundNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('background_notifications') ?? [];

      final notifications = <NotificationModel>[];
      for (final jsonStr in notificationsJson) {
        try {
          final json = jsonDecode(jsonStr);
          notifications.add(NotificationModel.fromJson(json));
        } catch (e) {
          if (kDebugMode) {
            print("Error decoding background notification: $e");
          }
        }
      }

      // Clear the saved notifications since we've retrieved them
      await prefs.remove('background_notifications');

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print("Error retrieving background notifications: $e");
      }
      return [];
    }
  }

  /// Dispose of resources
  void dispose() {
    _messageStreamController.close();
  }
}
