import 'package:flutter/material.dart';
import '../../models/user_approval_model.dart';
import '../../services/approval_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<UserApproval> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _approvalService.fetchUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleApprove(String email) async {
    try {
      await _approvalService.approveUser(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $email approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(String email) async {
    try {
      await _approvalService.rejectUser(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $email rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<UserApproval> get _pendingUsers =>
      _users.where((user) => !user.isStaff).toList();

  List<UserApproval> get _approvedUsers =>
      _users.where((user) => user.isStaff).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _users.isEmpty
                  ? const Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUsers,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pending Approval Section
                            _buildSectionHeader(
                              'Pending Approval',
                              Colors.orange.shade700,
                              Icons.pending_actions,
                            ),
                            const SizedBox(height: 16),
                            _pendingUsers.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No users pending approval',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : _buildUserGrid(_pendingUsers, isPending: true),
                            const SizedBox(height: 32),

                            // Approved Users Section
                            _buildSectionHeader(
                              'Approved Users',
                              Colors.green.shade700,
                              Icons.check_circle,
                            ),
                            const SizedBox(height: 16),
                            _approvedUsers.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No approved users',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : _buildUserGrid(_approvedUsers, isPending: false),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildUserGrid(List<UserApproval> users, {required bool isPending}) {
    // Calculate responsive columns
    int crossAxisCount = 1;
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      crossAxisCount = 4;
    } else if (width > 900) {
      crossAxisCount = 3;
    } else if (width > 600) {
      crossAxisCount = 2;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: users.map((user) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - (16 * (crossAxisCount + 1))) / crossAxisCount,
          child: _buildUserCard(user, isPending: isPending),
        );
      }).toList(),
    );
  }

  Widget _buildUserCard(UserApproval user, {required bool isPending}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.email,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // User Details
            _buildDetailRow('Role', user.role),
            _buildDetailRow('Staff', user.isStaff ? 'Yes' : 'No'),
            _buildDetailRow('Superuser', user.isSuperuser ? 'Yes' : 'No'),
            _buildDetailRow('Active', user.isActive ? 'Yes' : 'No'),

            // Action Buttons (only for pending users)
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(user.email),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleReject(user.email),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
