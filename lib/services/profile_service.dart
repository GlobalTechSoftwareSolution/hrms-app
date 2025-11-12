import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_profile_model.dart';
import '../config/api_config.dart';

class ProfileService {
  static const String employeesEndpoint = '/accounts/employees/';
  static const String managersEndpoint = '/accounts/managers/';
  static const String departmentsEndpoint = '/accounts/departments/';

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    print('ProfileService - user_info from prefs: $userInfoString');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      print('ProfileService - extracted email: ${userInfo['email']}');
      return userInfo['email'];
    }
    print('ProfileService - No user_info found in SharedPreferences');
    return null;
  }

  Future<EmployeeProfile> fetchProfile(String email) async {
    try {
      final url = '${ApiConfig.apiUrl}$employeesEndpoint${Uri.encodeComponent(email)}/';
      print('🌐 Fetching profile from: $url');
      print('⏱️ Timeout set to: ${ApiConfig.requestTimeout.inSeconds} seconds');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      print('✅ Profile API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return EmployeeProfile.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Profile fetch error: $e');
      throw Exception('Error fetching profile: $e');
    }
  }

  Future<List<Manager>> fetchManagers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$managersEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Manager.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch managers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching managers: $e');
      return [];
    }
  }

  Future<List<Department>> fetchDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$departmentsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Department.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch departments: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  Future<bool> updateProfile(EmployeeProfile profile, {File? profileImage}) async {
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiConfig.apiUrl}$employeesEndpoint${Uri.encodeComponent(profile.email)}/'),
      );

      // Add profile picture if provided
      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_picture', profileImage.path),
        );
      }

      // Add all other fields
      final jsonData = profile.toJson();
      jsonData.forEach((key, value) {
        if (value != null && key != 'profile_picture') {
          request.fields[key] = value.toString();
        }
      });

      final streamedResponse = await request.send().timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }
}
