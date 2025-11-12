class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status; // present, absent, late, half-day

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
  });

  Duration? get workDuration {
    if (checkIn != null && checkOut != null) {
      return checkOut!.difference(checkIn!);
    }
    return null;
  }

  String get workHours {
    final duration = workDuration;
    if (duration == null) return 'N/A';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
