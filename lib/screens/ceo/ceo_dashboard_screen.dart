import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../layouts/dashboard_layout.dart';

class CeoDashboardScreen extends StatefulWidget {
  const CeoDashboardScreen({super.key});

  @override
  State<CeoDashboardScreen> createState() => _CeoDashboardScreenState();
}

class _CeoDashboardScreenState extends State<CeoDashboardScreen> {
  String selectedYear = '2023-2024';
  
  // Financial data
  final Map<String, String> financialData = {
    'totalHours': '100',
    'totalEmployees': '50',
    'totalSales': '10',
    'totalConversion': '1',
    'paymentDone': '+4',
    'paymentPending': '+1',
    'cost': '+10000',
    'grossProfit': '+10',
  };

  // Highlights data
  final List<Map<String, dynamic>> highlights = [
    {
      'title': 'Last Sales',
      'date': '16 Oct 2021',
      'amount': '₹1000',
      'icon': '💰'
    },
    {
      'title': 'Last Receipt',
      'date': '18 Oct 2021',
      'amount': '₹1000',
      'icon': '📥'
    },
    {
      'title': 'Last Purchase',
      'date': '16 Oct 2021',
      'amount': '₹1000',
      'icon': '🛒'
    },
    {
      'title': 'Last Payment',
      'date': '13 Oct 2021',
      'amount': '₹1000',
      'icon': '📤'
    },
    {
      'title': 'Due Customers',
      'count': '10',
      'value': '₹1000',
      'icon': '👥'
    },
  ];

