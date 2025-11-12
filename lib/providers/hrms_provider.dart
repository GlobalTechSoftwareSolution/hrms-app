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

  HRMSProvider() {
    _initializeDummyData();
  }

  void _initializeDummyData() {
    // Dummy employees
    _employees = [
      Employee(
        id: '1',
        name: 'John Doe',
        email: 'john.doe@company.com',
        department: 'Engineering',
        position: 'Senior Developer',
        phone: '+1 234 567 8900',
        joinDate: DateTime(2022, 1, 15),
        status: 'Active',
        salary: 85000,
      ),
      Employee(
        id: '2',
        name: 'Jane Smith',
        email: 'jane.smith@company.com',
        department: 'Marketing',
        position: 'Marketing Manager',
        phone: '+1 234 567 8901',
        joinDate: DateTime(2021, 6, 10),
        status: 'Active',
        salary: 75000,
      ),
      Employee(
        id: '3',
        name: 'Mike Johnson',
        email: 'mike.johnson@company.com',
        department: 'HR',
        position: 'HR Specialist',
        phone: '+1 234 567 8902',
        joinDate: DateTime(2023, 3, 20),
        status: 'Active',
        salary: 65000,
      ),
      Employee(
        id: '4',
        name: 'Sarah Williams',
        email: 'sarah.williams@company.com',
        department: 'Engineering',
        position: 'UI/UX Designer',
        phone: '+1 234 567 8903',
        joinDate: DateTime(2022, 8, 5),
        status: 'Active',
        salary: 70000,
      ),
      Employee(
        id: '5',
        name: 'David Brown',
        email: 'david.brown@company.com',
        department: 'Sales',
        position: 'Sales Executive',
        phone: '+1 234 567 8904',
        joinDate: DateTime(2023, 1, 12),
        status: 'Active',
        salary: 60000,
      ),
    ];

    // Dummy leave requests
    _leaveRequests = [
      LeaveRequest(
        id: '1',
        employeeId: '1',
        employeeName: 'John Doe',
        leaveType: 'Vacation',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 9)),
        reason: 'Family vacation',
        status: 'pending',
        requestDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      LeaveRequest(
        id: '2',
        employeeId: '2',
        employeeName: 'Jane Smith',
        leaveType: 'Sick Leave',
        startDate: DateTime.now().subtract(const Duration(days: 3)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        reason: 'Medical appointment',
        status: 'approved',
        requestDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      LeaveRequest(
        id: '3',
        employeeId: '4',
        employeeName: 'Sarah Williams',
        leaveType: 'Personal',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 12)),
        reason: 'Personal matters',
        status: 'pending',
        requestDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    // Dummy attendance records
    final now = DateTime.now();
    _attendanceRecords = [
      Attendance(
        id: '1',
        employeeId: '1',
        employeeName: 'John Doe',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 9, 0),
        checkOut: DateTime(now.year, now.month, now.day, 18, 0),
        status: 'present',
      ),
      Attendance(
        id: '2',
        employeeId: '2',
        employeeName: 'Jane Smith',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 9, 15),
        checkOut: DateTime(now.year, now.month, now.day, 17, 45),
        status: 'present',
      ),
      Attendance(
        id: '3',
        employeeId: '3',
        employeeName: 'Mike Johnson',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 10, 30),
        status: 'late',
      ),
      Attendance(
        id: '4',
        employeeId: '4',
        employeeName: 'Sarah Williams',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 8, 45),
        checkOut: DateTime(now.year, now.month, now.day, 18, 15),
        status: 'present',
      ),
      Attendance(
        id: '5',
        employeeId: '5',
        employeeName: 'David Brown',
        date: now,
        status: 'absent',
      ),
    ];
  }

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
