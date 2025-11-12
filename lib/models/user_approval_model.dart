class UserApproval {
  final String email;
  final String role;
  final bool isStaff;
  final bool isSuperuser;
  final bool isActive;
  final String? lastLogin;

  UserApproval({
    required this.email,
    required this.role,
    required this.isStaff,
    required this.isSuperuser,
    required this.isActive,
    this.lastLogin,
  });

  factory UserApproval.fromJson(Map<String, dynamic> json) {
    return UserApproval(
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isStaff: json['is_staff'] ?? false,
      isSuperuser: json['is_superuser'] ?? false,
      isActive: json['is_active'] ?? false,
      lastLogin: json['last_login'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'role': role,
      'is_staff': isStaff,
      'is_superuser': isSuperuser,
      'is_active': isActive,
      'last_login': lastLogin,
    };
  }
}
