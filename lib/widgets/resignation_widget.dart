import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/resignation_model.dart';
import '../services/resignation_service.dart';

class ResignationWidget extends StatefulWidget {
  const ResignationWidget({super.key});

  @override
  State<ResignationWidget> createState() => _ResignationWidgetState();
}

class _ResignationWidgetState extends State<ResignationWidget> {
  final ResignationService _resignationService = ResignationService();
  
  Map<String, String> employeeDetails = {};
  ResignationStatus? resignationStatus;
  bool isLoading = false;
  bool isSubmitting = false;
  String? error;
  
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      // Get user email from SharedPreferences
      final prefs = await _resignationService.getUserInfo();
      final email = prefs['email'];
      
      if (email == null || email.isEmpty) {
        throw Exception('User email not found');
      }

      // Fetch employee details
      final details = await _resignationService.fetchEmployeeDetails(email);
      
      // Fetch resignation status
      final status = await _resignationService.fetchResignationStatus(email);
      
      if (!mounted) return;
      setState(() {
        employeeDetails = details;
        resignationStatus = status;
        isLoading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _submitResignation() async {
    if (_reasonController.text.trim().isEmpty) {
      _showMessage('Please provide a reason for resignation', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => isSubmitting = true);

    try {
      final request = ResignationRequest(
        email: employeeDetails['email']!,
        fullname: employeeDetails['fullname']!,
        department: _departmentController.text.trim().isEmpty 
            ? employeeDetails['department'] 
            : _departmentController.text.trim(),
        designation: _designationController.text.trim().isEmpty 
            ? employeeDetails['designation'] 
            : _designationController.text.trim(),
        reasonForResignation: _reasonController.text.trim(),
      );

      await _resignationService.submitResignation(request);
      
      if (!mounted) return;
      setState(() => isSubmitting = false);
      
      _showMessage('Resignation submitted successfully!');
      _reasonController.clear();
      Navigator.pop(context); // Close dialog
      
      // Reload data
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      _showMessage('Failed to submit resignation: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isEmployeeInactive = employeeDetails.isEmpty ||
        (employeeDetails['fullname']?.isEmpty ?? true) ||
        (employeeDetails['email']?.isEmpty ?? true);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade50, Colors.red.shade50],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    _buildStatsCards(),
                    const SizedBox(height: 24),

                    // Error Message
                    if (error != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Error: $error',
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Main Content
                    if (isEmployeeInactive)
                      _buildInactiveEmployeeCard()
                    else
                      _buildResignationCard(),

                    const SizedBox(height: 24),

                    // Progress Tracker
                    if (!isEmployeeInactive && employeeDetails['email'] != null)
                      _buildProgressTracker(),
                  ],
                ),
              ),
              // Loading indicator
              if (isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final isActive = employeeDetails.isNotEmpty &&
        (employeeDetails['fullname']?.isNotEmpty ?? false);

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: isActive ? Colors.blue : Colors.red,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employment Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.grey.shade800 : Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'Currently employed'
                        : 'Contact HR for activation',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: Colors.green, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Department',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    employeeDetails['department'] ?? 'Not specified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInactiveEmployeeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Inactive Employee',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your employment details are not available in the system.\nPlease contact the HR department for assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResignationCard() {
    final hasPendingRequest = resignationStatus?.hasPendingRequest ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.exit_to_app, size: 32, color: Colors.red.shade600),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Resignation Request',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Submit your formal resignation request below to initiate the offboarding process.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Employee Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Full Name', employeeDetails['fullname'] ?? 'N/A'),
                  _buildDetailRow('Email', employeeDetails['email'] ?? 'N/A'),
                  _buildDetailRow('Department', employeeDetails['department'] ?? 'Not specified'),
                  _buildDetailRow('Designation', employeeDetails['designation'] ?? 'Not specified'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            if (hasPendingRequest)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have already submitted a resignation request. Please wait for approval.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _showResignationDialog(),
                icon: const Icon(Icons.warning_amber),
                label: const Text('Submit Resignation Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),

            const SizedBox(height: 24),

            // Important Notes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.yellow.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...[ 
                    'Resignation requests are subject to approval by HR',
                    'Standard notice period as per your contract will apply',
                    'You\'ll be contacted for exit formalities',
                    'All company property must be returned before settlement',
                  ].map((text) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.yellow.shade700)),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.yellow.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: BorderSide(color: Colors.blue.shade500, width: 3),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'Resignation Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (resignationStatus == null)
              Text(
                'No resignation request found yet.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              )
            else
              _buildProgressSteps(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSteps() {
    final status = resignationStatus!;
    
    final steps = [
      {
        'label': 'Applied',
        'active': true,
        'rejected': false,
      },
      {
        'label': 'Manager',
        'active': status.isManagerApproved,
        'rejected': status.isManagerRejected,
      },
      {
        'label': 'HR',
        'active': status.isHrApproved,
        'rejected': status.isHrRejected,
      },
      {
        'label': 'Relieved',
        'active': status.isRelieved,
        'rejected': false,
      },
    ];

    return Column(
      children: [
        // Progress Steps
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildProgressStep(
                      label: step['label'] as String,
                      isActive: step['active'] as bool,
                      isRejected: step['rejected'] as bool,
                      stepNumber: index + 1,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      flex: 0,
                      child: Container(
                        width: 30,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 20),
                        color: step['active'] as bool
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        
        // Success Message
        if (status.isRelieved) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Text(
                  '🎉 Successfully Relieved!',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your offboarding process is complete. Best wishes!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressStep({
    required String label,
    required bool isActive,
    required bool isRejected,
    required int stepNumber,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isRejected
                ? Colors.red.shade500
                : isActive
                    ? Colors.green.shade500
                    : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: (isActive || isRejected)
                ? [
                    BoxShadow(
                      color: (isRejected ? Colors.red : Colors.green).withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              isRejected ? '✗' : isActive ? '✓' : stepNumber.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showResignationDialog() {
    // Initialize controllers with current values
    _departmentController.text = employeeDetails['department'] ?? '';
    _designationController.text = employeeDetails['designation'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade700],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resignation Form',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Review and confirm',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogField('Full Name', employeeDetails['fullname'] ?? '', readOnly: true),
                      _buildDialogField('Email', employeeDetails['email'] ?? '', readOnly: true),
                      _buildDialogFieldWithController('Department', _departmentController),
                      _buildDialogFieldWithController('Designation', _designationController),
                      const SizedBox(height: 12),
                      Text(
                        'Reason for Resignation *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        autofocus: true,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Please provide a detailed reason for your resignation...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This will be recorded in your profile',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _submitResignation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Submit Resignation'),
                      ),
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

  Widget _buildDialogFieldWithController(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, String value, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value),
            readOnly: readOnly,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: readOnly,
              fillColor: readOnly ? Colors.grey.shade100 : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
