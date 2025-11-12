import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

class TicketWidget extends StatefulWidget {
  final bool showCreateButton;

  const TicketWidget({super.key, this.showCreateButton = true});

  @override
  State<TicketWidget> createState() => _TicketWidgetState();
}

class _TicketWidgetState extends State<TicketWidget> {
  final TicketService _ticketService = TicketService();

  Map<String, List<Ticket>> tickets = {
    'assignedToMe': [],
    'raisedByMe': [],
    'closedByMe': [],
    'allTickets': [],
  };

  bool isLoading = false;
  String searchTerm = '';
  String statusFilter = '';
  String priorityFilter = '';
  bool showFilters = false;
  String activeSection = 'all';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final categorizedTickets = await _ticketService.fetchCategorizedTickets();
      if (!mounted) return;

      setState(() {
        tickets = categorizedTickets;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching tickets: $e')));
      }
    }
  }

  List<Ticket> _getCurrentTickets() {
    List<Ticket> currentTickets;
    switch (activeSection) {
      case 'assigned':
        currentTickets = tickets['assignedToMe']!;
        break;
      case 'raised':
        currentTickets = tickets['raisedByMe']!;
        break;
      case 'closed':
        currentTickets = tickets['closedByMe']!;
        break;
      default:
        currentTickets = tickets['allTickets']!;
    }

    return currentTickets.where((ticket) {
      final matchesSearch =
          searchTerm.isEmpty ||
          ticket.subject.toLowerCase().contains(searchTerm.toLowerCase()) ||
          ticket.description.toLowerCase().contains(searchTerm.toLowerCase());
      final matchesStatus =
          statusFilter.isEmpty ||
          ticket.status.toLowerCase() == statusFilter.toLowerCase();
      final matchesPriority =
          priorityFilter.isEmpty ||
          ticket.priority.toLowerCase() == priorityFilter.toLowerCase();
      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentTickets = _getCurrentTickets();
    final stats = {
      'total': tickets['allTickets']!.length,
      'assigned': tickets['assignedToMe']!.length,
      'raised': tickets['raisedByMe']!.length,
      'closed': tickets['closedByMe']!
          .where((t) => t.status == 'closed')
          .length,
      'open': tickets['allTickets']!.where((t) => t.status == 'open').length,
      'inProgress': tickets['allTickets']!
          .where((t) => t.status == 'in-progress')
          .length,
    };

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade50, Colors.blue.shade50],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchTickets,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Create Button
                    if (widget.showCreateButton)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showCreateTicketDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Ticket'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (widget.showCreateButton) const SizedBox(height: 16),

                    // Stats Dashboard
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _buildStatCard(
                          'Total',
                          stats['total']!,
                          Icons.mail,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Open',
                          stats['open']!,
                          Icons.error_outline,
                          Colors.red,
                        ),
                        _buildStatCard(
                          'In Progress',
                          stats['inProgress']!,
                          Icons.access_time,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Assigned',
                          stats['assigned']!,
                          Icons.person,
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Search and Filters
                    _buildSearchAndFilters(),
                    const SizedBox(height: 16),

                    // Section Tabs
                    _buildSectionTabs(),
                    const SizedBox(height: 16),

                    // Tickets List
                    currentTickets.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentTickets.length,
                            itemBuilder: (context, index) {
                              return _buildTicketCard(currentTickets[index]);
                            },
                          ),
                  ],
                ),
              ),
              // Subtle loading indicator at top
              if (isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tickets...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => setState(() => searchTerm = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: showFilters ? Colors.blue : null,
                  ),
                  onPressed: () => setState(() => showFilters = !showFilters),
                ),
              ],
            ),
            if (showFilters) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: statusFilter.isEmpty ? null : statusFilter,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All')),
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'in-progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => statusFilter = value ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: priorityFilter.isEmpty ? null : priorityFilter,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => priorityFilter = value ?? ''),
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

  Widget _buildSectionTabs() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildTab('All', 'all', tickets['allTickets']!.length),
            _buildTab('Assigned', 'assigned', tickets['assignedToMe']!.length),
            _buildTab('Raised', 'raised', tickets['raisedByMe']!.length),
            _buildTab('Closed', 'closed', tickets['closedByMe']!.length),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String section, int count) {
    final isActive = activeSection == section;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => activeSection = section),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade700,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '($count)',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTicketDetailsDialog(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _getStatusBadge(ticket.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _getPriorityBadge(ticket.priority),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          ticket.assignedBy ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(ticket.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or create a new ticket',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'open':
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      case 'in-progress':
        color = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'closed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase().replaceAll('-', ' '),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'low':
        color = Colors.green;
        break;
      case 'medium':
        color = Colors.yellow.shade700;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'urgent':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('user_info');
    if (userInfoString != null) {
      final userInfo = jsonDecode(userInfoString);
      return userInfo['email']?.toString().toLowerCase();
    }
    return null;
  }

  Future<bool> _canUpdateTicket(Ticket ticket) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return false;

    // User can update if they are assigned to the ticket or raised the ticket
    return ticket.assignedTo?.toLowerCase() == userEmail ||
        ticket.assignedBy?.toLowerCase() == userEmail;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Cannot Update Ticket'),
          ],
        ),
        content: const Text(
          'This task is not assigned to you, so you cannot update it. Please contact your manager if you need to make changes.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCreateTicketDialog() {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'medium';
    String? assignedTo;
    List<Map<String, dynamic>> users = [];
    bool loadingUsers = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (loadingUsers) {
            _ticketService
                .fetchUsers()
                .then((fetchedUsers) {
                  setDialogState(() {
                    users = fetchedUsers;
                    loadingUsers = false;
                  });
                })
                .catchError((e) {
                  setDialogState(() => loadingUsers = false);
                });
          }

          return AlertDialog(
            title: const Text('Create New Ticket'),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => priority = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (loadingUsers)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: assignedTo,
                        decoration: const InputDecoration(
                          labelText: 'Assign To (Optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...users.map(
                            (user) => DropdownMenuItem(
                              value: user['email'],
                              child: Text(
                                user['fullname'] ?? user['email'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => assignedTo = value);
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (subjectController.text.isEmpty ||
                      descriptionController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                      ),
                    );
                    return;
                  }

                  // Check if user is trying to assign to themselves
                  final userEmail = await _getUserEmail();
                  if (assignedTo != null &&
                      userEmail != null &&
                      assignedTo?.toLowerCase() == userEmail.toLowerCase()) {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text('Cannot Self-Assign'),
                          ],
                        ),
                        content: const Text(
                          'You cannot assign a ticket to yourself. Please select another team member or leave it unassigned.',
                          style: TextStyle(fontSize: 15),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  try {
                    await _ticketService.createTicket(
                      subject: subjectController.text,
                      description: descriptionController.text,
                      priority: priority,
                      assignedTo: assignedTo,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchTickets();
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      
                      // Show user-friendly error dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text('Failed to Create Ticket'),
                            ],
                          ),
                          content: const Text(
                            'Unable to create the ticket. Please check your connection and try again.',
                            style: TextStyle(fontSize: 15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTicketDetailsDialog(Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket.subject),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(ticket.description),
              const SizedBox(height: 16),
              if (ticket.closedDescription != null) ...[
                const Text(
                  'Closure Notes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(ticket.closedDescription!),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _getStatusBadge(ticket.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Priority: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _getPriorityBadge(ticket.priority),
                ],
              ),
              const SizedBox(height: 8),
              Text('Raised By: ${ticket.assignedBy ?? "Unknown"}'),
              Text('Assigned To: ${ticket.assignedTo ?? "Unassigned"}'),
              Text(
                'Created: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt)}',
              ),
              Text(
                'Updated: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.updatedAt)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (ticket.status != 'closed')
            ElevatedButton(
              onPressed: () async {
                final canUpdate = await _canUpdateTicket(ticket);
                if (!canUpdate) {
                  Navigator.pop(context);
                  _showPermissionDeniedDialog();
                  return;
                }
                Navigator.pop(context);
                _showUpdateStatusDialog(ticket);
              },
              child: const Text('Update Status'),
            ),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(Ticket ticket) {
    String newStatus = ticket.status;
    final closureController = TextEditingController(
      text: ticket.closedDescription ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Ticket Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: newStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(
                    value: 'in-progress',
                    child: Text('In Progress'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (value) {
                  setDialogState(() => newStatus = value!);
                },
              ),
              if (newStatus == 'closed' || newStatus == 'in-progress') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: closureController,
                  decoration: InputDecoration(
                    labelText: newStatus == 'closed'
                        ? 'Closure Description *'
                        : 'Progress Description *',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if ((newStatus == 'closed' || newStatus == 'in-progress') &&
                    closureController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a description'),
                    ),
                  );
                  return;
                }

                try {
                  await _ticketService.updateTicketStatus(
                    ticketId: ticket.id,
                    newStatus: newStatus,
                    closedDescription: closureController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ticket updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchTickets();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);

                    // Check if it's a permission error
                    final errorMessage = e.toString().toLowerCase();
                    if (errorMessage.contains('permission') ||
                        errorMessage.contains('unauthorized') ||
                        errorMessage.contains('forbidden')) {
                      _showPermissionDeniedDialog();
                    } else {
                      // Show generic error dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text('Update Failed'),
                            ],
                          ),
                          content: Text(
                            'Unable to update ticket status. Please try again later.',
                            style: const TextStyle(fontSize: 15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
