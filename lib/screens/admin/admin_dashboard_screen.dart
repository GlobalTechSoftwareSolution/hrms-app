import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../services/approval_service.dart';
import 'admin_approval_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApprovalService _approvalService = ApprovalService();
  int _pendingApprovals = 0;
  int _totalUsers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApprovalData();
  }

  Future<void> _loadApprovalData() async {
    setState(() => _isLoading = true);
    
    try {
      final users = await _approvalService.fetchUsers();
      if (mounted) {
        setState(() {
          _pendingApprovals = users.where((u) => !u.isStaff).length;
          _totalUsers = users.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'admin',
      child: RefreshIndicator(
        onRefresh: _loadApprovalData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                      'Pending Approvals',
                      _pendingApprovals.toString(),
                      Icons.pending_actions,
                      Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminApprovalScreen(),
                          ),
                        ).then((_) => _loadApprovalData());
                      },
                    ),
                    _buildStatCard(
                      'Total Users',
                      _totalUsers.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
