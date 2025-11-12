import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'dart:ui';

class EmployeeTasksScreen extends StatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _tasks = [];
  String _filter = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';
      
      print('Fetching tasks for user: $_userEmail');
      
      final response = await _apiService.get('/accounts/list_tasks/');
      print('API Response: $response');
      
      if (response['success']) {
        final allTasks = response['data']['tasks'] as List? ?? [];
        print('Total tasks from API: ${allTasks.length}');
        
        // Debug: Print all task emails
        for (var t in allTasks) {
          print('Task email: ${t['email']}, User email: $_userEmail, Match: ${t['email'] == _userEmail}');
        }
        
        final tasks = allTasks
            .where((t) {
              final taskEmail = (t['email'] ?? '').toString().trim().toLowerCase();
              final userEmail = _userEmail.trim().toLowerCase();
              return taskEmail == userEmail;
            })
            .map((t) => <String, dynamic>{
              'task_id': t['task_id'],
              'title': t['title'],
              'description': t['description'],
              'email': t['email'],
              'assigned_by': t['assigned_by'],
              'priority': (t['priority'] ?? 'low').toString().toLowerCase(),
              'status': t['status'],
              'start_date': t['start_date'],
              'due_date': t['due_date'],
              'dueDate': t['due_date'] ?? '',
              'completed_date': t['completed_date'],
              'created_at': t['created_at'],
              'createdAt': t['created_at'] ?? '',
              'updated_at': t['updated_at'],
              'completed': (t['status'] ?? '').toString().toLowerCase() == 'completed',
            })
            .toList();
        
        print('Filtered tasks for user: ${tasks.length}');
        setState(() => _tasks = List<Map<String, dynamic>>.from(tasks));
      }
    } catch (e) {
      print('Error fetching tasks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    return _tasks.where((task) {
      final status = (task['status'] ?? '').toString().toLowerCase();
      final priority = task['priority'].toString().toLowerCase();
      
      if (_filter == 'pending' && status == 'completed') return false;
      if (_filter == 'completed' && status != 'completed') return false;
      if (_filter == 'high-priority' && priority != 'high') return false;
      
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (task['title'] ?? '').toString().toLowerCase().contains(query) ||
               (task['description'] ?? '').toString().toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  int get _pendingCount => _tasks.where((t) => !t['completed']).length;
  int get _highPriorityCount => _tasks.where((t) => 
    t['priority'].toString().toLowerCase() == 'high' && !t['completed']).length;
  int get _completedCount => _tasks.where((t) => t['completed']).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchTasks,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildFiltersAndSearch(),
            const SizedBox(height: 16),
            _buildTasksList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Task Management', 
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Stay organized and boost your productivity',
          style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Tasks', _tasks.length.toString(), '📋', Colors.blue),
        _buildStatCard('Pending', _pendingCount.toString(), '⏳', Colors.orange),
        _buildStatCard('High Priority', _highPriorityCount.toString(), '🔴', Colors.red),
        _buildStatCard('Completed', _completedCount.toString(), '✅', Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ],
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'All Tasks', '📝'),
              _buildFilterChip('pending', 'Pending', '⏳'),
              _buildFilterChip('completed', 'Completed', '✅'),
              _buildFilterChip('high-priority', 'High Priority', '🔴'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search tasks...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, String emoji) {
    final isSelected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: Colors.blue,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[700]),
      ),
    );
  }

  Widget _buildTasksList() {
    if (_filteredTasks.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('📋', style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text('No tasks found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final priority = task['priority'].toString().toLowerCase();
    final status = (task['status'] ?? 'pending').toString();
    final completed = task['completed'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTaskModal(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: priority == 'high' ? Colors.red : priority == 'medium' ? Colors.orange : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task['title'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: completed ? TextDecoration.lineThrough : null,
                        color: completed ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(task['description'] ?? '', 
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip(_formatDate(task['dueDate']), Colors.grey),
                  const SizedBox(width: 8),
                  _buildChip('${_getPriorityEmoji(priority)} ${priority.toUpperCase()}', 
                    priority == 'high' ? Colors.red : priority == 'medium' ? Colors.orange : Colors.green),
                  const SizedBox(width: 8),
                  _buildChip(status, _getStatusColor(status)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
      if (date.year == now.year && date.month == now.month && date.day == now.day + 1) return 'Tomorrow';
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getPriorityEmoji(String priority) {
    switch (priority) {
      case 'high': return '🔴';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'in progress': return Colors.blue;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  void _showTaskModal(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        onUpdate: _fetchTasks,
        apiService: _apiService,
        userEmail: _userEmail,
      ),
    );
  }
}

class TaskDetailDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onUpdate;
  final ApiService apiService;
  final String userEmail;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.onUpdate,
    required this.apiService,
    required this.userEmail,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late String _selectedStatus;
  final _reportController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task['status'] ?? 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.indigo.shade600]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.task['title'] ?? '', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(widget.task['description'] ?? '', 
                          style: TextStyle(color: Colors.blue.shade100)),
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Pending', 'In Progress', 'Completed']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await widget.apiService.patch(
                          '/accounts/update_task/${widget.task['task_id']}/',
                          {'status': _selectedStatus},
                        );
                        widget.onUpdate();
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task updated successfully')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Update Status'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reportController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe your progress...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_reportController.text.trim().isEmpty) return;
                      try {
                        await widget.apiService.post('/accounts/create_report/', {
                          'title': widget.task['title'],
                          'date': DateTime.now().toIso8601String().split('T')[0],
                          'email': widget.userEmail,
                          'content': _reportController.text,
                          'description': widget.task['description'],
                        });
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted successfully')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
