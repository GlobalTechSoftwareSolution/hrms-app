import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/petty_cash_model.dart';
import '../config/api_config.dart';

class PettyCashService {
  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final PettyCashService _instance = PettyCashService._internal();
  factory PettyCashService() => _instance;
  PettyCashService._internal();

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

  // Fetch all petty cash transactions
  Future<List<PettyCashTransaction>> fetchPettyCashTransactions() async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/list_pettycashs/';
      print('🌐 Fetching petty cash transactions from: $url');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(ApiConfig.requestTimeout);

      print('✅ Petty cash API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> transactions = [];
        if (data is List) {
          transactions = data;
        } else if (data is Map<String, dynamic>) {
          transactions =
              data['pettycash_records'] ??
              data['pettycash'] ??
              data['transactions'] ??
              data['data'] ??
              [];
        }

        return transactions
            .map((json) => PettyCashTransaction.fromJson(json))
            .toList();
      } else {
        throw Exception(
          'Failed to fetch petty cash transactions: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Petty cash fetch error: $e');
      throw Exception('Error fetching petty cash transactions: $e');
    }
  }

  // Create a new petty cash transaction
  Future<PettyCashTransaction> createPettyCashTransaction({
    required String email,
    required DateTime date,
    required String description,
    required String category,
    required String transactionType,
    required String amount,
    String? remarks,
  }) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/create_pettycash/';
      print('🌐 Creating petty cash transaction at: $url');

      final payload = {
        'email': email,
        'date': date.toIso8601String().split('T')[0],
        'description': description,
        'category': category,
        'transaction_type': transactionType,
        'amount': amount,
        'remarks': remarks,
      };

      print('📤 Sending payload: $payload');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Create response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return PettyCashTransaction.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ??
              errorData['message'] ??
              'Failed to create transaction',
        );
      }
    } catch (e) {
      print('❌ Create transaction error: $e');
      throw Exception('Error creating petty cash transaction: $e');
    }
  }

  // Approve a petty cash transaction
  Future<bool> approvePettyCashTransaction(
    int transactionId,
    String approverEmail,
  ) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/approve_pettycash/';
      print('🌐 Approving petty cash transaction at: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({
              'transaction_id': transactionId,
              'approved_by': approverEmail,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Approve response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Failed to approve transaction: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Approve transaction error: $e');
      throw Exception('Error approving petty cash transaction: $e');
    }
  }

  // Reject a petty cash transaction
  Future<bool> rejectPettyCashTransaction(
    int transactionId,
    String rejectorEmail,
    String reason,
  ) async {
    try {
      final url = '${ApiConfig.apiUrl}/accounts/reject_pettycash/';
      print('🌐 Rejecting petty cash transaction at: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({
              'transaction_id': transactionId,
              'rejected_by': rejectorEmail,
              'rejection_reason': reason,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      print('✅ Reject response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to reject transaction: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Reject transaction error: $e');
      throw Exception('Error rejecting petty cash transaction: $e');
    }
  }

  // Get monthly fund summary
  Future<PettyCashMonthlyFund> getMonthlyFundSummary(
    int month,
    int year,
  ) async {
    try {
      final transactions = await fetchPettyCashTransactions();

      // Filter transactions for the specified month and year
      final monthTransactions = transactions.where((t) {
        return t.date.month == month && t.date.year == year;
      }).toList();

      // Calculate totals
      double totalCredits = 0;
      double totalDebits = 0;

      for (var transaction in monthTransactions) {
        final amount = double.tryParse(transaction.amount) ?? 0;
        if (transaction.transactionType == 'Credit') {
          totalCredits += amount;
        } else {
          totalDebits += amount;
        }
      }

      final monthName = _getMonthName(month);

      return PettyCashMonthlyFund(
        month: monthName,
        year: year,
        allocatedAmount: totalCredits,
        spentAmount: totalDebits,
        remainingAmount: totalCredits - totalDebits,
      );
    } catch (e) {
      print('❌ Monthly fund summary error: $e');
      throw Exception('Error calculating monthly fund summary: $e');
    }
  }

  // Export petty cash transactions to CSV
  Future<String> exportToCSV(List<PettyCashTransaction> transactions) async {
    final headers = [
      'Date',
      'Voucher No',
      'Description',
      'Category',
      'Type',
      'Amount',
      'Balance',
      'Status',
      'Email',
      'Remarks',
    ];

    final csvData = transactions.map(
      (t) => [
        t.date.toIso8601String().split('T')[0],
        t.voucherNo ?? 'N/A',
        t.description,
        t.category,
        t.transactionType,
        t.amount,
        t.balance,
        t.status,
        t.email,
        t.remarks ?? '',
      ],
    );

    final csvContent = [headers, ...csvData]
        .map(
          (row) =>
              row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
        )
        .join('\n');

    return csvContent;
  }

  // Get current user email from storage
  Future<String?> getCurrentUserEmail() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return null;

      // You might need to decode the JWT token or make an API call to get user info
      // For now, we'll try to get it from shared preferences
      final prefs = await getSharedPreferences();
      final userInfoString = prefs.getString('user_info');
      if (userInfoString != null) {
        final userInfo = jsonDecode(userInfoString);
        return userInfo['email']?.toString();
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user email: $e');
      return null;
    }
  }

  // Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  // Helper method to get shared preferences (avoid circular imports)
  Future<dynamic> getSharedPreferences() async {
    // This is a simplified version - in real implementation you'd import shared_preferences
    return null;
  }
}
