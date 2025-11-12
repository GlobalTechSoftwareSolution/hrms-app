import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import '../../services/api_service.dart';

class EmployeePayrollScreen extends StatefulWidget {
  const EmployeePayrollScreen({super.key});

  @override
  State<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends State<EmployeePayrollScreen> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _payrollData = [];
  Map<String, dynamic>? _employeeData;
  
  bool _isLoading = true;
  String? _error;
  String _userEmail = '';
  
  String _filterYear = '2025';
  String _filterStatus = 'all';
  
  int _presentDays = 0;
  int _absentDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';
      
      if (_userEmail.isEmpty) {
        throw Exception('No employee logged in.');
      }

      // Fetch employee data
      final empResponse = await _apiService.get('/accounts/employees/${Uri.encodeComponent(_userEmail)}/');
      if (empResponse['success']) {
        _employeeData = empResponse['data'];
      }

      // Fetch attendance for STD days
      try {
        final attResponse = await _apiService.get('/accounts/get_attendance/${Uri.encodeComponent(_userEmail)}/');
        if (attResponse['success']) {
          final attData = attResponse['data'];
          if (attData['attendance'] is List) {
            _presentDays = (attData['attendance'] as List).length;
          }
        }
      } catch (e) {
        print('Failed to fetch attendance: $e');
      }

      // Fetch absences for LOP days
      try {
        final absResponse = await _apiService.get('/accounts/get_absent/${Uri.encodeComponent(_userEmail)}/');
        if (absResponse['success']) {
          final absData = absResponse['data'];
          if (absData is List) {
            _absentDays = absData.length;
          }
        }
      } catch (e) {
        print('Failed to fetch absences: $e');
      }

      // Fetch payroll data
      final payrollResponse = await _apiService.get('/accounts/get_payroll/${Uri.encodeComponent(_userEmail)}/');
      
