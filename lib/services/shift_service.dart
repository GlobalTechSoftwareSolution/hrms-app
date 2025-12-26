import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/shift_model.dart';
import '../config/api_config.dart';

class ShiftService {
  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final ShiftService _instance = ShiftService._internal();
  factory ShiftService() => _instance;
  ShiftService._internal();

  // Get headers with authentication token
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Fetch all employees
  Future<List<Employee>> fetchEmployees() async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/employees/';
      print('🌐 Fetching employees from: $url');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Employees API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> employees = [];
        if (data is List) {
          employees = data;
        } else if (data is Map<String, dynamic>) {
          employees =
              data['employees'] ?? data['data'] ?? data['results'] ?? [];
        }

        return employees.map((json) => Employee.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch employees: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Employees fetch error: $e');
      throw Exception('Error fetching employees: $e');
    }
  }

  // Fetch shifts for a specific date
  Future<List<Shift>> fetchShifts(String date) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/list_shifts/';
      print('🌐 Fetching shifts from: $url for date: $date');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Shifts API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> shifts = [];
        if (data is Map<String, dynamic> && data['shifts'] is List) {
          shifts = data['shifts'];
        } else if (data is List) {
          shifts = data;
        }

        // Filter shifts for the specified date
        final dateShifts = shifts
            .map((json) => Shift.fromJson(json))
            .where((shift) => shift.date == date && shift.status == 'active')
            .toList();

        return dateShifts;
      } else {
        throw Exception('Failed to fetch shifts: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Shifts fetch error: $e');
      throw Exception('Error fetching shifts: $e');
    }
  }

  // Create a new shift
  Future<Shift> createShift({
    required String employeeEmail,
    required String shiftType,
    required String date,
    required String managerEmail,
  }) async {
    try {
      // Determine start and end times based on shift type
      String startTime, endTime;
      switch (shiftType) {
        case 'Morning':
          startTime = '09:00';
          endTime = '17:00';
          break;
        case 'Evening':
          startTime = '14:00';
          endTime = '22:00';
          break;
        case 'Night':
          startTime = '22:00';
          endTime = '06:00';
          break;
        default:
          startTime = '09:00';
          endTime = '17:00';
      }

      final url = '${ApiConfig.apiUrl}/accounts/create_shift/';
      print('🌐 Creating shift at: $url');

      final payload = {
        'emp_email': employeeEmail,
        'manager_email': managerEmail,
        'shift': shiftType,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
      };

      print('📤 Sending payload: $payload');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Create shift response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Shift.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ??
              errorData['message'] ??
              'Failed to create shift',
        );
      }
    } catch (e) {
      print('❌ Create shift error: $e');
      throw Exception('Error creating shift: $e');
    }
  }

  // Delete a shift
  Future<bool> deleteShift(int shiftId) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/delete_shift/$shiftId/';
      print('🌐 Deleting shift at: $url');

      final response = await http
          .delete(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Delete shift response status: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete shift: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Delete shift error: $e');
      throw Exception('Error deleting shift: $e');
    }
  }

  // Bulk create shifts
  Future<List<Shift>> bulkCreateShifts(
    List<Map<String, dynamic>> shiftsData,
  ) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/bulk_create_shifts/';
      print('🌐 Bulk creating shifts at: $url');

      final payload = {'shifts': shiftsData};
      print('📤 Sending bulk payload with ${shiftsData.length} shifts');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Bulk create response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh shifts to get server-generated IDs
        final refreshResponse = await http
            .get(
              Uri.parse('${ApiConfig.apiUrl}/accounts/list_shifts/'),
              headers: await _getHeaders(),
            )
            .timeout(ApiConfig.requestTimeout);

        if (refreshResponse.statusCode == 200) {
          final data = jsonDecode(refreshResponse.body);
          List<dynamic> shifts = [];
          if (data is Map<String, dynamic> && data['shifts'] is List) {
            shifts = data['shifts'];
          } else if (data is List) {
            shifts = data;
          }

          return shifts.map((json) => Shift.fromJson(json)).toList();
        }

        return [];
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ??
              errorData['message'] ??
              'Failed to bulk create shifts',
        );
      }
    } catch (e) {
      print('❌ Bulk create shifts error: $e');
      throw Exception('Error bulk creating shifts: $e');
    }
  }

  // Bulk delete shifts
  Future<bool> bulkDeleteShifts(List<int> shiftIds) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/bulk_delete_shifts/';
      print('🌐 Bulk deleting shifts at: $url');

      final payload = {'shift_ids': shiftIds};
      print('📤 Deleting ${shiftIds.length} shifts');

      final response = await http
          .delete(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Bulk delete response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to bulk delete shifts: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Bulk delete shifts error: $e');
      throw Exception('Error bulk deleting shifts: $e');
    }
  }

  // Fetch overtime records
  Future<List<OvertimeRecord>> fetchOvertimeRecords(String date) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/list_ot/';
      print('🌐 Fetching overtime records from: $url for date: $date');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Overtime API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> records = [];
        if (data is List) {
          records = data;
        } else if (data is Map<String, dynamic>) {
          records = data['ot_records'] ?? data['data'] ?? data['results'] ?? [];
        }

        // Filter records for the specified date
        final dateRecords = records
            .map((json) => OvertimeRecord.fromJson(json))
            .where((record) {
              if (record.otStart == null) return false;
              final recordDate = DateTime.parse(record.otStart!);
              final filterDate = DateTime.parse(date);
              return recordDate.year == filterDate.year &&
                  recordDate.month == filterDate.month &&
                  recordDate.day == filterDate.day;
            })
            .toList();

        return dateRecords;
      } else {
        throw Exception(
          'Failed to fetch overtime records: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Overtime records fetch error: $e');
      throw Exception('Error fetching overtime records: $e');
    }
  }

  // Create overtime record
  Future<OvertimeRecord> createOvertimeRecord({
    required String employeeEmail,
    required String managerEmail,
    required String otStart,
    required String otEnd,
  }) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/create_ot/';
      print('🌐 Creating overtime record at: $url');

      final payload = {
        'email': employeeEmail,
        'manager_email': managerEmail,
        'ot_start': otStart,
        'ot_end': otEnd,
      };

      print('📤 Sending OT payload: $payload');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Create OT response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return OvertimeRecord.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ??
              errorData['message'] ??
              'Failed to create overtime record',
        );
      }
    } catch (e) {
      print('❌ Create overtime record error: $e');
      throw Exception('Error creating overtime record: $e');
    }
  }

  // Delete overtime record
  Future<bool> deleteOvertimeRecord(int recordId) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/delete_ot/$recordId/';
      print('🌐 Deleting overtime record at: $url');

      final response = await http
          .delete(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Delete OT response status: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to delete overtime record: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Delete overtime record error: $e');
      throw Exception('Error deleting overtime record: $e');
    }
  }
}