  // Monthly trend data
  final List<Map<String, dynamic>> monthlyTrend = [
    {'month': 'Apr', 'hours': 95, 'productivity': 65},
    {'month': 'May', 'hours': 87, 'productivity': 72},
    {'month': 'Jun', 'hours': 76, 'productivity': 68},
    {'month': 'Jul', 'hours': 82, 'productivity': 75},
    {'month': 'Aug', 'hours': 91, 'productivity': 70},
    {'month': 'Sep', 'hours': 89, 'productivity': 78},
    {'month': 'Oct', 'hours': 94, 'productivity': 80},
    {'month': 'Nov', 'hours': 88, 'productivity': 74},
    {'month': 'Dec', 'hours': 92, 'productivity': 76},
    {'month': 'Jan', 'hours': 85, 'productivity': 71},
    {'month': 'Feb', 'hours': 90, 'productivity': 77},
    {'month': 'Mar', 'hours': 96, 'productivity': 82},
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildMainMetrics(),
              const SizedBox(height: 16),
              _buildStatisticsAndHighlights(),
              const SizedBox(height: 16),
              _buildPerformanceSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 600;
          
          if (isSmallScreen) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.dashboard, size: 24, color: Colors.blue.shade600),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CEO Dashboard',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Global Tech Software Solutions',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2023 - 2024 • 01-04-2024 to 31-03-2025',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedYear,
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700, size: 18),
                          items: const [
                            DropdownMenuItem(value: '2023-2024', child: Text('2023-2024')),
                            DropdownMenuItem(value: '2024-2025', child: Text('2024-2025')),
                            DropdownMenuItem(value: '2025-2026', child: Text('2025-2026')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dashboard, size: 24, color: Colors.blue.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CEO Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Global Tech Software Solutions • 2023 - 2024 • 01-04-2024 to 31-03-2025',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedYear,
                      style: TextStyle(color: Colors.blue.shade700),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                      items: const [
                        DropdownMenuItem(value: '2023-2024', child: Text('2023-2024')),
                        DropdownMenuItem(value: '2024-2025', child: Text('2024-2025')),
                        DropdownMenuItem(value: '2025-2026', child: Text('2025-2026')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedYear = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMainMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 1.2;
        
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.0;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 2;
          childAspectRatio = 1.3;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 2.5;
        }
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildMetricCard(
              'Total Hours',
              financialData['totalHours']!,
              '📈',
              Colors.green,
              '+12.5% from last year',
            ),
            _buildMetricCard(
              'Total Employees',
              financialData['totalEmployees']!,
              '💳',
              Colors.blue,
              '+8.3% from last year',
            ),
            _buildMetricCard(
              'Total Sales',
              '₹${financialData['totalSales']!}',
              '🛒',
              Colors.orange,
              '+15.2% from last year',
            ),
            _buildMetricCard(
              'Total Conversion',
              '₹${financialData['totalConversion']!}',
              '💸',
              Colors.purple,
              '+9.7% from last year',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, String emoji, Color color, String change) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = constraints.maxWidth < 200 ? 20 : 28;
        double titleFontSize = constraints.maxWidth < 200 ? 10 : 12;
        double changeFontSize = constraints.maxWidth < 200 ? 10 : 12;
        double emojiSize = constraints.maxWidth < 200 ? 20 : 24;
        double padding = constraints.maxWidth < 200 ? 12 : 16;
        
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    emoji,
                    style: TextStyle(fontSize: emojiSize),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: changeFontSize,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsAndHighlights() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile layout - stack vertically
          return Column(
            children: [
              _buildStatisticsSection(),
              const SizedBox(height: 16),
              _buildHighlightsSection(),
            ],
          );
        } else {
          // Desktop layout - side by side
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildStatisticsSection(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHighlightsSection(),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              double childAspectRatio = constraints.maxWidth > 600 ? 1.8 : 2.5;
              
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildStatItem('Payment Done', financialData['paymentDone']!, Colors.green, '📋'),
                  _buildStatItem('Payment Pending', financialData['paymentPending']!, Colors.red, '📄'),
                  _buildStatItem('Operating Cost', financialData['cost']!, Colors.orange, '⚡'),
                  _buildStatItem('Gross Profit', financialData['grossProfit']!, Colors.purple, '💰'),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Working Hours vs Productivity Trend',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: monthlyTrend.isEmpty 
            ? const Center(
                child: Text(
                  'No chart data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 100 || constraints.maxHeight < 100) {
                    return const Center(
                      child: Text(
                        'Chart too small to display',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    );
                  }
                  
                  return BarChart(
                    key: const ValueKey('ceo_dashboard_chart'),
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < monthlyTrend.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    monthlyTrend[index]['month']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: monthlyTrend.asMap().entries.map((entry) {
                        double barWidth = constraints.maxWidth > 400 ? 8 : 4;
                        final hours = entry.value['hours'];
                        final productivity = entry.value['productivity'];
                        
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: (hours is num) ? hours.toDouble() : 0.0,
                              color: Colors.green.shade500,
                              width: barWidth,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2),
                              ),
                            ),
                            BarChartRodData(
                              toY: (productivity is num) ? productivity.toDouble() : 0.0,
                              color: Colors.blue.shade500,
                              width: barWidth,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Hours', Colors.green.shade500),
            const SizedBox(width: 24),
            _buildLegendItem('Productivity', Colors.blue.shade500),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Highlights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ...highlights.map((highlight) => _buildHighlightItem(highlight)),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildHighlightItem(Map<String, dynamic> highlight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                highlight['icon'] ?? '📋',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      highlight['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      highlight['date'] ?? 'No Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (highlight['amount'] != null)
            Text(
              highlight['amount'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          if (highlight['count'] != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${highlight['count'] ?? '0'} Customers',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  highlight['value'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 300 ? 2 : 1;
            double childAspectRatio = constraints.maxWidth > 300 ? 2.2 : 3.0;
            
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: childAspectRatio,
              children: [
                _buildActionButton('Generate Report', Colors.blue),
                _buildActionButton('Export Data', Colors.green),
                _buildActionButton('View Analytics', Colors.purple),
                _buildActionButton('Schedule Meeting', Colors.orange),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, Color color) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title - Coming soon')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade800, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('₹100', 'Net Flow'),
          _buildSummaryItem('10%', 'Profit Margin'),
          _buildSummaryItem('3%', 'Quarterly Growth'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
