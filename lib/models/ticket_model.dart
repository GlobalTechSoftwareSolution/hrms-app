class Ticket {
  final String id;
  final String subject;
  final String description;
  final String status; // 'open', 'closed', 'in-progress'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;
  final String? assignedBy;
  final String? closedBy;
  final String? closedTo;
  final String? closedDescription;

  Ticket({
    required this.id,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.assignedBy,
    this.closedBy,
    this.closedTo,
    this.closedDescription,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'].toString(),
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: _normalizeStatus(json['status'] ?? 'open'),
      priority: (json['priority'] ?? 'medium').toString().toLowerCase(),
      email: json['email'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      assignedTo: json['assigned_to'],
      assignedBy: json['assigned_by'],
      closedBy: json['closed_by'],
      closedTo: json['closed_to'],
      closedDescription: json['closed_description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'description': description,
      'status': _denormalizeStatus(status),
      'priority': priority.substring(0, 1).toUpperCase() + priority.substring(1),
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'closed_by': closedBy,
      'closed_to': closedTo,
      'closed_description': closedDescription,
    };
  }

  static String _normalizeStatus(String status) {
    return status.toLowerCase().replaceAll(' ', '-');
  }

  static String _denormalizeStatus(String status) {
    if (status == 'in-progress') return 'In Progress';
    if (status == 'open') return 'Open';
    if (status == 'closed') return 'Closed';
    return status;
  }

  Ticket copyWith({
    String? id,
    String? subject,
    String? description,
    String? status,
    String? priority,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
    String? assignedBy,
    String? closedBy,
    String? closedTo,
    String? closedDescription,
  }) {
    return Ticket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      closedBy: closedBy ?? this.closedBy,
      closedTo: closedTo ?? this.closedTo,
      closedDescription: closedDescription ?? this.closedDescription,
    );
  }
}
