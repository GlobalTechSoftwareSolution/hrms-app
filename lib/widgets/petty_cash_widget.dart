import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/petty_cash_model.dart';
import '../services/petty_cash_service.dart';

class PettyCashWidget extends StatefulWidget {
  final bool showCreateButton;
  final String? userRole; // To determine permissions

  const PettyCashWidget({
    super.key,
    this.showCreateButton = true,
    this.userRole,
  });

  @override
  State<PettyCashWidget> createState() => _PettyCashWidgetState();
}

class _PettyCashWidgetState extends State<PettyCashWidget> {
  final PettyCashService _pettyCashService = PettyCashService();

  List<PettyCashTransaction> transactions = [];
  PettyCashMonthlyFund? monthlyFund;
  bool isLoading = false;
  String searchTerm = '';
  String statusFilter = 'all';
  String categoryFilter = 'all';
  String typeFilter = 'all';
  bool showFilters = false;
  String? _userEmail;
  String? _userRole;
  DateTime selectedMonth = DateTime.now(); // Default to current month

  // Form controllers
  final TextEditingController dateController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  String selectedCategory = 'Office Supplies';
  String selectedType = 'debit';

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _fetchTransactions();

    // Initialize date to today
    dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    dateController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_info');

      if (userInfoString != null) {
        final userInfo = jsonDecode(userInfoString);
        setState(() {
          _userEmail = userInfo['email']?.toString().toLowerCase();
          _userRole =
              widget.userRole ??
              userInfo['role']?.toString().toLowerCase() ??
              'employee';
        });
      }
    } catch (e) {
      print('Error initializing user data: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      print('💰 Fetching petty cash transactions...');
      final fetchedTransactions = await _pettyCashService
          .fetchPettyCashTransactions();

      if (!mounted) return;

      setState(() {
        transactions = fetchedTransactions;
        isLoading = false;
      });

      // Calculate monthly fund for selected month
      try {
        final fund = await _pettyCashService.getMonthlyFundSummary(
          selectedMonth.month,
          selectedMonth.year,
        );
        if (mounted) {
          setState(() => monthlyFund = fund);
        }
      } catch (e) {
        print('Error calculating monthly fund: $e');
      }

      print(
        '✅ Petty cash fetch successful: ${transactions.length} transactions',
      );
    } catch (e) {
      print('❌ Petty cash fetch error: $e');
      if (!mounted) return;

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching petty cash: $e')),
        );
      }
    }
  }

  Future<void> _updateMonthlyStats() async {
    try {
      final fund = await _pettyCashService.getMonthlyFundSummary(
        selectedMonth.month,
        selectedMonth.year,
      );
      if (mounted) {
        setState(() => monthlyFund = fund);
      }
    } catch (e) {
      print('Error calculating monthly fund: $e');
    }
  }

  List<PettyCashTransaction> get _filteredTransactions {
    return transactions.where((transaction) {
      // Month filter - only show current month transactions by default
      final matchesMonth =
          transaction.date.month == selectedMonth.month &&
          transaction.date.year == selectedMonth.year;

      // Search filter
      final matchesSearch =
          searchTerm.isEmpty ||
          transaction.description.toLowerCase().contains(
            searchTerm.toLowerCase(),
          ) ||
          (transaction.voucherNo?.toLowerCase().contains(
                searchTerm.toLowerCase(),
              ) ??
              false) ||
          transaction.email.toLowerCase().contains(searchTerm.toLowerCase());

      // Status filter
      final matchesStatus =
          statusFilter == 'all' || transaction.status == statusFilter;

      // Category filter
      final matchesCategory =
          categoryFilter == 'all' || transaction.category == categoryFilter;

      // Type filter
      final matchesType =
          typeFilter == 'all' ||
          transaction.transactionType.toLowerCase() == typeFilter;

      return matchesMonth &&
          matchesSearch &&
          matchesStatus &&
          matchesCategory &&
          matchesType;
    }).toList();
  }

  Future<void> _createTransaction() async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    if (descriptionController.text.isEmpty || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      await _pettyCashService.createPettyCashTransaction(
        email: _userEmail!,
        date: DateTime.parse(dateController.text),
        description: descriptionController.text,
        category: selectedCategory,
        transactionType: selectedType == 'credit' ? 'Credit' : 'Debit',
        amount: amountController.text,
        remarks: remarksController.text.isNotEmpty
            ? remarksController.text
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        _clearForm();
        _fetchTransactions();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Petty cash transaction created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating transaction: $e')),
        );
      }
    }
  }

  Future<void> _approveTransaction(PettyCashTransaction transaction) async {
    if (_userEmail == null) return;

    try {
      await _pettyCashService.approvePettyCashTransaction(
        transaction.id,
        _userEmail!,
      );

      if (mounted) {
        _fetchTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving transaction: $e')),
        );
      }
    }
  }

  Future<void> _rejectTransaction(
    PettyCashTransaction transaction,
    String reason,
  ) async {
    if (_userEmail == null) return;

    try {
      await _pettyCashService.rejectPettyCashTransaction(
        transaction.id,
        _userEmail!,
        reason,
      );

      if (mounted) {
        _fetchTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting transaction: $e')),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final csvContent = await _pettyCashService.exportToCSV(
        _filteredTransactions,
      );

      // Create filename with current month and timestamp
      final monthName = DateFormat('MMMM_yyyy').format(selectedMonth);
      final timestamp = DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now());
      final fileName = 'petty_cash_${monthName}_${timestamp}.csv';

      // For mobile, we'll share the file using share_plus
      // This allows the user to save it to their preferred location
      await _shareCSVFile(csvContent, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareCSVFile(String csvContent, String fileName) async {
    try {
      // Convert string to Uint8List for sharing
      final bytes = Uint8List.fromList(csvContent.codeUnits);

      // Create a temporary file in the app's temp directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Petty Cash Transactions Export',
        subject:
            'Petty Cash CSV Export - ${DateFormat('MMMM yyyy').format(selectedMonth)}',
      );
    } catch (e) {
      // Fallback: if sharing fails, show the content in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('CSV Export - $fileName'),
            content: SingleChildScrollView(child: SelectableText(csvContent)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _clearForm() {
    dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    descriptionController.clear();
    amountController.clear();
    remarksController.clear();
    selectedCategory = 'Office Supplies';
    selectedType = 'debit';
  }

  bool _canApprove() {
    return ['admin', 'hr', 'manager', 'ceo'].contains(_userRole?.toLowerCase());
  }

  Widget _buildStatsCard() {
    final fund = monthlyFund;
    if (fund == null) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fund.month} ${fund.year}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Allocated',
                    currencyFormat.format(fund.allocatedAmount),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Spent',
                    currencyFormat.format(fund.spentAmount),
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Balance',
                    currencyFormat.format(fund.remainingAmount),
                    fund.remainingAmount >= 0 ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filteredTransactions;

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
          onRefresh: _fetchTransactions,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add Transaction Button
                if (widget.showCreateButton)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateTransactionDialog(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (widget.showCreateButton) const SizedBox(height: 16),

                // Monthly Fund Stats
                _buildStatsCard(),
                const SizedBox(height: 16),

                // Month Selector
                _buildMonthSelector(),
                const SizedBox(height: 16),

                // Search and Filters
                _buildSearchAndFilters(),
                const SizedBox(height: 16),

                // Export Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportToCSV,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transactions List
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (filteredTransactions.isEmpty)
                  _buildEmptyState()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionCard(filteredTransactions[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Month',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Previous Month Button
                IconButton(
                  onPressed: () async {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month - 1,
                        1,
                      );
                    });
                    await _updateMonthlyStats();
                  },
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                // Current Month Display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Next Month Button
                IconButton(
                  onPressed: () async {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month + 1,
                        1,
                      );
                    });
                    await _updateMonthlyStats();
                  },
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ],
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
                      hintText: 'Search transactions...',
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
                      value: statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => statusFilter = value ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: typeFilter,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Types'),
                        ),
                        DropdownMenuItem(
                          value: 'credit',
                          child: Text('Credit'),
                        ),
                        DropdownMenuItem(value: 'debit', child: Text('Debit')),
                      ],
                      onChanged: (value) =>
                          setState(() => typeFilter = value ?? 'all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: categoryFilter,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Categories'),
                  ),
                  ..._getCategories().map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => categoryFilter = value ?? 'all'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(PettyCashTransaction transaction) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final isMyTransaction =
        transaction.email.toLowerCase() == (_userEmail ?? '');
    final canApproveThis = _canApprove() && transaction.status == 'pending';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTransactionDetailsDialog(transaction),
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
                      transaction.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(transaction.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(transaction.date),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    transaction.category,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${transaction.transactionType}: ${currencyFormat.format(double.tryParse(transaction.amount) ?? 0)}',
                      style: TextStyle(
                        color: transaction.transactionType == 'Credit'
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (canApproveThis) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _approveTransaction(transaction),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              if (transaction.remarks != null &&
                  transaction.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Remarks: ${transaction.remarks}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    transaction.email.split('@')[0],
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (transaction.voucherNo != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.receipt, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      transaction.voucherNo!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
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
            status.toUpperCase(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or add a new transaction',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getCategories() {
    return [
      'Office Supplies',
      'Travel',
      'Utilities',
      'Maintenance',
      'Refreshments',
      'Miscellaneous',
      'Monthly Fund',
      'Salary Advance',
      'Emergency',
    ];
  }

  void _showCreateTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Petty Cash Transaction'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _getCategories()
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedCategory = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'credit',
                        child: Text('Credit (Money In)'),
                      ),
                      DropdownMenuItem(
                        value: 'debit',
                        child: Text('Debit (Money Out)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedType = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _createTransaction,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailsDialog(PettyCashTransaction transaction) {
    final canApproveThis = _canApprove() && transaction.status == 'pending';
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaction.description),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Date',
                DateFormat('dd/MM/yyyy').format(transaction.date),
              ),
              _buildDetailRow('Category', transaction.category),
              _buildDetailRow('Type', transaction.transactionType),
              _buildDetailRow(
                'Amount',
                currencyFormat.format(double.tryParse(transaction.amount) ?? 0),
              ),
              _buildDetailRow('Status', transaction.status.toUpperCase()),
              if (transaction.voucherNo != null)
                _buildDetailRow('Voucher No', transaction.voucherNo!),
              _buildDetailRow('Email', transaction.email),
              if (transaction.remarks != null &&
                  transaction.remarks!.isNotEmpty)
                _buildDetailRow('Remarks', transaction.remarks!),
              if (transaction.approvedAt != null)
                _buildDetailRow(
                  'Approved At',
                  DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(transaction.approvedAt!),
                ),
              if (transaction.approvedBy != null)
                _buildDetailRow('Approved By', transaction.approvedBy!),
              _buildDetailRow(
                'Created',
                DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt),
              ),
              _buildDetailRow(
                'Updated',
                DateFormat('dd/MM/yyyy HH:mm').format(transaction.updatedAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (canApproveThis) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showRejectDialog(transaction);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _approveTransaction(transaction);
              },
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(PettyCashTransaction transaction) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              _rejectTransaction(transaction, reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
