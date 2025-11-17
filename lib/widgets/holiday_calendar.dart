import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class HolidayCalendar extends StatefulWidget {
  final String role;

  const HolidayCalendar({super.key, required this.role});

  @override
  State<HolidayCalendar> createState() => _HolidayCalendarState();
}

class _HolidayCalendarState extends State<HolidayCalendar> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _holidays = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month - 1; // 0-indexed
  DateTime? _selectedDay = DateTime.now();

  static const Map<String, Color> holidayColors = {
    'National Holiday': Colors.red,
    'Government Holiday': Colors.blue,
    'Jayanti/Festival': Colors.purple,
    'Festival': Colors.green,
    'Regional Festival': Colors.orange,
    'Harvest Festival': Colors.amber,
    'Observance': Colors.grey,
    'Observance/Restricted': Colors.grey,
    'Festival/National Holiday': Colors.pink,
    'Jayanti': Colors.deepPurple,
    'Other': Colors.blueGrey,
  };

  final List<String> _monthNames = [
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

  final List<String> _weekDays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call the real API to fetch holidays
      final response = await _apiService.get('/accounts/holidays/');

      if (response['success']) {
        final holidaysData = response['data'] as List? ?? [];

        setState(() {
          _holidays = holidaysData
              .map(
                (h) => {
                  'year': h['year'] ?? DateTime.now().year,
                  'month': h['month'] ?? 1,
                  'country': h['country'] ?? 'India',
                  'date': h['date'] ?? '',
                  'name': h['name'] ?? 'Holiday',
                  'type': h['type'] ?? 'Other',
                  'weekday': h['weekday'] ?? '',
                },
              )
              .toList();
        });
      } else {
        setState(() {
          _error = response['error'] ?? 'Failed to load holidays';
        });
      }
    } catch (e) {
      setState(() {
        _error =
            'Network error: Failed to load holidays. Please check your connection.';
      });
      print('Holiday fetch error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _normalizeDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  List<Map<String, dynamic>> get _selectedDateHolidays {
    if (_selectedDay == null) return [];
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    return _holidays
        .where((h) => _normalizeDate(h['date']) == dateStr)
        .toList();
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_selectedMonth == 0) {
        _selectedMonth = 11;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _goToNextMonth() {
    setState(() {
      if (_selectedMonth == 11) {
        _selectedMonth = 0;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedYear = today.year;
      _selectedMonth = today.month - 1;
      _selectedDay = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchHolidays,
      child: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildYearSelector(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Mobile layout: Stack vertically
                  if (constraints.maxWidth < 1024) {
                    return Column(
                      children: [
                        _buildMainCalendar(),
                        const SizedBox(height: 16),
                        _buildSidebar(),
                      ],
                    );
                  }
                  // Desktop layout: 3:1 ratio like React
                  else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildMainCalendar()),
                        const SizedBox(width: 24),
                        Expanded(flex: 1, child: _buildSidebar()),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
              _buildHolidayCards(),
              if (_error != null) _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Holiday Calendar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View company holidays for $_selectedYear',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    // Get unique years from holidays data
    final availableYears =
        _holidays
            .map((h) => h['year'] as int? ?? DateTime.now().year)
            .toSet()
            .toList()
          ..sort();

    if (availableYears.isEmpty) {
      availableYears.add(DateTime.now().year);
    }

    if (!availableYears.contains(_selectedYear)) {
      availableYears.add(_selectedYear);
      availableYears.sort();
    }

    return Row(
      children: [
        const Text(
          'Year:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            items: availableYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedYear = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 16),
          _buildWeekDaysHeader(),
          const SizedBox(height: 8),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: _goToPreviousMonth,
                    icon: const Icon(Icons.chevron_left, size: 16),
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.5,
                  ),
                  child: Text(
                    '${_monthNames[_selectedMonth]} $_selectedYear',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: _goToNextMonth,
                    icon: const Icon(Icons.chevron_right, size: 16),
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            if (!isNarrow)
              ElevatedButton(
                onPressed: _goToToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Today'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWeekDaysHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: _weekDays
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive cell height based on screen width
        final double cellHeight = constraints.maxWidth < 400 ? 60 : 80;

        final firstDay = DateTime(_selectedYear, _selectedMonth + 1, 1);
        final lastDay = DateTime(_selectedYear, _selectedMonth + 2, 0);
        final daysInMonth = lastDay.day;
        final startingDay = firstDay.weekday % 7;

        final List<Widget> days = [];

        // Empty days for the start of the month
        for (int i = 0; i < startingDay; i++) {
          days.add(
            Container(
              height: cellHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                color: Colors.grey.shade50,
              ),
            ),
          );
        }

        // Actual days of the month
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_selectedYear, _selectedMonth + 1, day);
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final isToday =
              DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
          final isSelected =
              _selectedDay != null &&
              DateFormat('yyyy-MM-dd').format(_selectedDay!) == dateStr;

          final dayHolidays = _holidays
              .where((h) => _normalizeDate(h['date']) == dateStr)
              .toList();

          days.add(
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDay = date;
                });
              },
              child: Container(
                height: cellHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  color: isSelected
                      ? Colors.blue.shade500
                      : isToday
                      ? Colors.blue.shade50
                      : Colors.white,
                ),
                padding: const EdgeInsets.all(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? Colors.blue.shade600
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...dayHolidays.take(2).map((holiday) {
                              final color =
                                  holidayColors[holiday['type']] ?? Colors.grey;
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 0.5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                  vertical: 0.5,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                                child: Text(
                                  holiday['name'].length > 6
                                      ? '${holiday['name'].substring(0, 6)}...'
                                      : holiday['name'],
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            if (dayHolidays.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 0.5),
                                child: Text(
                                  '+${dayHolidays.length - 2}',
                                  style: TextStyle(
                                    fontSize: 7,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ),
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

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: days,
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        _buildSelectedDateCard(),
        const SizedBox(height: 16),
        _buildOverviewCard(),
      ],
    );
  }

  Widget _buildSelectedDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          const Text(
            'Selected Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _selectedDay != null
                  ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                  : 'No date selected',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Holidays:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _selectedDateHolidays.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No holidays',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _selectedDateHolidays.map((h) {
                    final color = holidayColors[h['type']] ?? Colors.grey;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  h['type'],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final yearHolidays = _holidays
        .where((h) => DateTime.parse(h['date']).year == _selectedYear)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Text(
                  yearHolidays.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
                Text(
                  'Total Holidays',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCards() {
    // Group holidays by month for the selected year
    final Map<int, List<Map<String, dynamic>>> holidaysByMonth = {};

    for (final holiday in _holidays) {
      final date = DateTime.parse(holiday['date']);
      if (date.year == _selectedYear) {
        final month = date.month - 1; // 0-indexed
        if (!holidaysByMonth.containsKey(month)) {
          holidaysByMonth[month] = [];
        }
        holidaysByMonth[month]!.add(holiday);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Holidays ($_selectedYear)',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth > 800) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 400) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.2,
              ),
              itemCount: holidaysByMonth.length,
              itemBuilder: (context, index) {
                final monthNum = holidaysByMonth.keys.elementAt(index);
                final monthHolidays = holidaysByMonth[monthNum]!;

                // Sort holidays by date
                monthHolidays.sort(
                  (a, b) => DateTime.parse(
                    a['date'],
                  ).day.compareTo(DateTime.parse(b['date']).day),
                );

                return Container(
                  height: 200, // Fixed height to prevent overflow
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthNames[monthNum],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: monthHolidays.length,
                          itemBuilder: (context, holidayIndex) {
                            final holiday = monthHolidays[holidayIndex];
                            final date = DateTime.parse(holiday['date']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        date.day.toString(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          holiday['name'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('EEE').format(date),
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                holiday['type'],
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}
