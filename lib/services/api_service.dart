import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Backend URL - local development (using 10.0.2.2 for Android emulator to access host)
  static const String baseUrl = 'http://10.0.2.2:8001/api';

  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Get headers with authentication token
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        headers['Authorization'] =
            'Bearer $token'; // or 'Token $token' for Django Token Auth
      }
    }

    return headers;
  }

  // Save authentication token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Get authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Clear authentication token
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== AUTH ENDPOINTS ====================

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Save token if present
        if (data['token'] != null) {
          await saveToken(data['token']);
        }

        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Register/Signup
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Save token if present
        if (data['token'] != null) {
          await saveToken(data['token']);
        }

        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout/'),
        headers: await _getHeaders(),
      );

      await clearToken();

      return {'success': true};
    } catch (e) {
      await clearToken();
      return {'success': true};
    }
  }

  // ==================== EMPLOYEE ENDPOINTS ====================

  // Get all employees
  Future<Map<String, dynamic>> getEmployees() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to fetch employees'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Get single employee
  Future<Map<String, dynamic>> getEmployee(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to fetch employee'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Create employee
  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> employeeData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/employees/'),
        headers: await _getHeaders(),
        body: jsonEncode(employeeData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to create employee'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Update employee (PATCH)
  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> employeeData,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
        body: jsonEncode(employeeData),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to update employee'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Delete employee
  Future<Map<String, dynamic>> deleteEmployee(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'error': 'Failed to delete employee'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== ATTENDANCE ENDPOINTS ====================

  // Get attendance records
  Future<Map<String, dynamic>> getAttendance({
    String? employeeId,
    String? date,
  }) async {
    try {
      var url = '$baseUrl/attendance/';
      final queryParams = <String, String>{};

      if (employeeId != null) queryParams['employee_id'] = employeeId;
      if (date != null) queryParams['date'] = date;

      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to fetch attendance'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Mark attendance
  Future<Map<String, dynamic>> markAttendance(
    Map<String, dynamic> attendanceData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/'),
        headers: await _getHeaders(),
        body: jsonEncode(attendanceData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to mark attendance'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== LEAVE ENDPOINTS ====================

  // Get leave requests
  Future<Map<String, dynamic>> getLeaveRequests({String? status}) async {
    try {
      var url = '$baseUrl/leaves/';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to fetch leave requests'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Create leave request
  Future<Map<String, dynamic>> createLeaveRequest(
    Map<String, dynamic> leaveData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/leaves/'),
        headers: await _getHeaders(),
        body: jsonEncode(leaveData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to create leave request'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Update leave request status (PATCH)
  Future<Map<String, dynamic>> updateLeaveStatus(
    String id,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/leaves/$id/'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to update leave status'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== DASHBOARD/STATS ENDPOINTS ====================

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to fetch dashboard stats'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Request failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        // Return error response with data for better error handling
        final errorData = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        return {'success': false, 'error': 'Request failed', 'data': errorData};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Generic PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Request failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'error': 'Request failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
