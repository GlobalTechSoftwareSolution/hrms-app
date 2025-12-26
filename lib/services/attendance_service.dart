import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_record_model.dart';
import '../config/api_config.dart';

class AttendanceService {
  static const String listAttendanceEndpoint = '/accounts/list_attendance/';

  Future<List<AttendanceRecord>> fetchAttendance() async {
    try {
      final url = '${ApiConfig.apiUrl}$listAttendanceEndpoint';
      print('🌐 Fetching attendance from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(ApiConfig.requestTimeout);

      print('✅ Attendance API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        List<dynamic> attendanceList = [];

        // Handle different response structures
        if (responseBody is List) {
          // Direct list response
          attendanceList = responseBody;
        } else if (responseBody is Map<String, dynamic>) {
          // Check for nested attendance data
          if (responseBody.containsKey('attendance')) {
            final attendanceData = responseBody['attendance'];
            if (attendanceData is List) {
              attendanceList = attendanceData;
            } else {
              attendanceList = [];
            }
          }
          // Check for wrapped response with success/data structure
          else if (responseBody['success'] == true &&
              responseBody['data'] != null) {
            final responseData = responseBody['data'];
            if (responseData is List) {
              attendanceList = responseData;
            } else if (responseData is Map<String, dynamic> &&
                responseData.containsKey('attendance')) {
              attendanceList = responseData['attendance'] ?? [];
            } else if (responseData is Map<String, dynamic> &&
                responseData.containsKey('results')) {
              // Paginated response
              attendanceList = responseData['results'] ?? [];
            } else {
              attendanceList = [];
            }
          }
          // Check for direct results
          else if (responseBody.containsKey('results')) {
            attendanceList = responseBody['results'] ?? [];
          } else {
            attendanceList = [];
          }
        } else {
          attendanceList = [];
        }

        return attendanceList
            .map((json) => AttendanceRecord.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch attendance: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Attendance fetch error: $e');
      throw Exception('Error fetching attendance: $e');
    }
  }
}
