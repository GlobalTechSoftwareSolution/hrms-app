import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class ManagerNoticeScreen extends StatefulWidget {
  const ManagerNoticeScreen({super.key});

  @override
  State<ManagerNoticeScreen> createState() => _ManagerNoticeScreenState();
}

class _ManagerNoticeScreenState extends State<ManagerNoticeScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _filteredNotices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';
      debugPrint('👤 Manager user email: $_userEmail');

      final response = await _apiService.get('/accounts/list_notices/');
      debugPrint('📥 Manager notices response: $response');

      // Manager sees notices where notice_to is null (for everyone) or matches their email
      final allNotices = (response['data']?['notices'] ?? response['notices'] ?? []) as List;
      debugPrint('📋 Total notices: ${allNotices.length}');

      final noticesList = allNotices
          .where((n) {
            final noticeTo = n['notice_to'];
            // Show if notice_to is null (for everyone)
            if (noticeTo == null || noticeTo.toString().isEmpty) {
              return true;
            }
            // Show if notice_to matches manager's email
            if (_userEmail.isNotEmpty &&
                noticeTo.toString().toLowerCase() == _userEmail.toLowerCase()) {
              return true;
            }
            return false;
          })
          .map<Map<String, dynamic>>((n) => {
                'id': n['id'],
                'title': n['title'],
                'message': n['message'],
                'email': n['email'],
                'notice_by': n['notice_by'],
                'notice_to': n['notice_to'],
                'posted_date': n['posted_date'],
                'important': n['important'],
                'attachment': n['attachment'],
                'category': n['category'] ?? 'General',
                'is_read': n['is_read'] ?? false,
              })
          .toList();

      setState(() {
        _notices = noticesList;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('❌ Error fetching manager notices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var result = List<Map<String, dynamic>>.from(_notices);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((n) =>
          (n['title'] ?? '').toString().toLowerCase().contains(q) ||
          (n['message'] ?? '').toString().toLowerCase().contains(q) ||
          (n['email'] ?? '').toString().toLowerCase().contains(q) ||
          (n['notice_by'] ?? '').toString().toLowerCase().contains(q)).toList();
    }

    if (_filter == 'important') {
      result = result.where((n) => n['important'] == true).toList();
    } else if (_filter == 'with-attachments') {
      result = result.where((n) => n['attachment'] != null).toList();
    } else if (_filter == 'unread') {
      result = result.where((n) => !(n['is_read'] ?? false)).toList();
    }

    setState(() => _filteredNotices = result);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      return DateFormat('MMM d, y, h:mm a').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'manager', child: _buildNoticeContent());
  }

  Widget _buildNoticeContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600;

    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 16),
                Text('Loading notices...'),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchNotices,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth > 600 ? 16 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildStatsCards(),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildSearchAndFilters(),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildNoticesList(),
                ],
              ),
            ),
          );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
            ),
            child: Icon(
              Icons.notifications_active,
              size: isSmallScreen ? 16 : 20,
              color: Colors.blue.shade600,
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notices',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Stay updated with important announcements',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotices,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final unreadCount = _notices.where((n) => !(n['is_read'] ?? false)).length;
    final importantCount = _notices.where((n) => n['important'] == true).length;
    final withAttachmentsCount =
        _notices.where((n) => n['attachment'] != null).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Notices',
            _notices.length.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Unread',
            unreadCount.toString(),
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Important',
            importantCount.toString(),
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'With Files',
            withAttachmentsCount.toString(),
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search notices by title, message, sender...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', _filter == 'all', () {
                  setState(() {
                    _filter = 'all';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', _filter == 'unread', () {
                  setState(() {
                    _filter = 'unread';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Important', _filter == 'important', () {
                  setState(() {
                    _filter = 'important';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip('With Files', _filter == 'with-attachments', () {
                  setState(() {
                    _filter = 'with-attachments';
                    _applyFilters();
                  });
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesList() {
    if (_filteredNotices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.notifications_off,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No notices found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredNotices.length,
      itemBuilder: (context, index) => _buildNoticeCard(_filteredNotices[index]),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final isImportant = notice['important'] == true;
    final isRead = notice['is_read'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isImportant ? Border.all(color: Colors.red, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showNoticeDialog(notice),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isImportant)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'IMPORTANT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isImportant) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (notice['attachment'] != null)
                  const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice['message'] ?? '',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From: ${notice['notice_by'] ?? notice['email'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notice['notice_to'] != null)
                        Text(
                          'To: ${notice['notice_to']}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(notice['posted_date']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDialog(Map<String, dynamic> notice) {
    // Mark as read
    final index = _notices.indexWhere((n) => n['id'] == notice['id']);
    if (index != -1 && !(_notices[index]['is_read'] ?? false)) {
      setState(() {
        _notices[index]['is_read'] = true;
        _applyFilters();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        notice['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice['important'] == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.priority_high,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Important Notice',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From: ${notice['notice_by'] ?? notice['email'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (notice['notice_to'] != null)
                              Text(
                                'To: ${notice['notice_to']}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            Text(
                              'Posted: ${_formatDate(notice['posted_date'])}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Message:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notice['message'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      if (notice['attachment'] != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Attachment:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notice['attachment'],
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

