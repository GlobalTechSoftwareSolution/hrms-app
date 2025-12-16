import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/hrms_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'models/notification_model.dart';

// Initialize local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FCM
  await FCMService().initialize();

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create notification channel (required for Android 8+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // ID
    'High Importance Notifications', // Name
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Global error handling
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => HRMSProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Smart HR - Human Resource Management',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    NotificationsScreen(),
    AttendanceScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    NavigationDestination(
      icon: Icon(Icons.access_time_outlined),
      selectedIcon: Icon(Icons.access_time),
      label: 'Attendance',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Request initial permissions
    _requestInitialPermissions();

    // Load background notifications when app starts
    _loadBackgroundNotifications();

    // Listen to FCM messages
    FCMService().messageStream.listen((message) {
      // Handle incoming messages
      setState(() {
        // Refresh notifications or update UI as needed
      });
    });

    // Listen to FCM notifications and add them to the provider
    FCMService.notificationStream.listen((notification) {
      if (kDebugMode) {
        print(
          'MAIN SCREEN: Received notification from stream: ${notification.title}',
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final notificationProvider = Provider.of<NotificationProvider>(
            context,
            listen: false,
          );

          if (kDebugMode) {
            print(
              'MAIN SCREEN: Adding notification to provider: ${notification.title}',
            );
            print(
              'MAIN SCREEN: Provider before add has ${notificationProvider.notifications.length} notifications',
            );
          }

          notificationProvider.addNotification(notification);

          if (kDebugMode) {
            print(
              'MAIN SCREEN: Notification added successfully. Total notifications: ${notificationProvider.notifications.length}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('MAIN SCREEN: Error adding notification to provider: $e');
          }
        }
      });
    });
  }

  /// Request initial permissions when app starts
  Future<void> _requestInitialPermissions() async {
    // Add a small delay to ensure context is available
    await Future.delayed(const Duration(milliseconds: 500));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Request camera permission
        final cameraStatus = await Permission.camera.request();
        if (kDebugMode) {
          print('Camera permission status: $cameraStatus');
        }

        // Request location permission
        final locationStatus = await Permission.location.request();
        if (kDebugMode) {
          print('Location permission status: $locationStatus');
        }

        // Show a welcome message if this is the first time
        final prefs = await SharedPreferences.getInstance();
        final hasShownWelcome =
            prefs.getBool('has_shown_welcome_message') ?? false;

        if (!hasShownWelcome && mounted) {
          await prefs.setBool('has_shown_welcome_message', true);

          // Show welcome dialog with permission information
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Welcome to HRMS'),
                content: const Text(
                  'This app requires camera and location permissions to function properly.\n\n'
                  '• Camera: For face recognition attendance\n'
                  '• Location: For attendance verification\n\n'
                  'You can change these permissions anytime in your device settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error requesting initial permissions: $e');
        }
      }
    });
  }

  /// Load background notifications when app starts
  Future<void> _loadBackgroundNotifications() async {
    try {
      // Add a small delay to ensure provider is initialized
      await Future.delayed(const Duration(milliseconds: 500));

      final backgroundNotifications = await FCMService()
          .getBackgroundNotifications();

      if (backgroundNotifications.isNotEmpty) {
        if (kDebugMode) {
          print(
            'MAIN SCREEN: Loading ${backgroundNotifications.length} background notifications',
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final notificationProvider = Provider.of<NotificationProvider>(
              context,
              listen: false,
            );

            // Add background notifications to provider (in reverse order to maintain chronological order)
            for (int i = backgroundNotifications.length - 1; i >= 0; i--) {
              notificationProvider.addNotification(backgroundNotifications[i]);
            }

            if (kDebugMode) {
              print(
                'MAIN SCREEN: Loaded background notifications. Total: ${notificationProvider.notifications.length}',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('MAIN SCREEN: Error loading background notifications: $e');
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('MAIN SCREEN: Error retrieving background notifications: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CircleAvatar(
                radius: 12,
                backgroundImage: const AssetImage('assets/images/logo.png'),
                backgroundColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HRMS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Human Resource Management',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      if (kDebugMode) {
                        print(
                          'NAVIGATION: Notification icon pressed, switching to index 1',
                        );
                      }
                      // Navigate to notifications screen
                      setState(() {
                        _selectedIndex = 1; // Notifications screen index
                      });
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
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
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _ErrorBoundary(child: _screens[_selectedIndex]),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final unreadCount = notificationProvider.unreadCount;

          // Create destinations with badge for notifications
          final destinations = [
            _destinations[0], // Home
            NavigationDestination(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
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
              selectedIcon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
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
              label: 'Notifications',
            ),
            _destinations[2], // Attendance
          ];

          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (kDebugMode) {
                print(
                  'NAVIGATION: Switching from index $_selectedIndex to index $index',
                );
              }
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: destinations,
            animationDuration: const Duration(milliseconds: 500),
          );
        },
      ),
    );
  }
}

// Error boundary widget to catch widget build errors
class _ErrorBoundary extends StatefulWidget {
  final Widget child;

  const _ErrorBoundary({required this.child});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again later',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Catch build errors in child widgets
    try {
      // This will trigger build of child widgets
    } catch (e, stack) {
      setState(() {
        _hasError = true;
      });
      debugPrint('Build error caught: $e\n$stack');
    }
  }
}
