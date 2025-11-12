class AttendanceRecord {
  final String email;
  final String fullname;
  final String department;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final WorkedHours hours;

  AttendanceRecord({
    required this.email,
    required this.fullname,
    required this.department,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.hours,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Calculate hours if check_in and check_out are present
    WorkedHours hours = WorkedHours(hrs: 0, mins: 0, secs: 0);
    
    if (json['check_in'] != null && json['check_out'] != null) {
      try {
        final checkInTime = DateTime.parse('${json['date']}T${json['check_in']}');
        final checkOutTime = DateTime.parse('${json['date']}T${json['check_out']}');
        final diff = checkOutTime.difference(checkInTime);
        
        if (diff.inSeconds > 0) {
          hours = WorkedHours(
            hrs: diff.inHours,
            mins: (diff.inMinutes % 60),
            secs: (diff.inSeconds % 60),
          );
        }
      } catch (e) {
        print('Error calculating hours: $e');
      }
    }

    return AttendanceRecord(
      email: json['email'] ?? '',
      fullname: json['fullname'] ?? '',
      department: json['department'] ?? '',
      date: json['date'] ?? '',
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      hours: hours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullname': fullname,
      'department': department,
      'date': date,
      'check_in': checkIn,
      'check_out': checkOut,
      'hours': hours.toJson(),
    };
  }
}

class WorkedHours {
  final int hrs;
  final int mins;
  final int secs;

  WorkedHours({
    required this.hrs,
    required this.mins,
    required this.secs,
  });

  int get totalSeconds => (hrs * 3600) + (mins * 60) + secs;
  double get totalHours => hrs + (mins / 60) + (secs / 3600);

  Map<String, dynamic> toJson() {
    return {
      'hrs': hrs,
      'mins': mins,
      'secs': secs,
    };
  }

  @override
  String toString() => '${hrs}h ${mins}m ${secs}s';
}
