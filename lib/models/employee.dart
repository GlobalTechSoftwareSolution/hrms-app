class Employee {
  final String id;
  final String name;
  final String email;
  final String department;
  final String position;
  final String phone;
  final DateTime joinDate;
  final String status;
  final String? avatarUrl;
  final double salary;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.position,
    required this.phone,
    required this.joinDate,
    required this.status,
    this.avatarUrl,
    required this.salary,
  });
}
