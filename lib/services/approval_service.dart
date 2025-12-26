import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_approval_model.dart';
import '../config/api_config.dart';

class ApprovalService {
  static const String usersEndpoint = '/accounts/users/';
  static const String approveEndpoint = '/accounts/approve/';
  static const String rejectEndpoint = '/accounts/reject/';

  Future<List<UserApproval>> fetchUsers() async {
    try {
      final url = '${ApiConfig.apiUrl}$usersEndpoint';
      print('🌐 Fetching users from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(ApiConfig.requestTimeout);

      print('✅ Users API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle case where response is directly a list
        if (data is List) {
          return data.map((json) => UserApproval.fromJson(json)).toList();
        }

        // Handle case where response is a map containing a list
        if (data is Map<String, dynamic>) {
          final List<dynamic> userList =
              data['users'] ?? data['results'] ?? data['data'] ?? [];
          return userList.map((json) => UserApproval.fromJson(json)).toList();
        }

        // Fallback: return empty list
        return [];
      } else {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Users fetch error: $e');
      throw Exception('Error fetching users: $e');
    }
  }

  Future<bool> approveUser(String email) async {
    try {
      final url = '${ApiConfig.apiUrl}$approveEndpoint';
      print('🌐 Approving user at: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Approve response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to approve user: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Approve error: $e');
      throw Exception('Error approving user: $e');
    }
  }

  Future<bool> rejectUser(String email) async {
    try {
      final url = '${ApiConfig.apiUrl}$rejectEndpoint';
      print('🌐 Rejecting user at: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Reject response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to reject user: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Reject error: $e');
      throw Exception('Error rejecting user: $e');
    }
  }
}
