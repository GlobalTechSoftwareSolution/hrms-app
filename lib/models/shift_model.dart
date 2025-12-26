class Shift {
  final int? id;
  final String employeeEmail;
  final String shiftType; // 'Morning', 'Evening', 'Night'
  final String startTime;
  final String endTime;
  final String date;
  final String status; // 'active', 'inactive'

  Shift({
    this.id,
    required this.employeeEmail,
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    required this.date,
    this.status = 'active',
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['shift_id'] ?? json['id'],
      employeeEmail: json['emp_email'] ?? json['employee_email'] ?? '',
      shiftType: _normalizeShiftType(json['shift'] ?? json['shift_type'] ?? ''),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emp_email': employeeEmail,
      'shift': shiftType,
      'start_time': startTime,
      'end_time': endTime,
      'date': date,
      'status': status,
    };
  }

  // Normalize shift types to match our expected format
  static String _normalizeShiftType(String shiftType) {
    switch (shiftType.toLowerCase()) {
      case 'morning':
      case 'm':
        return 'Morning';
      case 'evening':
      case 'e':
        return 'Evening';
      case 'night':
      case 'n':
        return 'Night';
      default:
        return shiftType;
    }
  }
}

class OvertimeRecord {
  final int? id;
  final String employeeEmail;
  final String date;
  final double hours;
  final bool approved;
  final String? approvedBy;
  final String? approvedAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String? otStart;
  final String? otEnd;
  final String? empName;

  OvertimeRecord({
    this.id,
    required this.employeeEmail,
    required this.date,
    required this.hours,
    this.approved = false,
    this.approvedBy,
    this.approvedAt,
    this.status = 'pending',
    this.otStart,
    this.otEnd,
    this.empName,
  });

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) {
    return OvertimeRecord(
      id: json['id'],
      employeeEmail: json['email'] ?? json['employee_email'] ?? '',
      date: json['date'] ?? '',
      hours: (json['hours'] ?? 0).toDouble(),
      approved: json['approved'] ?? false,
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'],
      status: json['status'] ?? 'pending',
      otStart: json['ot_start'],
      otEnd: json['ot_end'],
      empName: json['emp_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': employeeEmail,
      'ot_start': otStart,
      'ot_end': otEnd,
      'approved': approved,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
      'status': status,
      'emp_name': empName,
    };
  }
}

class ShiftColumn {
  final String id;
  final String title;
  final String timeRange;
  final List<Employee> employees;

  ShiftColumn({
    required this.id,
    required this.title,
    required this.timeRange,
    required this.employees,
  });

  ShiftColumn copyWith({
    String? id,
    String? title,
    String? timeRange,
    List<Employee>? employees,
  }) {
    return ShiftColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      timeRange: timeRange ?? this.timeRange,
      employees: employees ?? this.employees,
    );
  }
}

class Employee {
  final String email;
  final String? fullname;
  final String? name;
  final String? department;
  final String? designation;
  final String? profilePicture;

  Employee({
    required this.email,
    this.fullname,
    this.name,
    this.department,
    this.designation,
    this.profilePicture,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      email: json['email'] ?? '',
      fullname: json['fullname'],
      name: json['name'],
      department: json['department'],
      designation: json['designation'],
      profilePicture: json['profile_picture'],
    );
  }

  String get displayName => fullname ?? name ?? email;

  String get initials {
    final name = displayName;
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
