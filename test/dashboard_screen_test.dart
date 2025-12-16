import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_hr/screens/dashboard_screen.dart';
import 'package:smart_hr/providers/hrms_provider.dart';
import 'package:smart_hr/providers/notification_provider.dart';

void main() {
  group('Dashboard Screen Tests', () {
    testWidgets('Dashboard screen displays correctly', (
      WidgetTester tester,
    ) async {
      // Create a mock HRMS provider
      final hrmsProvider = HRMSProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: hrmsProvider),
              ChangeNotifierProvider<NotificationProvider>(
                create: (_) => NotificationProvider(),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      // Wait for the future to complete and content to load
      await tester.pumpAndSettle();

      // Check if the dashboard title is displayed
      expect(find.text('Dashboard Overview'), findsOneWidget);

      // Check if stats cards are displayed
      expect(find.text('Total Employees'), findsOneWidget);
      expect(find.text('Present Today'), findsOneWidget);
      expect(find.text('Pending Leaves'), findsOneWidget);
      expect(find.text('Attendance Rate'), findsOneWidget);
    });
  });
}
