import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project_model.dart';
import '../config/api_config.dart';

class ProjectService {
  static const String projectsEndpoint = '/accounts/list_projects/';

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return userInfo['email']?.toString().toLowerCase();
    }
    return null;
  }

  Future<List<Project>> fetchProjects() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$projectsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userEmail = await _getUserEmail();
        
        // Extract projects array from response
        final projectsList = data['projects'] ?? data;
        
        if (projectsList is! List) {
          throw Exception('Invalid response format');
        }

        // Parse all projects
        final allProjects = projectsList
            .map((json) => Project.fromJson(json))
            .toList();

        // Filter projects where user is a member
        if (userEmail != null) {
          return allProjects.where((project) {
            return project.members.any(
              (member) => member.toLowerCase() == userEmail,
            );
          }).toList();
        }

        return allProjects;
      } else {
        throw Exception('Failed to fetch projects: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching projects: $e');
    }
  }

  Future<Project> fetchProjectById(String projectId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$projectsEndpoint$projectId/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return Project.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch project: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching project: $e');
    }
  }
}
