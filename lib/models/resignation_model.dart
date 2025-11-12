class ResignationStatus {
  final String email;
  final String fullname;
  final String? department;
  final String? designation;
  final String? reasonForResignation;
  final String? managerApproved;
  final String? hrApproved;
  final String? managerDescription;
  final String? hrDescription;
  final String? approved;
  final DateTime? offboardedAt;

  ResignationStatus({
    required this.email,
    required this.fullname,
    this.department,
    this.designation,
    this.reasonForResignation,
    this.managerApproved,
    this.hrApproved,
    this.managerDescription,
    this.hrDescription,
    this.approved,
    this.offboardedAt,
  });

  factory ResignationStatus.fromJson(Map<String, dynamic> json) {
    return ResignationStatus(
      email: json['email'] ?? '',
      fullname: json['fullname'] ?? '',
      department: json['department'],
      designation: json['designation'],
      reasonForResignation: json['reason_for_resignation'],
      managerApproved: json['manager_approved']?.toString(),
      hrApproved: json['hr_approved']?.toString(),
      managerDescription: json['manager_description'],
      hrDescription: json['hr_description'],
      approved: json['approved']?.toString(),
      offboardedAt: json['offboarded_at'] != null
          ? DateTime.tryParse(json['offboarded_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullname': fullname,
      'department': department,
      'designation': designation,
      'reason_for_resignation': reasonForResignation,
      'manager_approved': managerApproved,
      'hr_approved': hrApproved,
      'manager_description': managerDescription,
      'hr_description': hrDescription,
      'approved': approved,
      'offboarded_at': offboardedAt?.toIso8601String(),
    };
  }

  bool get isManagerApproved {
    final value = managerApproved?.toLowerCase();
    return value == 'approved' || value == 'yes';
  }

  bool get isManagerRejected {
    final value = managerApproved?.toLowerCase();
    return value == 'rejected' || value == 'no';
  }

  bool get isHrApproved {
    final value = hrApproved?.toLowerCase();
    return value == 'approved' || value == 'yes' || hrApproved == 'true';
  }

  bool get isHrRejected {
    final value = hrApproved?.toLowerCase();
    return value == 'rejected' || value == 'no';
  }

  bool get isRelieved {
    return offboardedAt != null && isHrApproved;
  }

  bool get hasPendingRequest {
    return approved != 'yes' && !isManagerRejected && !isHrRejected;
  }
}

class ResignationRequest {
  final String email;
  final String fullname;
  final String? department;
  final String? designation;
  final String reasonForResignation;

  ResignationRequest({
    required this.email,
    required this.fullname,
    this.department,
    this.designation,
    required this.reasonForResignation,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullname': fullname,
      'department': department,
      'designation': designation,
      'reason_for_resignation': reasonForResignation,
      'approved': 'pending',
      'offboarded_at': DateTime.now().toIso8601String(),
    };
  }
}
