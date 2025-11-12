import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/employee_documents_model.dart';
import '../config/api_config.dart';

class DocumentsService {
  static const String documentsEndpoint = '/accounts/get_document/';
  static const String updateDocumentsEndpoint = '/accounts/update_document/';

  Future<EmployeeDocuments?> fetchDocuments(String email) async {
    try {
      final url = '${ApiConfig.apiUrl}$documentsEndpoint${Uri.encodeComponent(email)}/';
      print('🌐 Fetching documents from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      print('✅ Documents API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return EmployeeDocuments.fromJson(data[0]);
        }
        return null;
      } else {
        print('⚠️ Failed to fetch documents: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Documents fetch error: $e');
      return null;
    }
  }

  Future<bool> updateDocuments(String email, Map<String, File> documents) async {
    try {
      final url = '${ApiConfig.apiUrl}$updateDocumentsEndpoint${Uri.encodeComponent(email)}/';
      print('🌐 Updating documents at: $url');

      final request = http.MultipartRequest('PATCH', Uri.parse(url));

      // Add all document files
      for (var entry in documents.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
      }

      final streamedResponse = await request.send().timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('✅ Update documents response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        print('⚠️ Failed to update documents: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update documents: ${response.body}');
      }
    } catch (e) {
      print('❌ Documents update error: $e');
      throw Exception('Error updating documents: $e');
    }
  }
}
