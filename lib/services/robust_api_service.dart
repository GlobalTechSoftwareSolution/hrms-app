import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A robust API service wrapper that handles errors properly
class RobustApiService {
  // Backend URL - deployed on cloud
  static const String baseUrl = 'https://globaltechsoftwaresolutions.cloud/api';

  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final RobustApiService _instance = RobustApiService._internal();
  factory RobustApiService() => _instance;
  RobustApiService._internal();

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

  // Generic request handler with proper error handling
  Future<ApiResponse> _handleRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      return _processResponse(response);
    } on SocketException catch (e) {
      return ApiResponse.error('No internet connection: ${e.message}');
    } on TimeoutException catch (e) {
      return ApiResponse.error('Request timeout: ${e.message}');
    } on HandshakeException catch (e) {
      return ApiResponse.error(
        'SSL handshake failed: ${e.osError?.message ?? 'Unknown error'}',
      );
    } on FormatException catch (e) {
      return ApiResponse.error('Invalid response format: ${e.message}');
    } on Exception catch (e) {
      return ApiResponse.error('Unexpected error: ${e.toString()}');
    }
  }

  // Process HTTP response
  ApiResponse _processResponse(http.Response response) {
    try {
      // Handle successful responses
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse.success(null);
        }

        final data = jsonDecode(response.body);
        return ApiResponse.success(data);
      }

      // Handle error responses
      String errorMessage;
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        } else {
          errorMessage = errorData.toString();
        }
      } catch (e) {
        errorMessage = response.body.isEmpty
            ? 'HTTP ${response.statusCode}'
            : response.body;
      }

      return ApiResponse.error(errorMessage, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.error('Failed to process response: ${e.toString()}');
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  // Login
  Future<ApiResponse> login(String email, String password) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );
    });
  }

  // Register/Signup
  Future<ApiResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
    });
  }

  // Logout
  Future<ApiResponse> logout() async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/logout/'),
        headers: await _getHeaders(),
      );
    }).whenComplete(clearToken);
  }

  // ==================== EMPLOYEE ENDPOINTS ====================

  // Get all employees
  Future<ApiResponse> getEmployees() async {
    return _handleRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/employees/'),
        headers: await _getHeaders(),
      );
    });
  }

  // Get single employee
  Future<ApiResponse> getEmployee(String id) async {
    return _handleRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
      );
    });
  }

  // Create employee
  Future<ApiResponse> createEmployee(Map<String, dynamic> employeeData) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/employees/'),
        headers: await _getHeaders(),
        body: jsonEncode(employeeData),
      );
    });
  }

  // Update employee (PATCH)
  Future<ApiResponse> updateEmployee(
    String id,
    Map<String, dynamic> employeeData,
  ) async {
    return _handleRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
        body: jsonEncode(employeeData),
      );
    });
  }

  // Delete employee
  Future<ApiResponse> deleteEmployee(String id) async {
    return _handleRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/employees/$id/'),
        headers: await _getHeaders(),
      );
    });
  }

  // ==================== ATTENDANCE ENDPOINTS ====================

  // Get attendance records
  Future<ApiResponse> getAttendance({String? employeeId, String? date}) async {
    return _handleRequest(() async {
      var url = '$baseUrl/attendance/';
      final queryParams = <String, String>{};

      if (employeeId != null) queryParams['employee_id'] = employeeId;
      if (date != null) queryParams['date'] = date;

      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      return await http.get(Uri.parse(url), headers: await _getHeaders());
    });
  }

  // Mark attendance
  Future<ApiResponse> markAttendance(
    Map<String, dynamic> attendanceData,
  ) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/attendance/'),
        headers: await _getHeaders(),
        body: jsonEncode(attendanceData),
      );
    });
  }

  // ==================== LEAVE ENDPOINTS ====================

  // Get leave requests
  Future<ApiResponse> getLeaveRequests({String? status}) async {
    return _handleRequest(() async {
      var url = '$baseUrl/leaves/';
      if (status != null) {
        url += '?status=$status';
      }

      return await http.get(Uri.parse(url), headers: await _getHeaders());
    });
  }

  // Create leave request
  Future<ApiResponse> createLeaveRequest(Map<String, dynamic> leaveData) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/leaves/'),
        headers: await _getHeaders(),
        body: jsonEncode(leaveData),
      );
    });
  }

  // Update leave request status (PATCH)
  Future<ApiResponse> updateLeaveStatus(String id, String status) async {
    return _handleRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl/leaves/$id/'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
    });
  }

  // ==================== DASHBOARD/STATS ENDPOINTS ====================

  // Get dashboard statistics
  Future<ApiResponse> getDashboardStats() async {
    return _handleRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/dashboard/stats/'),
        headers: await _getHeaders(),
      );
    });
  }

  // Generic GET request
  Future<ApiResponse> get(String endpoint) async {
    return _handleRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
    });
  }

  // Generic POST request
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> data) async {
    return _handleRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });
  }

  // Generic PATCH request
  Future<ApiResponse> patch(String endpoint, Map<String, dynamic> data) async {
    return _handleRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });
  }

  // Generic DELETE request
  Future<ApiResponse> delete(String endpoint) async {
    return _handleRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
    });
  }
}

/// Response wrapper for API calls
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;

  ApiResponse.success(this.data)
    : success = true,
      error = null,
      statusCode = null;

  ApiResponse.error(this.error, {this.statusCode, dynamic data})
    : success = false,
      data = data;

  bool get hasError => !success;

  @override
  String toString() {
    return 'ApiResponse{success: $success, data: $data, error: $error, statusCode: $statusCode}';
  }
}