      if (payrollResponse['success']) {
        final payrollApiData = payrollResponse['data'];
        
        List<dynamic> payrollArray = [];
        if (payrollApiData['payroll'] != null) {
          payrollArray = [payrollApiData['payroll']];
        } else if (payrollApiData['payrolls'] != null) {
          payrollArray = payrollApiData['payrolls'];
        }

        final mappedData = payrollArray.map((item) {
          final basicSalary = double.tryParse(item['basic_salary'].toString()) ?? 0.0;
          final stdDays = _presentDays > 0 ? _presentDays : (item['STD'] ?? 28);
          final lopDays = _absentDays > 0 ? _absentDays : (item['LOP'] ?? 0);

          return {
            'id': item['id'] ?? 0,
            'month': '${item['month']} ${item['year']}',
            'basicSalary': basicSalary,
            'stdDays': stdDays,
            'lopDays': lopDays,
            'status': (item['status'] ?? 'pending').toString().toLowerCase(),
            'paymentDate': item['pay_date'] ?? '',
            'email': item['email'],
            'netPay': _calculateNetPay(basicSalary),
          };
        }).toList();

        setState(() => _payrollData = List<Map<String, dynamic>>.from(mappedData));
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateNetPay(double basicSalary) {
    // Calculate earnings
    final hra = (basicSalary * 0.4).round();
    final travelAllowance = 1600;
    final medicalAllowance = 1250;
    final specialAllowance = (basicSalary * 0.15).round();
    
    final grossEarnings = basicSalary + hra + travelAllowance + medicalAllowance + specialAllowance;
    
    // Calculate deductions
    final pf = (basicSalary * 0.12).round();
    final professionalTax = 200;
    final incomeTax = (basicSalary * 0.05).round();
    
    final grossDeductions = pf + professionalTax + incomeTax;
    
    return grossEarnings - grossDeductions;
  }

  List<Map<String, dynamic>> get _filteredData {
    return _payrollData.where((record) {
      final matchesYear = record['month'].toString().contains(_filterYear);
      final matchesStatus = _filterStatus == 'all' || record['status'] == _filterStatus;
      return matchesYear && matchesStatus;
    }).toList();
  }

  double get _overallNetPay {
    return _payrollData
        .where((rec) => rec['email'] == _userEmail)
        .fold(0.0, (sum, rec) => sum + (rec['basicSalary'] as double));
  }

  double get _currentMonthNetPay {
    final employeePayrolls = _payrollData.where((rec) => rec['email'] == _userEmail).toList();
    if (employeePayrolls.isEmpty) return 0.0;
    return employeePayrolls.first['basicSalary'] as double;
  }

  String _formatCurrency(double value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadPayrollPDF(Map<String, dynamic> record) async {
    try {
      if (_employeeData == null) {
        throw Exception('Employee data not available');
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      final pdf = pw.Document();
      
      final basicSalary = record['basicSalary'] as double;
      final hra = (basicSalary * 0.4).round();
      final travelAllowance = 1600;
      final medicalAllowance = 1250;
      final specialAllowance = (basicSalary * 0.15).round();
      final grossEarnings = basicSalary + hra + travelAllowance + medicalAllowance + specialAllowance;
      
      final pf = (basicSalary * 0.12).round();
      final professionalTax = 200;
      final incomeTax = (basicSalary * 0.05).round();
      final grossDeductions = pf + professionalTax + incomeTax;
      final netPay = grossEarnings - grossDeductions;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Global Tech Software Solutions',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'PAYSLIP',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('For the period: ${record['month']}', style: const pw.TextStyle(fontSize: 11)),
                pw.Divider(thickness: 0.6),
                pw.SizedBox(height: 10),
                
                // Employee Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Employee ID', _employeeData!['emp_id'] ?? 'N/A'),
                          _buildInfoRow('Employee Name', _employeeData!['fullname'] ?? 'N/A'),
                          _buildInfoRow('Bank', _employeeData!['bank_name'] ?? 'N/A'),
                          _buildInfoRow('Bank A/c No.', _employeeData!['account_number'] ?? 'N/A'),
                          _buildInfoRow('Date of Joining', _employeeData!['date_joined'] ?? 'N/A'),
                          _buildInfoRow('LOP Days', record['lopDays'].toString()),
                          _buildInfoRow('PF No.', _employeeData!['pf_no'] ?? 'N/A'),
                          _buildInfoRow('STD Days', record['stdDays'].toString()),
                          _buildInfoRow('Worked Days', (record['stdDays'] - record['lopDays']).toString()),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Department', _employeeData!['department'] ?? 'N/A'),
                          _buildInfoRow('Designation', _employeeData!['designation'] ?? 'N/A'),
                          _buildInfoRow('Facility', 'Bengaluru Office'),
                          _buildInfoRow('Entity', 'Global Tech Software Solutions'),
                          _buildInfoRow('PF - UAN', _employeeData!['pf_uan'] ?? 'N/A'),
                          _buildInfoRow('IFSC Code', _employeeData!['ifsc'] ?? 'N/A'),
                          _buildInfoRow('Branch', _employeeData!['branch'] ?? 'N/A'),
                          _buildInfoRow('Location', _employeeData!['work_location'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Earnings & Deductions Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                      children: [
                        _buildTableCell('Earnings', isHeader: true),
                        _buildTableCell('Amount (Rs.)', isHeader: true),
                        _buildTableCell('Deductions', isHeader: true),
                        _buildTableCell('Amount (Rs.)', isHeader: true),
                      ],
                    ),
                    // Rows
                    _buildEarningsDeductionsRow('Basic Salary', basicSalary, 'Provident Fund', pf.toDouble()),
                    _buildEarningsDeductionsRow('House Rent Allowance', hra.toDouble(), 'Professional Tax', professionalTax.toDouble()),
                    _buildEarningsDeductionsRow('Travel Allowance', travelAllowance.toDouble(), 'Income Tax', incomeTax.toDouble()),
                    _buildEarningsDeductionsRow('Medical Allowance', medicalAllowance.toDouble(), '', 0),
                    _buildEarningsDeductionsRow('Special Allowance', specialAllowance.toDouble(), '', 0),
                    // Totals
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('GROSS EARNINGS', isHeader: true),
                        _buildTableCell(_formatCurrency(grossEarnings), isHeader: true),
                        _buildTableCell('GROSS DEDUCTIONS', isHeader: true),
                        _buildTableCell(_formatCurrency(grossDeductions.toDouble()), isHeader: true),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                
                // Net Pay
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET PAY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        'Rs. ${_formatCurrency(netPay)}/-',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'This is a computer generated salary slip and does not require signature or stamp.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'Payslip_${_employeeData!['fullname']}_${record['month'].toString().replaceAll(' ', '_')}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Open the PDF file
      final result = await OpenFilex.open(file.path);
      
      if (result.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF opened successfully!\n$fileName'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to:\n${file.path}\n\nTap to view location'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate PDF. Please try again.')),
      );
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.TableRow _buildEarningsDeductionsRow(String earning, double earningAmt, String deduction, double deductionAmt) {
    return pw.TableRow(
      children: [
        _buildTableCell(earning),
        _buildTableCell(_formatCurrency(earningAmt)),
        _buildTableCell(deduction),
        _buildTableCell(deduction.isEmpty ? '' : _formatCurrency(deductionAmt)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payroll Dashboard'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('⏳ Loading payroll data...', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payroll Dashboard'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('❌ $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Payroll Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'View your salary history and download payslips',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              // Filters
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterYear,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['2025', '2024', '2023']
                          .map((year) => DropdownMenuItem(value: year, child: Text(year)))
                          .toList(),
                      onChanged: (value) => setState(() => _filterYear = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Status')),
                        ..._payrollData
                            .map((rec) => rec['status'] as String)
                            .toSet()
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status[0].toUpperCase() + status.substring(1)),
                                )),
                      ],
                      onChanged: (value) => setState(() => _filterStatus = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: Colors.blue.shade500, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overall Net Pay', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_formatCurrency(_overallNetPay)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: Colors.green.shade500, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Month Net Pay', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_formatCurrency(_currentMonthNetPay)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Payroll Records
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                ),
                child: _filteredData.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Text('💸', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text('No payroll records yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Your payroll data will appear here once available.', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredData.length,
                        itemBuilder: (context, index) {
                          final record = _filteredData[index];
                          final status = record['status'] as String;
                          final statusColor = _getStatusColor(status);
                          
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        record['month'] as String,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status[0].toUpperCase() + status.substring(1),
                                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRecordDetail('Basic Salary', '₹${_formatCurrency(record['basicSalary'])}'),
                                  _buildRecordDetail('STD Days', record['stdDays'].toString()),
                                  _buildRecordDetail('LOP Days', record['lopDays'].toString()),
                                  _buildRecordDetail('Net Pay', '₹${_formatCurrency(record['netPay'])}'),
                                  _buildRecordDetail('Payment Date', record['paymentDate'] as String),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _downloadPayrollPDF(record),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Download PDF'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
