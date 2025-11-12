class EmployeeProfile {
  // Basic Information
  final String email;
  String fullname;
  String? phone;
  String? department;
  String? designation;
  String? dateOfBirth;
  String? dateJoined;
  String? skills;
  String? profilePicture;
  String? gender;
  String? maritalStatus;
  String? nationality;
  String? permanentAddress;
  
  // Emergency Contact
  String? emergencyContactName;
  String? emergencyContactRelationship;
  String? emergencyContactNo;
  
  // Employment Details
  String? empId;
  String? employmentType;
  String? workLocation;
  String? team;
  String? reportsTo;
  
  // Education
  String? degree;
  String? degreePassoutYear;
  String? institution;
  String? grade;
  String? languages;
  
  // Additional Information
  String? bloodGroup;
  String? accountNumber;
  String? fatherName;
  String? fatherContact;
  String? motherName;
  String? motherContact;
  String? wifeName;
  String? homeAddress;
  String? totalSiblings;
  String? brothers;
  String? sisters;
  String? totalChildren;
  
  // Bank Details
  String? bankName;
  String? branch;
  String? pfNo;
  String? pfUan;
  String? ifsc;
  String? residentialAddress;

  EmployeeProfile({
    required this.email,
    required this.fullname,
    this.phone,
    this.department,
    this.designation,
    this.dateOfBirth,
    this.dateJoined,
    this.skills,
    this.profilePicture,
    this.gender,
    this.maritalStatus,
    this.nationality,
    this.permanentAddress,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactNo,
    this.empId,
    this.employmentType,
    this.workLocation,
    this.team,
    this.reportsTo,
    this.degree,
    this.degreePassoutYear,
    this.institution,
    this.grade,
    this.languages,
    this.bloodGroup,
    this.accountNumber,
    this.fatherName,
    this.fatherContact,
    this.motherName,
    this.motherContact,
    this.wifeName,
    this.homeAddress,
    this.totalSiblings,
    this.brothers,
    this.sisters,
    this.totalChildren,
    this.bankName,
    this.branch,
    this.pfNo,
    this.pfUan,
    this.ifsc,
    this.residentialAddress,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      email: json['email'] ?? '',
      fullname: json['fullname'] ?? '',
      phone: json['phone'],
      department: json['department'],
      designation: json['designation'],
      dateOfBirth: json['date_of_birth'],
      dateJoined: json['date_joined'],
      skills: json['skills'],
      profilePicture: json['profile_picture'],
      gender: json['gender'],
      maritalStatus: json['marital_status'],
      nationality: json['nationality'],
      permanentAddress: json['permanent_address'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactRelationship: json['emergency_contact_relationship'],
      emergencyContactNo: json['emergency_contact_no'],
      empId: json['emp_id'],
      employmentType: json['employment_type'],
      workLocation: json['work_location'],
      team: json['team'],
      reportsTo: json['reports_to'],
      degree: json['degree'],
      degreePassoutYear: json['degree_passout_year']?.toString(),
      institution: json['institution'],
      grade: json['grade'],
      languages: json['languages'],
      bloodGroup: json['blood_group'],
      accountNumber: json['account_number'],
      fatherName: json['father_name'],
      fatherContact: json['father_contact'],
      motherName: json['mother_name'],
      motherContact: json['mother_contact'],
      wifeName: json['wife_name'],
      homeAddress: json['home_address'],
      totalSiblings: json['total_siblings']?.toString(),
      brothers: json['brothers']?.toString(),
      sisters: json['sisters']?.toString(),
      totalChildren: json['total_children']?.toString(),
      bankName: json['bank_name'],
      branch: json['branch'],
      pfNo: json['pf_no'],
      pfUan: json['pf_uan'],
      ifsc: json['ifsc'],
      residentialAddress: json['residential_address'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'email': email,
      'fullname': fullname,
    };

    // Helper to add non-null values
    void addIfNotNull(String key, dynamic value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        map[key] = value;
      }
    }

    addIfNotNull('phone', phone);
    addIfNotNull('department', department);
    addIfNotNull('designation', designation);
    addIfNotNull('date_of_birth', dateOfBirth);
    addIfNotNull('date_joined', dateJoined);
    addIfNotNull('skills', skills);
    addIfNotNull('gender', gender);
    addIfNotNull('marital_status', maritalStatus);
    addIfNotNull('nationality', nationality);
    addIfNotNull('permanent_address', permanentAddress);
    addIfNotNull('emergency_contact_name', emergencyContactName);
    addIfNotNull('emergency_contact_relationship', emergencyContactRelationship);
    addIfNotNull('emergency_contact_no', emergencyContactNo);
    addIfNotNull('emp_id', empId);
    addIfNotNull('employment_type', employmentType);
    addIfNotNull('work_location', workLocation);
    addIfNotNull('team', team);
    addIfNotNull('reports_to', reportsTo);
    addIfNotNull('degree', degree);
    addIfNotNull('degree_passout_year', degreePassoutYear);
    addIfNotNull('institution', institution);
    addIfNotNull('grade', grade);
    addIfNotNull('languages', languages);
    addIfNotNull('blood_group', bloodGroup);
    addIfNotNull('account_number', accountNumber);
    addIfNotNull('father_name', fatherName);
    addIfNotNull('father_contact', fatherContact);
    addIfNotNull('mother_name', motherName);
    addIfNotNull('mother_contact', motherContact);
    addIfNotNull('wife_name', wifeName);
    addIfNotNull('home_address', homeAddress);
    addIfNotNull('total_siblings', totalSiblings);
    addIfNotNull('brothers', brothers);
    addIfNotNull('sisters', sisters);
    addIfNotNull('total_children', totalChildren);
    addIfNotNull('bank_name', bankName);
    addIfNotNull('branch', branch);
    addIfNotNull('pf_no', pfNo);
    addIfNotNull('pf_uan', pfUan);
    addIfNotNull('ifsc', ifsc);
    addIfNotNull('residential_address', residentialAddress);

    return map;
  }

  EmployeeProfile copyWith({
    String? email,
    String? fullname,
    String? phone,
    String? department,
    String? designation,
    String? dateOfBirth,
    String? dateJoined,
    String? skills,
    String? profilePicture,
    String? gender,
    String? maritalStatus,
    String? nationality,
    String? permanentAddress,
    String? emergencyContactName,
    String? emergencyContactRelationship,
    String? emergencyContactNo,
    String? empId,
    String? employmentType,
    String? workLocation,
    String? team,
    String? reportsTo,
    String? degree,
    String? degreePassoutYear,
    String? institution,
    String? grade,
    String? languages,
    String? bloodGroup,
    String? accountNumber,
    String? fatherName,
    String? fatherContact,
    String? motherName,
    String? motherContact,
    String? wifeName,
    String? homeAddress,
    String? totalSiblings,
    String? brothers,
    String? sisters,
    String? totalChildren,
    String? bankName,
    String? branch,
    String? pfNo,
    String? pfUan,
    String? ifsc,
    String? residentialAddress,
  }) {
    return EmployeeProfile(
      email: email ?? this.email,
      fullname: fullname ?? this.fullname,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateJoined: dateJoined ?? this.dateJoined,
      skills: skills ?? this.skills,
      profilePicture: profilePicture ?? this.profilePicture,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      nationality: nationality ?? this.nationality,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelationship: emergencyContactRelationship ?? this.emergencyContactRelationship,
      emergencyContactNo: emergencyContactNo ?? this.emergencyContactNo,
      empId: empId ?? this.empId,
      employmentType: employmentType ?? this.employmentType,
      workLocation: workLocation ?? this.workLocation,
      team: team ?? this.team,
      reportsTo: reportsTo ?? this.reportsTo,
      degree: degree ?? this.degree,
      degreePassoutYear: degreePassoutYear ?? this.degreePassoutYear,
      institution: institution ?? this.institution,
      grade: grade ?? this.grade,
      languages: languages ?? this.languages,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      accountNumber: accountNumber ?? this.accountNumber,
      fatherName: fatherName ?? this.fatherName,
      fatherContact: fatherContact ?? this.fatherContact,
      motherName: motherName ?? this.motherName,
      motherContact: motherContact ?? this.motherContact,
      wifeName: wifeName ?? this.wifeName,
      homeAddress: homeAddress ?? this.homeAddress,
      totalSiblings: totalSiblings ?? this.totalSiblings,
      brothers: brothers ?? this.brothers,
      sisters: sisters ?? this.sisters,
      totalChildren: totalChildren ?? this.totalChildren,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      pfNo: pfNo ?? this.pfNo,
      pfUan: pfUan ?? this.pfUan,
      ifsc: ifsc ?? this.ifsc,
      residentialAddress: residentialAddress ?? this.residentialAddress,
    );
  }
}

class Manager {
  final String id;
  final String fullname;
  final String email;

  Manager({
    required this.id,
    required this.fullname,
    required this.email,
  });

  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['email'] ?? json['id']?.toString() ?? '',
      fullname: json['fullname'] ?? 'Unknown Manager',
      email: json['email'] ?? '',
    );
  }
}

class Department {
  final String departmentName;

  Department({required this.departmentName});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      departmentName: json['department_name'] ?? '',
    );
  }
}
