import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class CeoFinanceScreen extends StatefulWidget {
  const CeoFinanceScreen({super.key});

  @override
  State<CeoFinanceScreen> createState() => _CeoFinanceScreenState();
}

class _CeoFinanceScreenState extends State<CeoFinanceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  TabController? _tabController;

  List<Map<String, dynamic>> _payrolls = [];
  List<Map<String, dynamic>> _filteredPayrolls = [];
  bool _isLoading = true;

  double _totalPayroll = 0;
  double _salaryCredited = 0;
  double _salaryPending = 0;
  int _totalEmployees = 0;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _fetchPayrollData();
  }

  void _initializeTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchPayrollData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch both payroll and employee data
      final payrollResponse = await _apiService.get('/accounts/list_payrolls/');
      final employeesResponse = await _apiService.get('/accounts/employees/');

      debugPrint('Payroll Response: $payrollResponse');
      debugPrint('Employees Response: $employeesResponse');

      List<Map<String, dynamic>> employees = [];

      // Extract employees data
      if (employeesResponse['success'] == true) {
        final empData = employeesResponse['data'];
        if (empData is List) {
          employees = empData.whereType<Map<String, dynamic>>().toList();
        } else if (empData is Map && empData['employees'] is List) {
          employees = (empData['employees'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      // Create a map for quick employee lookup by email
      final employeeMap = <String, Map<String, dynamic>>{};
      for (final emp in employees) {
        final email = (emp['email'] ?? emp['email_id'] ?? '')
            .toString()
            .toLowerCase();
        if (email.isNotEmpty) {
          employeeMap[email] = emp;
        }
      }

      if (payrollResponse['success'] == true) {
        final data = payrollResponse['data'];

        // Handle different response formats
        if (data is List) {
          _payrolls = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['payrolls'] is List) {
          _payrolls = (data['payrolls'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        } else {
          _payrolls = [];
        }

        // Merge employee data into payroll records
        _payrolls = _payrolls.map((payroll) {
          final email = (payroll['email'] ?? '').toString().toLowerCase();
          final employee = employeeMap[email];

          return {
            ...payroll,
            'name':
                employee?['fullname'] ??
                employee?['name'] ??
                email.split('@')[0],
            'department': employee?['department'] ?? 'N/A',
          };
        }).toList();

        debugPrint(
          'Loaded ${_payrolls.length} payroll records with employee data',
        );
        _calculateFinanceMetrics();
        _filterPayrollsByMonth();
      } else {
        _payrolls = [];
        debugPrint('Payroll API failed: ${payrollResponse['message']}');
      }
    } catch (e) {
      debugPrint('Error fetching payroll data: $e');
      _payrolls = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateFinanceMetrics() {
    // Calculate metrics only for the filtered month
    _totalPayroll = _filteredPayrolls.fold(0.0, (sum, payroll) {
      final salary = payroll['basic_salary'];
      if (salary is String) {
        return sum + (double.tryParse(salary) ?? 0.0);
      }
      return sum + ((salary as num?)?.toDouble() ?? 0.0);
    });

    // Count salaries that are either Credited or Paid (both are completed)
    _salaryCredited = _filteredPayrolls
        .where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();
          return status == 'credited' || status == 'paid';
        })
        .fold(0.0, (sum, payroll) {
          final salary = payroll['basic_salary'];
          if (salary is String) {
            return sum + (double.tryParse(salary) ?? 0.0);
          }
          return sum + ((salary as num?)?.toDouble() ?? 0.0);
        });

    _salaryPending = _totalPayroll - _salaryCredited;
    _totalEmployees = _filteredPayrolls.length;

    debugPrint(
      'Finance Metrics (Month $_selectedMonth/$_selectedYear): Total=$_totalPayroll, Credited=$_salaryCredited, Pending=$_salaryPending, Employees=$_totalEmployees',
    );
  }

  void _filterPayrollsByMonth() {
    _filteredPayrolls = _payrolls.where((payroll) {
      // Handle both formats: DateTime string and numeric month/year fields
      int payrollMonth = _selectedMonth;
      int payrollYear = _selectedYear;

      // Try to get month/year from payroll fields first
      if (payroll['month'] != null && payroll['year'] != null) {
        final monthVal = payroll['month'];
        final yearVal = payroll['year'];

        if (monthVal is String) {
          payrollMonth = int.tryParse(monthVal) ?? _selectedMonth;
        } else if (monthVal is int) {
          payrollMonth = monthVal;
        }

        if (yearVal is String) {
          payrollYear = int.tryParse(yearVal) ?? _selectedYear;
        } else if (yearVal is int) {
          payrollYear = yearVal;
        }
      } else if (payroll['pay_date'] != null) {
        // Fallback to parsing pay_date
        try {
          final payDate = DateTime.parse(payroll['pay_date']);
          payrollMonth = payDate.month;
          payrollYear = payDate.year;
        } catch (e) {
          debugPrint('Error parsing pay_date: $e');
          return false;
        }
      }

      return payrollYear == _selectedYear && payrollMonth == _selectedMonth;
    }).toList();

    // Recalculate metrics after filtering
    _calculateFinanceMetrics();

    debugPrint(
      'Filtered ${_filteredPayrolls.length} payrolls for month $_selectedMonth/$_selectedYear',
    );
  }

  String _formatCurrency(dynamic amount) {
    double numAmount = 0.0;

    if (amount is String) {
      numAmount = double.tryParse(amount) ?? 0.0;
    } else if (amount is num) {
      numAmount = amount.toDouble();
    }

    return '₹${numAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(dynamic dateStr) {
    try {
      if (dateStr == null) return 'N/A';
      final date = DateTime.parse(dateStr.toString());
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'N/A';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildMonthSelector() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Select Month & Year:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(months[index]),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                      _filterPayrollsByMonth();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year - index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value!;
                      _filterPayrollsByMonth();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'ceo', child: _buildFinanceContent());
  }

  Widget _buildFinanceContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple title
          const Text(
            'Finance Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Stats Cards Row - simple colors
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Payroll',
                  _formatCurrency(_totalPayroll),
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Salary Credited',
                  _formatCurrency(_salaryCredited),
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Salary Pending',
                  _formatCurrency(_salaryPending),
                  Icons.pending,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Employees',
                  _totalEmployees.toString(),
                  Icons.people,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Month Selection
          _buildMonthSelector(),

          const SizedBox(height: 20),

          // Selected Month Payroll Section
          _buildPayrollSection(
            '${_getMonthName(_selectedMonth)} $_selectedYear Payroll',
            _filteredPayrolls,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Icon(icon, color: Colors.grey.shade600, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSection(
    String title,
    List<Map<String, dynamic>> payrolls,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (payrolls.isEmpty)
              _buildEmptyState()
            else
              _buildPayrollList(payrolls),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No payroll records found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          Text(
            'Payroll data will appear here once available',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollList(List<Map<String, dynamic>> payrolls) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payrolls.length,
      itemBuilder: (context, index) {
        final payroll = payrolls[index];
        return _buildPayrollCard(payroll);
      },
    );
  }

  Widget _buildPayrollCard(Map<String, dynamic> payroll) {
    final status = (payroll['status'] as String?) ?? 'Unknown';
    final statusLower = status.toLowerCase();
    // Show green for both Credited and Paid, red for Pending
    final isCompleted = statusLower == 'credited' || statusLower == 'paid';
    final statusColor = isCompleted
        ? const Color(0xFF4CAF50) // Green for Credited/Paid
        : const Color(0xFFFF5722); // Red/Orange for Pending

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, statusColor.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor.withOpacity(0.8), statusColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  ((payroll['name'] as String?) ?? 'E')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payroll['name'] ?? 'Employee',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          payroll['department'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(payroll['basic_salary']),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(payroll['pay_date']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
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
