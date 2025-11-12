import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

/// Reusable Calendar Widget
///
/// Usage:
/// ```dart
/// CustomCalendar(
///   focusedDay: _focusedDay,
///   selectedDay: _selectedDay,
///   onDaySelected: (selectedDay, focusedDay) {
///     setState(() {
///       _selectedDay = selectedDay;
///       _focusedDay = focusedDay;
///     });
///   },
///   onPageChanged: (focusedDay) {
///     setState(() => _focusedDay = focusedDay);
///   },
///
///   markerBuilder: (date) {
///     // Return custom markers for specific dates
///     if (isHoliday(date)) return '🎉';
///     if (isPresent(date)) return '✓';
///     return null;
///   },
///   dayBuilder: (date) {
///     // Custom day cell decoration
///     return Container(
///       decoration: BoxDecoration(
///         color: isHoliday(date) ? Colors.red.shade50 : null,
///       ),
///     );
///   },
/// )
/// ```
class CustomCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime selectedDay, DateTime focusedDay)? onDaySelected;
  final Function(DateTime focusedDay)? onPageChanged;
  final String? Function(DateTime)? markerBuilder;
  final Widget? Function(DateTime)? dayBuilder;
  final bool showMonthNavigation;
  final bool showTodayButton;
  final Function()? onTodayPressed;
  final CalendarFormat calendarFormat;
  final bool hideOutsideDays;

  const CustomCalendar({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    this.onDaySelected,
    this.onPageChanged,
    this.markerBuilder,
    this.dayBuilder,
    this.showMonthNavigation = false,
    this.showTodayButton = false,
    this.onTodayPressed,
    this.calendarFormat = CalendarFormat.month,
    this.hideOutsideDays = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Optional Month Navigation
        if (showMonthNavigation) _buildMonthNavigation(context),
        if (showMonthNavigation) const SizedBox(height: 16),

        // Calendar
        Container(
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
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) =>
                selectedDay != null && isSameDay(selectedDay, day),
            calendarFormat: calendarFormat,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            headerVisible: !showMonthNavigation,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left, size: 24),
              rightChevronIcon: const Icon(Icons.chevron_right, size: 24),
              headerPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
              weekendStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: !hideOutsideDays,
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade500,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade300, width: 2),
              ),
              todayTextStyle: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              weekendTextStyle: const TextStyle(color: Colors.red),
              defaultTextStyle: const TextStyle(color: Colors.black87),
              outsideTextStyle: const TextStyle(color: Colors.grey),
              markerDecoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              // Custom day builder
              defaultBuilder: dayBuilder != null
                  ? (context, day, focusedDay) {
                      final customWidget = dayBuilder!(day);
                      if (customWidget != null) {
                        return Stack(
                          children: [
                            customWidget,
                            Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        );
                      }
                      return null;
                    }
                  : null,

              // Custom marker builder
              markerBuilder: markerBuilder != null
                  ? (context, day, events) {
                      final marker = markerBuilder!(day);
                      if (marker != null) {
                        return Positioned(
                          bottom: 4,
                          child: Text(
                            marker,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }
                      return null;
                    }
                  : null,

              // Today builder
              todayBuilder: (context, day, focusedDay) {
                final marker = markerBuilder?.call(day);
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (marker != null)
                        Positioned(
                          bottom: 2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              marker,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },

              // Selected day builder
              selectedBuilder: (context, day, focusedDay) {
                final marker = markerBuilder?.call(day);
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade500,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (marker != null)
                        Positioned(
                          bottom: 2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              marker,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              if (onPageChanged != null) {
                final newDate = DateTime(focusedDay.year, focusedDay.month - 1);
                onPageChanged!(newDate);
              }
            },
          ),
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(focusedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showTodayButton) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onTodayPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              if (onPageChanged != null) {
                final newDate = DateTime(focusedDay.year, focusedDay.month + 1);
                onPageChanged!(newDate);
              }
            },
          ),
        ],
      ),
    );
  }
}
