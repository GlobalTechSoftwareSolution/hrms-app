import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket_model.dart';
import '../config/api_config.dart';

class TicketService {
  static const String ticketsEndpoint = '/accounts/tickets/';

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return userInfo['email']?.toString().toLowerCase();
    }
    return null;
  }

  Future<String?> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return userInfo['role']?.toString().toLowerCase();
    }
    return null;
  }

  Future<List<Ticket>> fetchTickets() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        List<dynamic> data = [];

        // Handle different response structures
        if (responseBody is List) {
          // Direct list response
          data = responseBody;
        } else if (responseBody is Map<String, dynamic>) {
          // Wrapped response with success/data structure
          if (responseBody['success'] == true && responseBody['data'] != null) {
            final responseData = responseBody['data'];
            if (responseData is List) {
              data = responseData;
            } else if (responseData is Map<String, dynamic> &&
                responseData.containsKey('results')) {
              // Paginated response
              data = responseData['results'] ?? [];
            } else {
              data = [];
            }
          } else if (responseBody.containsKey('results')) {
            // Direct paginated response
            data = responseBody['results'] ?? [];
          } else if (responseBody.containsKey('tickets')) {
            // Direct tickets response (as per API response)
            data = responseBody['tickets'] ?? [];
          } else {
            data = [];
          }
        } else {
          data = [];
        }

        final userEmail = await _getUserEmail();
        final userRole = await _getUserRole();

        // For admin users, show all tickets. For others, filter by involvement
        final tickets = data.map((json) => Ticket.fromJson(json)).where((
          ticket,
        ) {
          // Admin users see all tickets
          if (userRole == 'admin') return true;

          // Regular users only see tickets they're involved with
          if (userEmail == null) return false;
          return [
            ticket.assignedBy?.toLowerCase(),
            ticket.assignedTo?.toLowerCase(),
            ticket.closedBy?.toLowerCase(),
            ticket.closedTo?.toLowerCase(),
          ].contains(userEmail);
        }).toList();

        return tickets;
      } else {
        throw Exception('Failed to fetch tickets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tickets: $e');
    }
  }

  Future<Map<String, List<Ticket>>> fetchCategorizedTickets() async {
    final tickets = await fetchTickets();
    final userEmail = await _getUserEmail();

    return {
      'assignedToMe': tickets
          .where((t) => t.assignedTo?.toLowerCase() == userEmail)
          .toList(),
      'raisedByMe': tickets
          .where((t) => t.assignedBy?.toLowerCase() == userEmail)
          .toList(),
      'closedByMe': tickets
          .where((t) => t.closedBy?.toLowerCase() == userEmail)
          .toList(),
      'allTickets': tickets,
    };
  }

  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? assignedTo,
  }) async {
    try {
      final userEmail = await _getUserEmail();
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      final payload = {
        'assigned_by': userEmail,
        'assigned_to': assignedTo,
        'subject': subject,
        'description': description,
        'status': 'Open',
        'priority':
            priority.substring(0, 1).toUpperCase() + priority.substring(1),
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Ticket.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create ticket: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating ticket: $e');
    }
  }

  Future<Ticket> updateTicketStatus({
    required String ticketId,
    required String newStatus,
    String? closedDescription,
  }) async {
    try {
      final userEmail = await _getUserEmail();
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      final apiStatus = newStatus == 'in-progress'
          ? 'In Progress'
          : newStatus == 'open'
          ? 'Open'
          : newStatus == 'closed'
          ? 'Closed'
          : newStatus;

      final Map<String, dynamic> patchPayload = {'status': apiStatus};

      if (newStatus == 'closed' || newStatus == 'in-progress') {
        patchPayload['closed_description'] = closedDescription ?? '';

        // Only set closed_by when closing the ticket, not when setting to in-progress
        // Backend validation requires closed_by to be the assigned user
        if (newStatus == 'closed') {
          patchPayload['closed_by'] = userEmail;
        }
      } else if (newStatus == 'open') {
        // For opening tickets, don't include closed_description or closed_by
        // Just update the status
      }

      // Debug: Print the URL and payload
      print(
        '🎫 Updating ticket: ${ApiConfig.apiUrl}$ticketsEndpoint$ticketId/',
      );
      print('🎫 Payload: $patchPayload');

      // Get auth token and only include in headers if it's valid
      final authToken = await _getAuthToken();
      final headers = {'Content-Type': 'application/json'};

      // Only add authorization header if token exists
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .patch(
            Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint$ticketId/'),
            headers: headers,
            body: jsonEncode(patchPayload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('🎫 Update response status: ${response.statusCode}');
      print('🎫 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Handle different response structures for single ticket
        Map<String, dynamic> ticketData = {};

        if (responseBody is Map<String, dynamic>) {
          // Direct ticket response
          ticketData = responseBody;
        } else {
          // If it's not a map, throw an error
          throw Exception('Invalid response format for ticket update');
        }

        return Ticket.fromJson(ticketData);
      } else {
        throw Exception(
          'Failed to update ticket: Status ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('🎫 Update ticket error: $e');
      throw Exception('Error updating ticket: $e');
    }
  }

  // Helper method to get auth token if available
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper method to get a single ticket
  Future<Ticket?> _getTicket(String ticketId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint$ticketId/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return Ticket.fromJson(responseBody);
      } else {
        print('Failed to fetch ticket: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching ticket: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      // First try the employees endpoint as that's more appropriate for ticket assignment
      final response = await http
          .get(
            Uri.parse('${ApiConfig.apiUrl}/accounts/employees/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        List<dynamic> data = [];

        // Handle different response structures
        if (responseBody is List) {
          // Direct list response
          data = responseBody;
        } else if (responseBody is Map<String, dynamic>) {
          // Wrapped response with success/data structure
          if (responseBody['success'] == true && responseBody['data'] != null) {
            final responseData = responseBody['data'];
            if (responseData is List) {
              data = responseData;
            } else if (responseData is Map<String, dynamic> &&
                responseData.containsKey('results')) {
              // Paginated response
              data = responseData['results'] ?? [];
            } else if (responseData.containsKey('employees')) {
              // Check for employees key specifically
              data = responseData['employees'] ?? [];
            } else {
              data = [];
            }
          } else if (responseBody.containsKey('results')) {
            // Direct paginated response
            data = responseBody['results'] ?? [];
          } else if (responseBody.containsKey('employees')) {
            // Check for employees key in top level
            data = responseBody['employees'] ?? [];
          } else {
            data = [];
          }
        } else {
          data = [];
        }

        return data.cast<Map<String, dynamic>>();
      } else {
        // If employees endpoint fails, try users endpoint as fallback
        final usersResponse = await http
            .get(
              Uri.parse('${ApiConfig.apiUrl}/accounts/users/'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(ApiConfig.requestTimeout);

        if (usersResponse.statusCode == 200) {
          final usersResponseBody = jsonDecode(usersResponse.body);
          List<dynamic> data = [];

          // Handle different response structures for users
          if (usersResponseBody is List) {
            // Direct list response
            data = usersResponseBody;
          } else if (usersResponseBody is Map<String, dynamic>) {
            // Wrapped response with success/data structure
            if (usersResponseBody['success'] == true &&
                usersResponseBody['data'] != null) {
              final responseData = usersResponseBody['data'];
              if (responseData is List) {
                data = responseData;
              } else if (responseData is Map<String, dynamic> &&
                  responseData.containsKey('results')) {
                // Paginated response
                data = responseData['results'] ?? [];
              } else {
                data = [];
              }
            } else if (usersResponseBody.containsKey('results')) {
              // Direct paginated response
              data = usersResponseBody['results'] ?? [];
            } else {
              data = [];
            }
          } else {
            data = [];
          }

          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Failed to fetch users from both endpoints');
        }
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }
}
