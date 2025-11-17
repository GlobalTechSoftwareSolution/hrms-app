import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class EmployeeNoticeScreen extends StatefulWidget {
  const EmployeeNoticeScreen({super.key});

  @override
  State<EmployeeNoticeScreen> createState() => _EmployeeNoticeScreenState();
}

class _EmployeeNoticeScreenState extends State<EmployeeNoticeScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _filteredNotices = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all';
  bool _showUnreadOnly = false;
  String _viewMode = 'list';

  Set<int> _bookmarkedNotices = {};
  Set<int> _readNotices = {};
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadReadNotices();
    _fetchNotices();
  }

  Future<void> _loadReadNotices() async {
    final prefs = await SharedPreferences.getInstance();
    final readNoticesStr = prefs.getString('read_notices') ?? '[]';
    try {
      final readList = readNoticesStr
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => int.parse(s.trim()))
          .toList();
      setState(() => _readNotices = Set<int>.from(readList));
    } catch (e) {
      print('Error loading read notices: $e');
    }
  }

  Future<void> _saveReadNotices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read_notices', _readNotices.toList().toString());
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';
      debugPrint('👤 User email: $_userEmail');

      final response = await _apiService.get('/accounts/list_notices/');
      debugPrint('📥 Raw response: $response');

      if (_userEmail.isEmpty) {
        debugPrint('⚠️ No user_email in SharedPreferences, cannot filter notices');
      }

      // Handle both old and new API structures
      final dynamicRaw = response['data']?['notices'] ?? response['notices'] ?? [];
      final allNotices = List<Map<String, dynamic>>.from(
        (dynamicRaw as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      debugPrint('📋 Total notices from API: ${allNotices.length}');

      // Match web logic: only notices whose notice_to.toString() == user_email
      final noticesList = allNotices
          .where((n) {
            final noticeTo = n['notice_to'];
            final noticeToStr = noticeTo?.toString() ?? '';
            final matches =
                _userEmail.isNotEmpty && noticeToStr == _userEmail;
            debugPrint(
              'Notice ${n['id']}: notice_to=$noticeToStr, user=$_userEmail, matches=$matches',
            );
            return matches;
          })
          .map<Map<String, dynamic>>(
            (n) => {
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
              'is_read': _readNotices.contains(n['id'] as int),
            },
          )
          .toList();

      debugPrint('✅ Filtered notices: ${noticesList.length}');

      setState(() {
        _notices = noticesList;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('❌ Error fetching notices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    debugPrint('🔍 Applying filters - Total notices: ${_notices.length}');
    var result = List<Map<String, dynamic>>.from(_notices);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (n) =>
                (n['title'] ?? '').toString().toLowerCase().contains(q) ||
                (n['message'] ?? '').toString().toLowerCase().contains(q) ||
                (n['email'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
      debugPrint('After search filter: ${result.length}');
    }

    if (_showUnreadOnly) {
      result = result.where((n) => !(n['is_read'] as bool)).toList();
      debugPrint('After unread filter: ${result.length}');
    }

    if (_filter == 'important') {
      result = result.where((n) => n['important'] == true).toList();
      debugPrint('After important filter: ${result.length}');
    } else if (_filter == 'with-attachments') {
      result = result.where((n) => n['attachment'] != null).toList();
      debugPrint('After attachments filter: ${result.length}');
    }

    debugPrint('✨ Final filtered notices: ${result.length}');
    setState(() => _filteredNotices = result);
  }

  void _markAsRead(int noticeId) {
    _readNotices.add(noticeId);
    _saveReadNotices();

    for (var i = 0; i < _notices.length; i++) {
      if (_notices[i]['id'] == noticeId) _notices[i]['is_read'] = true;
    }
    for (var i = 0; i < _filteredNotices.length; i++) {
      if (_filteredNotices[i]['id'] == noticeId)
        _filteredNotices[i]['is_read'] = true;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var notice in _notices) {
        _readNotices.add(notice['id'] as int);
        notice['is_read'] = true;
      }
      _saveReadNotices();
      _applyFilters();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      return DateFormat('MMM d, y, h:mm a').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  int get _unreadCount => _notices.where((n) => !(n['is_read'] as bool)).length;
  int get _importantCount =>
      _notices.where((n) => n['important'] == true).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Loading notices...'),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      child: RefreshIndicator(
        onRefresh: _fetchNotices,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildStatsCards(),
              const SizedBox(height: 12),
              _buildSearchAndFilters(),
              const SizedBox(height: 12),
              _buildNoticesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
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
                  size: isSmallScreen ? 20 : 24,
                  color: Colors.blue.shade600,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Notices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stay updated with important announcements and updates',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_unreadCount > 0)
              ElevatedButton(
                onPressed: _markAllAsRead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Mark All as Read'),
              ),
            OutlinedButton(
              onPressed: () => setState(
                () => _viewMode = _viewMode == 'list' ? 'grid' : 'list',
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_viewMode == 'list' ? 'Grid View' : 'List View'),
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
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Unread',
            _unreadCount.toString(),
            Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Important',
            _importantCount.toString(),
            Colors.red,
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
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search notices...',
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
                _buildFilterChip('Unread', _showUnreadOnly, () {
                  setState(() {
                    _showUnreadOnly = !_showUnreadOnly;
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'All',
                  _filter == 'all',
                  () => setState(() {
                    _filter = 'all';
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Important',
                  _filter == 'important',
                  () => setState(() {
                    _filter = 'important';
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Files',
                  _filter == 'with-attachments',
                  () => setState(() {
                    _filter = 'with-attachments';
                    _applyFilters();
                  }),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(8),
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
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade500),
              const SizedBox(height: 16),
              const Text(
                'No matching notices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _viewMode == 'list' ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: _viewMode == 'list' ? 3.8 : 1.0,
      ),
      itemCount: _filteredNotices.length,
      itemBuilder: (context, index) =>
          _buildNoticeCard(_filteredNotices[index]),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final isRead = notice['is_read'] as bool;
    final isImportant = notice['important'] == true;
    final isBookmarked = _bookmarkedNotices.contains(notice['id']);

    return InkWell(
      onTap: () {
        if (!isRead) {
          setState(() => _markAsRead(notice['id'] as int));
        }
        _showNoticeDialog(notice);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isImportant)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notice['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setState(
                    () => isBookmarked
                        ? _bookmarkedNotices.remove(notice['id'])
                        : _bookmarkedNotices.add(notice['id'] as int),
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.red : Colors.black,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice['message'] ?? '',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(notice['posted_date']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (!isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Unread',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDialog(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
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
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
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
                      // Important badge
                      if (notice['important'] == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Important',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Posted by and date
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Posted by: ${notice['notice_by'] ?? notice['email'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Posted on: ${_formatDate(notice['posted_date'])}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Message
                      const Text(
                        'Message:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice['message'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      if (notice['attachment'] != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Attachment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
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

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final toCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Notice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: toCtrl,
                decoration: InputDecoration(
                  labelText: 'Notice To',
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _apiService.post('/accounts/create_notice/', {
                          'title': titleCtrl.text,
                          'message': msgCtrl.text,
                          'email': _userEmail,
                          'notice_by': _userEmail,
                          'notice_to': toCtrl.text,
                          'posted_date': DateTime.now().toIso8601String(),
                          'important': false,
                          'category': 'General',
                        });
                        Navigator.pop(ctx);
                        _fetchNotices();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notice created')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
