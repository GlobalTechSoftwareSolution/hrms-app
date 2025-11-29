import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/hrms_provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HRMSProvider>(
      builder: (context, hrmsProvider, child) {
        final attendanceRecords = hrmsProvider.getTodayAttendance();

        return Scaffold(
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusChip(
                          'Present',
                          attendanceRecords
                              .where(
                                (a) =>
                                    a.status == 'present' || a.status == 'late',
                              )
                              .length,
                          Colors.green,
                        ),
                        _buildStatusChip(
                          'Absent',
                          attendanceRecords
                              .where((a) => a.status == 'absent')
                              .length,
                          Colors.red,
                        ),
                        _buildStatusChip(
                          'Late',
                          attendanceRecords
                              .where((a) => a.status == 'late')
                              .length,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: attendanceRecords.isEmpty
                    ? const Center(
                        child: Text('No attendance records for today'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: attendanceRecords.length,
                        itemBuilder: (context, index) {
                          final attendance = attendanceRecords[index];
                          return _buildAttendanceCard(attendance);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(attendance) {
    Color statusColor;
    IconData statusIcon;

    switch (attendance.status) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendance.employeeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (attendance.checkIn != null)
                    Row(
                      children: [
                        Icon(Icons.login, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'In: ${DateFormat('hh:mm a').format(attendance.checkIn!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (attendance.checkOut != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Out: ${DateFormat('hh:mm a').format(attendance.checkOut!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (attendance.workDuration != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Work Hours: ${attendance.workHours}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                attendance.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
