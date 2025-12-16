import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_hr/screens/leaves_screen.dart';
import 'package:smart_hr/providers/hrms_provider.dart';
import 'package:smart_hr/providers/notification_provider.dart';

void main() {
  group('Leaves Screen Tests', () {
    testWidgets('Leaves screen displays correctly', (
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
            child: const LeavesScreen(),
          ),
        ),
      );

      // Check if the leaves title is displayed
      expect(find.text('Leave Requests'), findsOneWidget);

      // Check if no leaves message is displayed
      expect(find.text('No leave requests'), findsOneWidget);
    });
  });
}
