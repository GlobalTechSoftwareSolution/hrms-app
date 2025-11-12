import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resignation_model.dart';
import '../config/api_config.dart';

class ResignationService {
  static const String resignationEndpoint = '/accounts/releaved/';
  static const String listResignationsEndpoint = '/accounts/list_releaved/';
  static const String employeesEndpoint = '/accounts/employees/';

  Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return {
        'email': userInfo['email']?.toString().toLowerCase() ?? '',
        'fullname': userInfo['fullname'] ?? '',
        'department': userInfo['department'] ?? '',
        'designation': userInfo['designation'] ?? '',
      };
    }
    return {};
  }

  Future<Map<String, String>> fetchEmployeeDetails(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$employeesEndpoint$email/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'email': data['email'] ?? '',
          'fullname': data['fullname'] ?? '',
          'department': data['department'] ?? '',
          'designation': data['designation'] ?? '',
        };
      } else {
        throw Exception('Failed to fetch employee details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching employee details: $e');
    }
  }

  Future<ResignationStatus?> fetchResignationStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$listResignationsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Find resignation for this user
        final userResignation = data.firstWhere(
          (item) => item['email']?.toString().toLowerCase() == email.toLowerCase(),
          orElse: () => null,
        );

        if (userResignation != null) {
          return ResignationStatus.fromJson(userResignation);
        }
        return null;
      } else {
        throw Exception('Failed to fetch resignation status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching resignation status: $e');
    }
  }

  Future<bool> submitResignation(ResignationRequest request) async {
    try {
      // Step 1: Update employee record with resignation reason
      final employeeUpdatePayload = {
        'reason_for_resignation': request.reasonForResignation,
        'fullname': request.fullname,
        'department': request.department,
        'designation': request.designation,
        'email': request.email,
      };

      final updateResponse = await http.patch(
        Uri.parse('${ApiConfig.apiUrl}$employeesEndpoint${request.email}/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employeeUpdatePayload),
      ).timeout(ApiConfig.requestTimeout);

      if (updateResponse.statusCode != 200) {
        throw Exception('Failed to update employee record: ${updateResponse.statusCode}');
      }

      // Step 2: Submit resignation request
      final resignationResponse = await http.post(
        Uri.parse('${ApiConfig.apiUrl}$resignationEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(ApiConfig.requestTimeout);

      if (resignationResponse.statusCode == 200 || resignationResponse.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to submit resignation: ${resignationResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Error submitting resignation: $e');
    }
  }
}
