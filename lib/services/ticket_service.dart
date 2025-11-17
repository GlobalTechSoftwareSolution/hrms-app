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

  Future<List<Ticket>> fetchTickets() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final userEmail = await _getUserEmail();
        
        // Filter tickets related to the current user
        final tickets = data
            .map((json) => Ticket.fromJson(json))
            .where((ticket) {
              if (userEmail == null) return false;
              return [
                ticket.assignedBy?.toLowerCase(),
                ticket.assignedTo?.toLowerCase(),
                ticket.closedBy?.toLowerCase(),
                ticket.closedTo?.toLowerCase(),
              ].contains(userEmail);
            })
            .toList();
        
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
        'priority': priority.substring(0, 1).toUpperCase() + priority.substring(1),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(ApiConfig.requestTimeout);

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
        patchPayload['closed_by'] = userEmail;
      }

      final response = await http.patch(
        Uri.parse('${ApiConfig.apiUrl}$ticketsEndpoint$ticketId/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchPayload),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return Ticket.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update ticket: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating ticket: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/accounts/users/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch users');
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }
}
