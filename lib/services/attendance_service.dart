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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      print('✅ Attendance API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> attendanceList = data['attendance'] ?? [];
        
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
