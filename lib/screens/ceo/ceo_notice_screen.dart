import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class CeoNoticeScreen extends StatefulWidget {
  const CeoNoticeScreen({super.key});

  @override
  State<CeoNoticeScreen> createState() => _CeoNoticeScreenState();
}

class _CeoNoticeScreenState extends State<CeoNoticeScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _filteredNotices = [];
  Map<String, dynamic>? _selectedNotice;
  bool _isLoading = true;
  String _searchTerm = '';
  String _filter = 'all'; // all, unread, important, with-attachments
  List<int> _bookmarkedNotices = [];
  String _viewMode = 'list'; // list, grid
  bool _showUnreadOnly = false;
  bool _showModal = false;

  // Form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noticeToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _noticeToController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);

    try {
      // Get current user's email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserEmail = prefs.getString('user_email') ?? '';

      debugPrint('Current user email: $currentUserEmail');

      // Fetch notices from API
      final response = await _apiService.get('/accounts/list_notices/');

      debugPrint('Notices Response: $response');

      if (response['success'] == true) {
        final data = response['data'];
        List<Map<String, dynamic>> allNotices = [];

        // Handle different response formats
        if (data is List) {
          allNotices = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['notices'] is List) {
          allNotices = (data['notices'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }

        // Filter notices: show only if notice_to is null (for everyone) or matches current user's email
        _notices = allNotices.where((notice) {
          final noticeTo = notice['notice_to'];

          // Show if notice_to is null (for everyone)
          if (noticeTo == null) {
            return true;
          }

          // Show if notice_to matches current user's email
          if (noticeTo is String &&
              noticeTo.toLowerCase() == currentUserEmail.toLowerCase()) {
            return true;
          }

          return false;
        }).toList();

        debugPrint(
          'Filtered ${_notices.length} notices for user $currentUserEmail',
        );

        _filteredNotices = List.from(_notices);
        _filterNotices();
      } else {
        _notices = [];
        debugPrint('Notices API failed: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Error fetching notices: $e');
      _notices = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterNotices() {
    List<Map<String, dynamic>> result = List.from(_notices);

    // Search filter
    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      result = result.where((notice) {
        return notice['title'].toString().toLowerCase().contains(term) ||
            notice['message'].toString().toLowerCase().contains(term) ||
            notice['email'].toString().toLowerCase().contains(term);
      }).toList();
    }

    // Unread only filter
    if (_showUnreadOnly) {
      result = result.where((notice) => !(notice['is_read'] ?? false)).toList();
    }

    // Category filter
    switch (_filter) {
      case 'unread':
        result = result
            .where((notice) => !(notice['is_read'] ?? false))
            .toList();
        break;
      case 'important':
        result = result
            .where((notice) => notice['important'] ?? false)
            .toList();
        break;
      case 'with-attachments':
        result = result
            .where((notice) => notice['attachment'] != null)
            .toList();
        break;
    }

    setState(() {
      _filteredNotices = result;
    });
  }

  void _handleNoticeSelect(Map<String, dynamic> notice) {
    setState(() {
      _selectedNotice = notice;

      // Mark as read
      if (!(notice['is_read'] ?? false)) {
        final index = _notices.indexWhere((n) => n['id'] == notice['id']);
        if (index != -1) {
          _notices[index]['is_read'] = true;
        }
        _filterNotices();
      }
    });
  }

  void _toggleBookmark(int noticeId) {
    setState(() {
      if (_bookmarkedNotices.contains(noticeId)) {
        _bookmarkedNotices.remove(noticeId);
      } else {
        _bookmarkedNotices.add(noticeId);
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notice in _notices) {
        notice['is_read'] = true;
      }
      _filterNotices();
    });
  }

  Future<void> _createNotice() async {
    if (_titleController.text.isEmpty ||
        _messageController.text.isEmpty ||
        _noticeToController.text.isEmpty) {
      return;
    }

    try {
      // Mock creation - replace with actual API call
      final newNotice = {
        'id': _notices.length + 1,
        'title': _titleController.text,
        'message': _messageController.text,
        'email': 'ceo@company.com', // Current user email
        'posted_date': DateTime.now().toIso8601String(),
        'valid_until': null,
        'important': false,
        'attachment': null,
        'category': 'General',
        'is_read': false,
        'notice_to': _noticeToController.text,
      };

      setState(() {
        _notices.insert(0, newNotice);
        _showModal = false;
        _titleController.clear();
        _messageController.clear();
        _noticeToController.clear();
      });

      _filterNotices();
    } catch (e) {
      print('Error creating notice: $e');
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int get _unreadCount =>
      _notices.where((notice) => !(notice['is_read'] ?? false)).length;
  int get _importantCount =>
      _notices.where((notice) => notice['important'] ?? false).length;

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'ceo', child: _buildNoticeContent());
  }

  Widget _buildNoticeContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStatsCards(),
              const SizedBox(height: 24),
              _buildSearchAndFilters(),
              const SizedBox(height: 24),
              _buildNoticesList(),
            ],
          ),
        ),
        if (_showModal) _buildCreateNoticeModal(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          children: [
            const Icon(Icons.notifications, size: 24, color: Colors.black),
            const SizedBox(width: 8),
            const Text(
              'Notices',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Stay updated with important announcements',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          children: [
            if (_unreadCount > 0)
              Expanded(
                child: ElevatedButton(
                  onPressed: _markAllAsRead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Mark All Read',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            if (_unreadCount > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _showModal = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Post Notice',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Notices',
            _notices.length.toString(),
            Colors.black,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Unread',
            _unreadCount.toString(),
            Colors.black,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Important',
            _importantCount.toString(),
            Colors.red.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
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
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
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
        border: Border.all(color: Colors.black, width: 1),
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
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search notices...',
              prefixIcon: const Icon(Icons.search, color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchTerm = value;
              });
              _filterNotices();
            },
          ),
          const SizedBox(height: 16),

          // Filter Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterButton('Unread Only', _showUnreadOnly, () {
                setState(() => _showUnreadOnly = !_showUnreadOnly);
                _filterNotices();
              }),
              _buildFilterButton('All', _filter == 'all', () {
                setState(() => _filter = 'all');
                _filterNotices();
              }),
              _buildFilterButton('Important', _filter == 'important', () {
                setState(() => _filter = 'important');
                _filterNotices();
              }),
              _buildFilterButton(
                'With Files',
                _filter == 'with-attachments',
                () {
                  setState(() => _filter = 'with-attachments');
                  _filterNotices();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_filteredNotices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'No matching notices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _filteredNotices
          .map((notice) => _buildNoticeCard(notice))
          .toList(),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final isSelected = _selectedNotice?['id'] == notice['id'];
    final isBookmarked = _bookmarkedNotices.contains(notice['id']);
    final isRead = notice['is_read'] ?? false;
    final isImportant = notice['important'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _handleNoticeSelect(notice),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade50 : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.black,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
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
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isImportant)
                          const Icon(Icons.error, color: Colors.red, size: 16),
                        if (isImportant) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            notice['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleBookmark(notice['id']),
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? Colors.red : Colors.black,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notice['message'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(notice['posted_date'] ?? ''),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  if (!isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Unread',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modal for creating new notice
  Widget _buildCreateNoticeModal() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () => setState(() => _showModal = false),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          // Modal
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Create New Notice',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _showModal = false),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noticeToController,
                      decoration: InputDecoration(
                        labelText: 'Notice To (Email)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _showModal = false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createNotice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
