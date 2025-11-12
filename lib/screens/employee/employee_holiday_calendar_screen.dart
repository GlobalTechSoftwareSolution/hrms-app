import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_calendar.dart';

class EmployeeHolidayCalendarScreen extends StatefulWidget {
  const EmployeeHolidayCalendarScreen({super.key});

  @override
  State<EmployeeHolidayCalendarScreen> createState() =>
      _EmployeeHolidayCalendarScreenState();
}

class _EmployeeHolidayCalendarScreenState
    extends State<EmployeeHolidayCalendarScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _holidays = [];
  bool _isLoading = true;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _selectedYear = DateTime.now().year;

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

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('/accounts/holidays/');

      if (response['success']) {
        final holidaysData = response['data'] as List? ?? [];

        setState(() {
          _holidays = holidaysData
              .map(
                (h) => {
                  'year': h['year'] ?? 0,
                  'month': h['month'] ?? 0,
                  'country': h['country'] ?? '',
                  'date': h['date'] ?? '',
                  'name': h['name'] ?? '',
                  'type': h['type'] ?? 'Other',
                  'weekday': h['weekday'] ?? '',
                },
              )
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching holidays: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _normalizeDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(d);
  }

  List<Map<String, dynamic>> _getHolidaysForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _holidays.where((h) {
      return _normalizeDate(h['date']) == dateStr &&
          DateTime.parse(h['date']).year == _selectedYear;
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedDateHolidays {
    if (_selectedDay == null) return [];
    return _getHolidaysForDate(_selectedDay!);
  }

  Map<int, List<Map<String, dynamic>>> get _holidaysByMonth {
    final grouped = <int, List<Map<String, dynamic>>>{};

    for (var holiday in _holidays) {
      final date = DateTime.parse(holiday['date']);
      if (date.year == _selectedYear) {
        final month = date.month - 1; // 0-indexed
        grouped[month] ??= [];
        grouped[month]!.add(holiday);
      }
    }

    return grouped;
  }

  List<int> get _availableYears {
    return _holidays.map((h) => DateTime.parse(h['date']).year).toSet().toList()
      ..sort();
  }

  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
      _selectedYear = DateTime.now().year;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Holiday Calendar'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Holiday Calendar'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('⚠ $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchHolidays,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Calendar'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHolidays,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Holiday Calendar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'View company holidays for $_selectedYear',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // Year Selector
              Row(
                children: [
                  const Text(
                    'Year:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _selectedYear,
                    items: _availableYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedYear = value;
                          _focusedDay = DateTime(value, _focusedDay.month);
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Calendar with Navigation
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    // Desktop: Calendar + Sidebar
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: CustomCalendar(
                            focusedDay: _focusedDay,
                            selectedDay: _selectedDay,
                            showMonthNavigation: true,
                            showTodayButton: true,
                            onTodayPressed: _goToToday,
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                                _selectedYear = focusedDay.year;
                              });
                            },
                            markerBuilder: (date) {
                              final holidays = _getHolidaysForDate(date);
                              if (holidays.isNotEmpty) return '🎉';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _buildSidebar()),
                      ],
                    );
                  } else {
                    // Mobile: Stacked
                    return Column(
                      children: [
                        CustomCalendar(
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          showMonthNavigation: true,
                          showTodayButton: true,
                          onTodayPressed: _goToToday,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                              _selectedYear = focusedDay.year;
                            });
                          },
                          markerBuilder: (date) {
                            final holidays = _getHolidaysForDate(date);
                            if (holidays.isNotEmpty) return '🎉';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSidebar(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // All Holidays by Month
              _buildHolidayCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Selected Date
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
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
        ),
        const SizedBox(height: 16),

        // Quick Stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                      _holidays
                          .where(
                            (h) =>
                                DateTime.parse(h['date']).year == _selectedYear,
                          )
                          .length
                          .toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    Text(
                      'Total Holidays',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHolidayCards() {
    final monthNames = [
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

    // Filter to only months with holidays
    final monthsWithHolidays = <int>[];
    for (int i = 0; i < 12; i++) {
      if (_holidaysByMonth[i]?.isNotEmpty ?? false) {
        monthsWithHolidays.add(i);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Holidays ($_selectedYear)',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth > 900) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 2;
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: monthsWithHolidays.map((index) {
                final monthHolidays = _holidaysByMonth[index] ?? [];

                // Sort by date
                monthHolidays.sort((a, b) {
                  final dateA = DateTime.parse(a['date']);
                  final dateB = DateTime.parse(b['date']);
                  return dateA.day.compareTo(dateB.day);
                });

                final cardWidth = crossAxisCount == 1
                    ? constraints.maxWidth
                    : crossAxisCount == 2
                    ? (constraints.maxWidth - 12) / 2
                    : (constraints.maxWidth - 24) / 3;

                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthNames[index],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 12),
                        ...monthHolidays.map((holiday) {
                          final date = DateTime.parse(holiday['date']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        holiday['name'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat('EEE').format(date),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              holiday['type'],
                                              style: TextStyle(
                                                fontSize: 9,
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
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
