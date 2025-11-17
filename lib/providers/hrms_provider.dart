import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../models/leave_request.dart';
import '../models/attendance.dart';

class HRMSProvider with ChangeNotifier {
  List<Employee> _employees = [];
  List<LeaveRequest> _leaveRequests = [];
  List<Attendance> _attendanceRecords = [];

  List<Employee> get employees => _employees;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  List<Attendance> get attendanceRecords => _attendanceRecords;

  HRMSProvider();

  void addEmployee(Employee employee) {
    _employees.add(employee);
    notifyListeners();
  }

  void updateEmployee(Employee employee) {
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index != -1) {
      _employees[index] = employee;
      notifyListeners();
    }
  }

  void deleteEmployee(String id) {
    _employees.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addLeaveRequest(LeaveRequest request) {
    _leaveRequests.add(request);
    notifyListeners();
  }

  void updateLeaveRequestStatus(String id, String status) {
    final index = _leaveRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final request = _leaveRequests[index];
      _leaveRequests[index] = LeaveRequest(
        id: request.id,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        leaveType: request.leaveType,
        startDate: request.startDate,
        endDate: request.endDate,
        reason: request.reason,
        status: status,
        requestDate: request.requestDate,
      );
      notifyListeners();
    }
  }

  void addAttendance(Attendance attendance) {
    _attendanceRecords.add(attendance);
    notifyListeners();
  }

  List<LeaveRequest> getPendingLeaveRequests() {
    return _leaveRequests.where((r) => r.status == 'pending').toList();
  }

  List<Attendance> getTodayAttendance() {
    final today = DateTime.now();
    return _attendanceRecords.where((a) {
      return a.date.year == today.year &&
          a.date.month == today.month &&
          a.date.day == today.day;
    }).toList();
  }

  Map<String, int> getEmployeesByDepartment() {
    final Map<String, int> departmentCount = {};
    for (var employee in _employees) {
      departmentCount[employee.department] =
          (departmentCount[employee.department] ?? 0) + 1;
    }
    return departmentCount;
  }

  double getAttendanceRate() {
    final todayAttendance = getTodayAttendance();
    if (todayAttendance.isEmpty) return 0;
    final present = todayAttendance
        .where((a) => a.status == 'present' || a.status == 'late')
        .length;
    return (present / _employees.length) * 100;
  }
}
