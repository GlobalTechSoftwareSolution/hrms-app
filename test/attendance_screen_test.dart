import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_hr/screens/attendance_screen.dart';
import 'package:smart_hr/providers/hrms_provider.dart';
import 'package:smart_hr/providers/notification_provider.dart';

void main() {
  group('Attendance Screen Tests', () {
    testWidgets('Attendance screen displays correctly', (
      WidgetTester tester,
    ) async {
      // Create providers
      final hrmsProvider = HRMSProvider();
      final notificationProvider = NotificationProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: hrmsProvider),
              ChangeNotifierProvider.value(value: notificationProvider),
            ],
            child: const AttendanceScreen(),
          ),
        ),
      );

      // Wait for content to load
      await tester.pumpAndSettle();

      // Check if the attendance title is displayed
      expect(find.text('Present'), findsOneWidget);
    });
  });
}
