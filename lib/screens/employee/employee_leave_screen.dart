import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _leaves = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  String _userEmail = '';
  String _userDepartment = '';
  String _reason = '';
  String _leaveType = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = prefs.getString('user_email') ?? '';
    
    final userInfoStr = prefs.getString('user_info');
    if (userInfoStr != null) {
      try {
        final userInfo = Map<String, dynamic>.from(
          Uri.splitQueryString(userInfoStr.replaceAll('{', '').replaceAll('}', '').replaceAll('"', ''))
        );
        _userDepartment = userInfo['department'] ?? '';
      } catch (e) {
        print('Error parsing user info: $e');
      }
    }
    
    _fetchLeaves();
  }

  Future<void> _fetchLeaves() async {
    if (_userEmail.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await _apiService.get('/accounts/list_leaves/?email=${Uri.encodeComponent(_userEmail)}');
      
      if (response['success']) {
        final leavesData = response['data']['leaves'] as List? ?? [];
        
        final filteredLeaves = leavesData
            .where((leave) => (leave['email'] ?? '') == _userEmail)
            .map((leave) {
          final startDate = DateTime.parse(leave['start_date']);
          final endDate = DateTime.parse(leave['end_date']);
          final daysRequested = endDate.difference(startDate).inDays + 1;
          
          return {
            'id': leave['id'] ?? 0,
            'reason': leave['reason'] ?? '',
            'leaveType': leave['leave_type'] ?? '',
            'startDate': leave['start_date'],
            'endDate': leave['end_date'],
            'status': leave['status'] ?? 'Pending',
            'daysRequested': daysRequested,
            'submittedDate': leave['applied_on'] ?? '',
            'department': leave['department'] ?? '',
            'paidStatus': leave['paid_status'] ?? 'Paid',
          };
        }).toList();
        
        setState(() => _leaves = List<Map<String, dynamic>>.from(filteredLeaves));
      }
    } catch (e) {
      print('Error fetching leaves: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getRemainingLeaves() {
    final approvedLeaves = _leaves.where((l) => 
      l['status'].toString().toLowerCase() == 'approved'
    );
    
    final totalUsed = approvedLeaves.fold<int>(0, (sum, leave) => 
      sum + (leave['daysRequested'] as int)
    );
    
    return 15 - totalUsed;
  }

  Future<void> _submitLeaveRequest() async {
    if (_reason.isEmpty || _startDate == null || _endDate == null || _leaveType.isEmpty) {
      _showDialog('Please fill all fields');
      return;
    }
    
    if (_startDate!.isAfter(_endDate!)) {
      _showDialog('End date cannot be before start date');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appliedOnDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Calculate total approved leaves for current year
      final currentYear = DateTime.now().year;
      final approvedLeaves = _leaves.where((leave) {
        final leaveYear = DateTime.parse(leave['startDate'] as String).year;
        return leave['status'] == 'Approved' && leaveYear == currentYear;
      });
      
      final totalApprovedDays = approvedLeaves.fold<int>(0, (sum, leave) => 
        sum + (leave['daysRequested'] as int)
      );
      
      // Calculate days for current request
      final requestedDays = _endDate!.difference(_startDate!).inDays + 1;
      
      // Determine paid/unpaid status
      final paidStatus = (totalApprovedDays + requestedDays) > 15 ? 'Unpaid' : 'Paid';
      
      final payload = {
        'email': _userEmail,
        'department': _userDepartment,
        'leave_type': _leaveType,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'reason': _reason,
        'status': 'Pending',
        'paid_status': paidStatus,
        'applied_on': appliedOnDate,
      };

      final response = await _apiService.post('/accounts/apply_leave/', payload);

      if (response['success']) {
        _showDialog('Leave request submitted successfully!');
        
        // Clear form
        setState(() {
          _reason = '';
          _leaveType = '';
          _startDate = null;
          _endDate = null;
        });
        
        // Refresh leaves
        _fetchLeaves();
      } else {
        final error = response['error'] ?? 'Failed to submit leave request';
        if (error.toLowerCase().contains('overlapping') || 
            error.toLowerCase().contains('already have a leave')) {
          _showDialog('You already have a leave during these dates. Please pick a different range.');
        } else {
          _showDialog('Failed to submit leave request. Please try again.');
        }
      }
    } catch (e) {
      print('Error submitting leave: $e');
      _showDialog('Failed to submit leave request. Please try again.');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return '✓';
      case 'rejected':
        return '✗';
      default:
        return '⏳';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeaves,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Leave Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Request and track your time off',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Leave Balance
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Annual Leave Balance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You have a total of 15 paid leaves per year.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_getRemainingLeaves()} days remaining',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Add Leave Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('📋', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'New Leave Request',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Reason Dropdown
                    const Text('Reason', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _reason.isEmpty ? null : _reason,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      hint: const Text('Select a reason'),
                      items: const [
                        DropdownMenuItem(value: 'Vacation', child: Text('Vacation')),
                        DropdownMenuItem(value: 'Medical Appointment', child: Text('Medical Appointment')),
                        DropdownMenuItem(value: 'Personal Work', child: Text('Personal Work')),
                        DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _reason = value ?? '';
                          _leaveType = value?.toLowerCase().replaceAll(' ', '_') ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Range
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() => _startDate = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _startDate == null
                                            ? 'Select date'
                                            : DateFormat('MMM dd, yyyy').format(_startDate!),
                                        style: TextStyle(
                                          color: _startDate == null ? Colors.grey : Colors.black,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Date', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate ?? _startDate ?? DateTime.now(),
                                    firstDate: _startDate ?? DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() => _endDate = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _endDate == null
                                            ? 'Select date'
                                            : DateFormat('MMM dd, yyyy').format(_endDate!),
                                        style: TextStyle(
                                          color: _endDate == null ? Colors.grey : Colors.black,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Days count and Submit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startDate != null && _endDate != null
                              ? '${_endDate!.difference(_startDate!).inDays + 1} day(s)'
                              : '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitLeaveRequest,
                          icon: Text(_isSubmitting ? '⏳' : '+'),
                          label: Text(_isSubmitting ? 'Processing...' : 'Submit Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Leave History
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('📅', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'Leave History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _leaves.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      Text('📋', style: TextStyle(fontSize: 48)),
                                      SizedBox(height: 12),
                                      Text('No leave requests yet', style: TextStyle(color: Colors.grey)),
                                      SizedBox(height: 4),
                                      Text('Submit your first request above', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _leaves.length,
                                itemBuilder: (context, index) {
                                  final leave = _leaves[index];
                                  final status = leave['status'] as String;
                                  final statusColor = _getStatusColor(status);
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  leave['reason'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _getStatusIcon(status),
                                                      style: TextStyle(color: statusColor),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      status,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildLeaveDetail('Period', 
                                            '${DateFormat('MMM dd, yyyy').format(DateTime.parse(leave['startDate']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(leave['endDate']))}'),
                                          const SizedBox(height: 8),
                                          _buildLeaveDetail('Duration', '${leave['daysRequested']} day(s)'),
                                          const SizedBox(height: 8),
                                          _buildLeaveDetail('Submitted', 
                                            DateFormat('MMM dd, yyyy').format(DateTime.parse(leave['submittedDate']))),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
